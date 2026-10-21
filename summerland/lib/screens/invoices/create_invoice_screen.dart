import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/employee.dart';
import '../../models/inventory.dart';
import '../../models/invoice.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';
import '../../services/api_service.dart';
import '../../services/employee_service.dart';
import '../../services/invoice_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/product_variant_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final ApiService _apiService = ApiService();

  late final LocationService _locationService;
  late final ProductVariantService _variantService;
  late final InventoryService _inventoryService;
  late final InvoiceService _invoiceService;
  late final EmployeeService _employeeService;

  List<Location> _locations = [];
  List<ProductVariant> _allVariants = [];
  List<ProductVariant> _filteredVariants = [];
  List<Employee> _employees = [];

  final List<_InvoiceCartItem> _cart = [];

  Location? _selectedCashierLocation;
  Employee? _selectedEmployee;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _discountController = TextEditingController();

  // false = invoice discount entered as money, true = as a percentage.
  bool _discountIsPercent = false;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isIncrementing = false;

  // The cart panel starts collapsed so it never covers the variant
  // results while items are being picked.
  bool _isCartExpanded = false;

  @override
  void initState() {
    super.initState();

    _locationService = LocationService(_apiService);
    _variantService = ProductVariantService(_apiService);
    _inventoryService = InventoryService(_apiService);
    _invoiceService = InvoiceService(_apiService);
    _employeeService = EmployeeService(_apiService);

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();

    for (final item in _cart) {
      item.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _locationService.getLocations(),
        _variantService.getVariants(),
        _employeeService.getEmployees(),
      ]);

      if (!mounted) return;

      setState(() {
        _locations = results[0] as List<Location>;
        _allVariants = results[1] as List<ProductVariant>;
        _employees = results[2] as List<Employee>;
        _filteredVariants = [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
  }

  void _searchVariants(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredVariants.clear();
        return;
      }

      _filteredVariants = _allVariants.where((variant) {
        return variant.modelNumber.toLowerCase().contains(query) ||
            variant.productName.toLowerCase().contains(query) ||
            variant.barcode.toLowerCase().contains(query) ||
            (variant.sizeName?.toLowerCase().contains(query) ?? false) ||
            (variant.colourName?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _selectVariant(ProductVariant variant) async {
    try {
      final inventory = await _inventoryService.getVariantInventory(variant.id);

      if (!mounted) return;

      await _showVariantDialog(variant, inventory);
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    }
  }

  Future<void> _showVariantDialog(
    ProductVariant variant,
    List<Inventory> inventory,
  ) async {
    final availableInventory = inventory
        .where((item) => item.quantity > 0)
        .toList();

    if (availableInventory.isEmpty) {
      _showError(context.tr('This variant has no stock in any location.'));
      return;
    }

    final quantity = await showDialog<_StockSelection>(
      context: context,
      builder: (context) => _AddItemDialog(
        variant: variant,
        availableInventory: availableInventory,
        locations: _locations,
        getCartQuantity: _getCartQuantity,
      ),
    );

    if (quantity == null) return;

    _addToCart(variant, quantity.location, quantity.quantity);
  }

  int _getCartQuantity(int variantId, int locationId) {
    final itemIndex = _cart.indexWhere((item) => item.variant.id == variantId);

    if (itemIndex == -1) {
      return 0;
    }

    return _cart[itemIndex].allocations
        .where((allocation) => allocation.location.id == locationId)
        .fold(0, (total, allocation) => total + allocation.quantity);
  }

  void _addToCart(ProductVariant variant, Location location, int quantity) {
    final itemIndex = _cart.indexWhere((item) => item.variant.id == variant.id);

    setState(() {
      if (itemIndex == -1) {
        _cart.add(
          _InvoiceCartItem(
            variant: variant,
            allocations: [
              _StockAllocation(location: location, quantity: quantity),
            ],
          ),
        );

        return;
      }

      final cartItem = _cart[itemIndex];

      final allocationIndex = cartItem.allocations.indexWhere(
        (allocation) => allocation.location.id == location.id,
      );

      if (allocationIndex == -1) {
        cartItem.allocations.add(
          _StockAllocation(location: location, quantity: quantity),
        );
      } else {
        cartItem.allocations[allocationIndex] = _StockAllocation(
          location: location,
          quantity: cartItem.allocations[allocationIndex].quantity + quantity,
        );
      }
    });
  }

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index).dispose();

      if (_cart.isEmpty) {
        _isCartExpanded = false;
      }
    });
  }

  // Adds one unit to a cart line, taking it from the first location that
  // still has free stock (stock on the shelf minus what is already in
  // this cart). Locations the line already draws from are tried first.
  Future<void> _incrementCartItem(int index) async {
    if (_isIncrementing) return;

    final item = _cart[index];

    setState(() {
      _isIncrementing = true;
    });

    try {
      final inventory = await _inventoryService.getVariantInventory(
        item.variant.id,
      );

      if (!mounted) return;

      final fromCartLocations = <Inventory>[];
      final fromOtherLocations = <Inventory>[];

      for (final entry in inventory) {
        final locationIndex = _locations.indexWhere(
          (location) => location.id == entry.locationId,
        );

        if (locationIndex == -1) continue;

        final alreadyInCart = item.allocations.any(
          (allocation) => allocation.location.id == entry.locationId,
        );

        if (alreadyInCart) {
          fromCartLocations.add(entry);
        } else {
          fromOtherLocations.add(entry);
        }
      }

      for (final entry in [...fromCartLocations, ...fromOtherLocations]) {
        final inCart = _getCartQuantity(item.variant.id, entry.locationId);

        if (entry.quantity - inCart <= 0) continue;

        final location = _locations.firstWhere(
          (location) => location.id == entry.locationId,
        );

        _addToCart(item.variant, location, 1);
        return;
      }

      _showError(
        context.tr('No more stock available for {0}.', [
          item.variant.productName,
        ]),
      );
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isIncrementing = false;
        });
      }
    }
  }

  // Removes one unit from a cart line, taking it from the most recently
  // added location. The line always keeps at least one unit; the bin icon
  // removes it entirely.
  void _decrementCartItem(int index) {
    final item = _cart[index];

    if (item.totalQuantity <= 1) return;

    setState(() {
      for (var i = item.allocations.length - 1; i >= 0; i--) {
        final allocation = item.allocations[i];

        if (allocation.quantity <= 0) continue;

        if (allocation.quantity == 1) {
          item.allocations.removeAt(i);
        } else {
          item.allocations[i] = _StockAllocation(
            location: allocation.location,
            quantity: allocation.quantity - 1,
          );
        }

        return;
      }
    });
  }

  // Price of the cart before any discount.
  double get _cartTotal {
    return _cart.fold(
      0,
      (total, item) => total + (item.variant.price * item.totalQuantity),
    );
  }

  // Per-line discounts entered on the cart rows, as money.
  double get _itemDiscountTotal {
    return _cart.fold(0, (total, item) => total + item.discountTotal);
  }

  // Items total once the per-line discounts are taken off.
  double get _cartTotalAfterItemDiscounts => _cartTotal - _itemDiscountTotal;

  // Raw invoice-discount entry; 0 when blank or not a number yet.
  double get _discountEntry =>
      double.tryParse(_discountController.text.trim()) ?? 0;

  bool get _discountEntryInvalid => _discountIsPercent && _discountEntry > 100;

  // Invoice-level discount, taken on top of the per-item discounts and
  // clamped so the payable can never go below zero.
  double get _discount {
    final value = _discountEntry;

    if (value <= 0) return 0;

    if (_discountIsPercent) {
      if (value > 100) return 0;

      return double.parse(
        (_cartTotalAfterItemDiscounts * value / 100).toStringAsFixed(2),
      );
    }

    return value > _cartTotalAfterItemDiscounts
        ? _cartTotalAfterItemDiscounts
        : value;
  }

  double get _netTotal => _cartTotalAfterItemDiscounts - _discount;

  // The invoice needs a cashier location, an employee and at least one item
  // before it can be created.
  bool get _canCreate =>
      _selectedCashierLocation != null &&
      _selectedEmployee != null &&
      _cart.isNotEmpty;

  // What the user still has to do before the invoice can be created.
  String get _createHint {
    final missingLocation = _selectedCashierLocation == null;
    final missingEmployee = _selectedEmployee == null;

    if (missingLocation && missingEmployee) {
      return context.tr(
        'Select a cashier location and an employee to create the invoice.',
      );
    }

    if (missingLocation) {
      return context.tr('Select a cashier location to create the invoice.');
    }

    if (missingEmployee) {
      return context.tr('Select an employee to create the invoice.');
    }

    if (_cart.isEmpty) {
      return context.tr('Add at least one item to create the invoice.');
    }

    return '';
  }

  Future<void> _createInvoice() async {
    if (_selectedCashierLocation == null) {
      _showError(context.tr('Please select the cashier location.'));
      return;
    }

    if (_selectedEmployee == null) {
      _showError(context.tr('Please select an employee.'));
      return;
    }

    if (_cart.isEmpty) {
      _showError(context.tr('Please add at least one item.'));
      return;
    }

    if (_discountEntryInvalid) {
      _showError(context.tr('Invoice discount percentage cannot exceed 100.'));
      return;
    }

    if (_discountEntry < 0) {
      _showError(context.tr('Discount cannot be negative.'));
      return;
    }

    if (!_discountIsPercent && _discountEntry > _cartTotalAfterItemDiscounts) {
      _showError(
        context.tr('Discount cannot exceed the items total of {0}.', [
          money(_cartTotalAfterItemDiscounts),
        ]),
      );
      return;
    }

    for (final cartItem in _cart) {
      final error = cartItem.discountError(context);

      if (error != null) {
        _showError(
          context.tr('{0}: {1}', [cartItem.variant.productName, error]),
        );
        return;
      }
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final items = <Map<String, dynamic>>[];

      for (final cartItem in _cart) {
        for (final allocation in cartItem.allocations) {
          items.add({
            'productVariantId': cartItem.variant.id,
            'quantity': allocation.quantity,
            'stockLocationId': allocation.location.id,
            ...cartItem.discountPayload,
          });
        }
      }

      final invoice = await _invoiceService.createInvoice(
        locationId: _selectedCashierLocation!.id,
        employeeId: _selectedEmployee!.id,
        items: items,
        discountAmount: _discountIsPercent ? 0 : _discount,
        discountPercent: _discountIsPercent ? _discountEntry : 0,
      );

      if (!mounted) return;

      setState(() {
        _isCreating = false;
        _discountController.clear();
        _discountIsPercent = false;
        _isCartExpanded = false;
      });

      await pushScreen(context, (_) => InvoiceDetailsScreen(invoice: invoice));

      if (!mounted) return;

      setState(() {
        _cart.clear();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: WideContent(
        child: TextField(
          controller: _searchController,
          onChanged: _searchVariants,
          decoration: InputDecoration(
            labelText: context.tr('Search Model / Name / Barcode'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _searchVariants('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantResults() {
    if (_filteredVariants.isEmpty) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search),
            Text(context.tr('Search for a Variant.')),
          ],
        ),
      );
    }

    return WideContent(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredVariants.length,
        itemBuilder: (context, index) {
          final variant = _filteredVariants[index];

          final inCart = _cart.any((item) => item.variant.id == variant.id);

          final cartQuantity = inCart
              ? _cart
                    .firstWhere((item) => item.variant.id == variant.id)
                    .totalQuantity
              : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(variant.productName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Model: {0}', [variant.modelNumber])),
                  if (variant.sizeName != null)
                    Text(context.tr('Size: {0}', [variant.sizeName])),
                  if (variant.colourName != null)
                    Text(context.tr('Colour: {0}', [variant.colourName])),
                  Text(context.tr('Barcode: {0}', [variant.barcode])),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(variant.price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor(context, variant.price),
                    ),
                  ),
                  if (inCart)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.tr('Qty: {0}', [cartQuantity]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () => _selectVariant(variant),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvoiceSummary(double availableHeight) {
    final theme = Theme.of(context);

    // Height the expanded panel may reach. The search bar, the toggle row
    // and the create button are all fixed, so they are taken off the space
    // first - otherwise the panel can push the bottom bar past the end of
    // the screen (seen on phones as a black/yellow overflow strip).
    final double panelMaxHeight = availableHeight - 300;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          InkWell(
            onTap: () {
              setState(() {
                _isCartExpanded = !_isCartExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.tr('Items: {0}', [_cart.length]),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: Text(
                      context.tr('Total: {0}', [money(_netTotal)]),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: amountColor(context, _netTotal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isCartExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isCartExpanded && panelMaxHeight > 0)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: panelMaxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(
                                  'cashier-location-'
                                  '${_selectedCashierLocation?.id}',
                                ),
                                initialValue: _selectedCashierLocation?.id,
                                isDense: true,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context.tr('Cashier Location'),
                                  prefixIcon: const Icon(
                                    Icons.storefront_outlined,
                                  ),
                                ),
                                items: _locations.map((location) {
                                  return DropdownMenuItem<int>(
                                    value: location.id,
                                    child: Text(
                                      location.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _selectedCashierLocation = _locations
                                        .firstWhere(
                                          (location) => location.id == value,
                                        );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(
                                  'invoice-employee-${_selectedEmployee?.id}',
                                ),
                                initialValue: _selectedEmployee?.id,
                                isDense: true,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context.tr('Employee'),
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                                items: _employees.map((employee) {
                                  return DropdownMenuItem<int>(
                                    value: employee.id,
                                    child: Text(
                                      employee.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _selectedEmployee = _employees.firstWhere(
                                      (employee) => employee.id == value,
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_itemDiscountTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.tr('Items {0}', [money(_cartTotal)]),
                              style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Text(
                              context.tr('Item discounts -{0}', [
                                money(_itemDiscountTotal),
                              ]),
                              style: TextStyle(
                                fontSize: 13,
                                color: amountColor(
                                  context,
                                  -_itemDiscountTotal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: _discountIsPercent
                                  ? context.tr('Invoice discount %')
                                  : context.tr('Invoice discount'),
                              prefixText: _discountIsPercent ? null : 'EGP ',
                              isDense: true,
                              suffixIcon: _discountController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _discountController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('EGP'),
                          selected: !_discountIsPercent,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) {
                            setState(() {
                              _discountIsPercent = false;
                              _discountController.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('%'),
                          selected: _discountIsPercent,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) {
                            setState(() {
                              _discountIsPercent = true;
                              _discountController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _discountEntryInvalid
                          ? context.tr('Enter a percentage up to 100.')
                          : _discount > 0
                          ? context.tr('Discount applied: -{0} {1}', [
                              money(_discount),
                              _discountIsPercent
                                  ? context.tr('({0}% of {1})', [
                                      _discountController.text.trim(),
                                      money(_cartTotalAfterItemDiscounts),
                                    ])
                                  : context.tr('(items {0})', [
                                      money(_cartTotalAfterItemDiscounts),
                                    ]),
                            ])
                          : context.tr(
                              'Invoice discount, applied after item discounts.',
                            ),
                      style: TextStyle(
                        color: _discountEntryInvalid
                            ? theme.colorScheme.error
                            : _discount > 0
                            ? amountColor(context, -_discount)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        final gross = item.variant.price * item.totalQuantity;
                        final net = gross - item.discountTotal;
                        final discountError = item.discountError(context);

                        return ListTile(
                          dense: true,
                          title: Text(item.variant.productName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.variant.modelNumber,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: item.totalQuantity > 1
                                        ? () => _decrementCartItem(index)
                                        : null,
                                    iconSize: 20,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    tooltip: context.tr('Decrease quantity'),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '${item.totalQuantity}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: !_isIncrementing
                                        ? () => _incrementCartItem(index)
                                        : null,
                                    iconSize: 20,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    tooltip: context.tr('Increase quantity'),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                              ...item.allocations.map(
                                (allocation) => Text(
                                  context.tr('  {0}: {1}', [
                                    allocation.location.name,
                                    allocation.quantity,
                                  ]),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              if (item.discountTotal > 0)
                                Text(
                                  context.tr(
                                    '  Unit: {0} → {1}{2} · line -{3}',
                                    [
                                      money(item.variant.price),
                                      money(
                                        item.variant.price -
                                            (item.unitDiscount ?? 0),
                                      ),
                                      item.discountIsPercent
                                          ? context.tr(' (-{0}%)', [
                                              item.discountController.text,
                                            ])
                                          : '',
                                      money(item.discountTotal),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 92,
                                    child: TextField(
                                      controller: item.discountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: item.discountIsPercent
                                            ? context.tr('Discount %')
                                            : context.tr('Discount/unit'),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('EGP'),
                                    selected: !item.discountIsPercent,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (_) {
                                      setState(() {
                                        item.discountIsPercent = false;
                                        item.discountController.clear();
                                      });
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('%'),
                                    selected: item.discountIsPercent,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (_) {
                                      setState(() {
                                        item.discountIsPercent = true;
                                        item.discountController.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (discountError != null)
                                Text(
                                  discountError,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                // Keeps a long figure from eating the row: the
                                // amount shrinks instead of squeezing the item.
                                constraints: const BoxConstraints(
                                  maxWidth: 110,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: item.discountTotal > 0
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              money(gross),
                                              style: TextStyle(
                                                fontSize: 12,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                            ),
                                            Text(
                                              money(net),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: amountColor(
                                                  context,
                                                  net,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          money(net),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: amountColor(context, net),
                                          ),
                                        ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeCartItem(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_canCreate && !_isCreating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _createHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isCreating || !_canCreate)
                        ? null
                        : _createInvoice,
                    icon: _isCreating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long_outlined),
                    label: Text(context.tr('Create Invoice')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Sales'),
      destinationId: 'sales',
      body: _isLoading
          ? const LoadingState()
          : LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    _buildHeader(),
                    const Divider(height: 1),
                    Expanded(child: _buildVariantResults()),
                    _buildInvoiceSummary(constraints.maxHeight),
                  ],
                );
              },
            ),
    );
  }
}

class _InvoiceCartItem {
  final ProductVariant variant;

  final List<_StockAllocation> allocations;

  final TextEditingController discountController = TextEditingController();

  // false = discount entered as money per unit, true = as a percentage.
  bool discountIsPercent = false;

  _InvoiceCartItem({required this.variant, required this.allocations});

  int get totalQuantity {
    return allocations.fold(
      0,
      (total, allocation) => total + allocation.quantity,
    );
  }

  double? get entryValue => double.tryParse(discountController.text.trim());

  bool get hasEntry => discountController.text.trim().isNotEmpty;

  // Per-unit discount as money. Null when the entry is not valid.
  double? get unitDiscount {
    if (!hasEntry) return 0;

    final value = entryValue;

    if (value == null || value < 0) return null;

    if (discountIsPercent) {
      if (value > 100) return null;

      return double.parse((variant.price * value / 100).toStringAsFixed(2));
    }

    return value > variant.price ? null : value;
  }

  double get discountTotal => (unitDiscount ?? 0) * totalQuantity;

  String? discountError(BuildContext context) {
    if (!hasEntry) return null;

    final value = entryValue;

    if (value == null || value < 0) {
      return context.tr('Enter 0 or more.');
    }

    if (discountIsPercent && value > 100) {
      return context.tr('Enter a percentage up to 100.');
    }

    if (!discountIsPercent && value > variant.price) {
      return context.tr('Max {0} per unit.', [money(variant.price)]);
    }

    return null;
  }

  // Exactly one of the two discount fields is sent; the API rejects
  // entries that set both.
  Map<String, dynamic> get discountPayload => discountIsPercent
      ? {'discountAmount': 0, 'discountPercent': entryValue ?? 0}
      : {'discountAmount': unitDiscount ?? 0, 'discountPercent': 0};

  void dispose() {
    discountController.dispose();
  }
}

class _StockAllocation {
  final Location location;
  final int quantity;

  _StockAllocation({required this.location, required this.quantity});
}

class _StockSelection {
  final Location location;
  final int quantity;

  _StockSelection({required this.location, required this.quantity});
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({
    required this.variant,
    required this.availableInventory,
    required this.locations,
    required this.getCartQuantity,
  });

  final ProductVariant variant;
  final List<Inventory> availableInventory;
  final List<Location> locations;
  final int Function(int variantId, int locationId) getCartQuantity;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late final TextEditingController _controller;

  Location? _selectedStockLocation;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Inventory _availableAt(Location location) {
    return widget.availableInventory.firstWhere(
      (item) => item.locationId == location.id,
    );
  }

  void _add() {
    final navigator = Navigator.of(context);

    if (_selectedStockLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please choose a stock location.'))),
      );
      return;
    }

    final value = int.tryParse(_controller.text.trim());

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter a valid quantity.'))),
      );
      return;
    }

    final available = _availableAt(_selectedStockLocation!).quantity;

    // Find existing quantity of this
    // variant from this SAME location.
    final existingQuantity = widget.getCartQuantity(
      widget.variant.id,
      _selectedStockLocation!.id,
    );

    if (existingQuantity + value > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Available stock at {0}: {1}', [
              _selectedStockLocation!.name,
              available,
            ]),
          ),
        ),
      );
      return;
    }

    navigator.pop(
      _StockSelection(location: _selectedStockLocation!, quantity: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;

    return AlertDialog(
      title: Text(context.tr('Add Item')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variant.productName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(context.tr('Model: {0}', [variant.modelNumber])),
            if (variant.sizeName != null)
              Text(context.tr('Size: {0}', [variant.sizeName])),
            if (variant.colourName != null)
              Text(context.tr('Colour: {0}', [variant.colourName])),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  context.tr('Price:'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(variant.price),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: amountColor(context, variant.price),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Stock Location'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('stock-location-${_selectedStockLocation?.id}'),
              initialValue: _selectedStockLocation?.id,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(hintText: context.tr('Select')),
              items: widget.availableInventory.map((item) {
                return DropdownMenuItem<int>(
                  value: item.locationId,
                  child: Text(
                    context.tr('{0} ({1})', [item.locationName, item.quantity]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedStockLocation = widget.locations.firstWhere(
                    (location) => location.id == value,
                  );
                });
              },
            ),
            if (_selectedStockLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr('Available: {0}', [
                    _availableAt(_selectedStockLocation!).quantity,
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('Quantity')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(onPressed: _add, child: Text(context.tr('Add'))),
      ],
    );
  }
}

class InvoiceDetailsScreen extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final itemDiscountTotal = invoice.items.fold<double>(
      0,
      (total, item) => total + item.discountAmount * item.quantity,
    );

    final subtotal =
        invoice.totalAmount + invoice.discountAmount + itemDiscountTotal;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Invoice #{0}', [invoice.id]))),
      body: WideContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Invoice #{0}', [invoice.id]),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    InfoTile(
                      label: context.tr('Cashier Location'),
                      value: invoice.locationName,
                    ),
                    InfoTile(
                      label: context.tr('Employee'),
                      value: invoice.employeeName ?? context.tr('None'),
                    ),
                    InfoTile(
                      label: context.tr('Date'),
                      value: '${invoice.createdAt}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: context.tr('Items'),
              subtitle: context.tr('Line items on this invoice'),
            ),
            const SizedBox(height: 8),
            ...invoice.items.map((item) {
              final variantDetails = [
                if (item.sizeName != null)
                  context.tr('Size: {0}', [item.sizeName]),
                if (item.colourName != null)
                  context.tr('Colour: {0}', [item.colourName]),
              ].join(' • ');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${item.modelNumber}'
                              '${variantDetails.isEmpty ? '' : ' • $variantDetails'}\n'
                              '${context.tr('Qty: ')}',
                        ),
                        TextSpan(text: '${item.quantity}'),
                        const TextSpan(text: ' × '),
                        if (!item.hasDiscount)
                          TextSpan(
                            text: money(item.unitPrice),
                            style: TextStyle(
                              color: amountColor(context, item.unitPrice),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else ...[
                          TextSpan(
                            text: money(item.unitPrice),
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          TextSpan(
                            text: ' → ${money(item.unitPriceAfterDiscount)}',
                            style: TextStyle(
                              color: amountColor(
                                context,
                                item.unitPriceAfterDiscount,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: context.tr('\nDiscount: {0}/unit{1}', [
                              '-${money(item.discountAmount)}',
                              item.discountPercent == null
                                  ? ''
                                  : ' (${percentLabel(item.discountPercent!)})',
                            ]),
                            style: TextStyle(
                              color: amountColor(context, -item.discountAmount),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: item.hasDiscount
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(item.totalBeforeDiscount),
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Text(
                              money(item.totalPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColor(context, item.totalPrice),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          money(item.totalPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: amountColor(context, item.totalPrice),
                          ),
                        ),
                ),
              );
            }),
            InfoTile(label: context.tr('Subtotal'), value: money(subtotal)),
            if (itemDiscountTotal > 0)
              InfoTile(
                label: context.tr('Item discounts'),
                value: moneyNegative(itemDiscountTotal),
                valueStyle: amountStyle(context, -itemDiscountTotal),
              ),
            if (invoice.discountAmount > 0)
              InfoTile(
                label: context.tr('Discount'),
                value: invoice.discountPercent == null
                    ? moneyNegative(invoice.discountAmount)
                    : '${moneyNegative(invoice.discountAmount)} '
                          '(${percentLabel(invoice.discountPercent!)})',
                valueStyle: amountStyle(context, -invoice.discountAmount),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    context.tr('Total'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money(invoice.totalAmount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
