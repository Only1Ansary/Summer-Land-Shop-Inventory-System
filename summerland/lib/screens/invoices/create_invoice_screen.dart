import 'package:flutter/material.dart';

import '../../models/inventory.dart';
import '../../models/invoice.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';
import '../../services/api_service.dart';
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

  List<Location> _locations = [];
  List<ProductVariant> _allVariants = [];
  List<ProductVariant> _filteredVariants = [];

  final List<_InvoiceCartItem> _cart = [];

  Location? _selectedCashierLocation;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _discountController = TextEditingController();

  // false = invoice discount entered as money, true = as a percentage.
  bool _discountIsPercent = false;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isIncrementing = false;

  @override
  void initState() {
    super.initState();

    _locationService = LocationService(_apiService);
    _variantService = ProductVariantService(_apiService);
    _inventoryService = InventoryService(_apiService);
    _invoiceService = InvoiceService(_apiService);

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
      ]);

      if (!mounted) return;

      setState(() {
        _locations = results[0] as List<Location>;
        _allVariants = results[1] as List<ProductVariant>;
        _filteredVariants = [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(friendlyError(e));
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
    if (_selectedCashierLocation == null) {
      _showError('Please select the cashier location first.');
      return;
    }

    try {
      final inventory = await _inventoryService.getVariantInventory(variant.id);

      if (!mounted) return;

      await _showVariantDialog(variant, inventory);
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
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
      _showError('This variant has no stock in any location.');
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

      _showError('No more stock available for ${item.variant.productName}.');
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
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

  Future<void> _createInvoice() async {
    if (_selectedCashierLocation == null) {
      _showError('Please select the cashier location.');
      return;
    }

    if (_cart.isEmpty) {
      _showError('Please add at least one item.');
      return;
    }

    if (_discountEntryInvalid) {
      _showError('Invoice discount percentage cannot exceed 100.');
      return;
    }

    if (_discountEntry < 0) {
      _showError('Discount cannot be negative.');
      return;
    }

    if (!_discountIsPercent && _discountEntry > _cartTotalAfterItemDiscounts) {
      _showError(
        'Discount cannot exceed the items total of '
        '${money(_cartTotalAfterItemDiscounts)}.',
      );
      return;
    }

    for (final cartItem in _cart) {
      final error = cartItem.discountError;

      if (error != null) {
        _showError('${cartItem.variant.productName}: $error');
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
        items: items,
        discountAmount: _discountIsPercent ? 0 : _discount,
        discountPercent: _discountIsPercent ? _discountEntry : 0,
      );

      if (!mounted) return;

      setState(() {
        _isCreating = false;
        _discountController.clear();
        _discountIsPercent = false;
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

      _showError(friendlyError(e));
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
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('cashier-location-${_selectedCashierLocation?.id}'),
              initialValue: _selectedCashierLocation?.id,
              decoration: const InputDecoration(
                labelText: 'Cashier Location',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              items: _locations.map((location) {
                return DropdownMenuItem<int>(
                  value: location.id,
                  child: Text(location.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedCashierLocation = _locations.firstWhere(
                    (location) => location.id == value,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _searchVariants,
              decoration: InputDecoration(
                labelText: 'Search Model / Name / Barcode',
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
          ],
        ),
      ),
    );
  }

  Widget _buildVariantResults() {
    if (_filteredVariants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Search for a variant.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
                  Text('Model: ${variant.modelNumber}'),
                  if (variant.sizeName != null)
                    Text('Size: ${variant.sizeName}'),
                  if (variant.colourName != null)
                    Text('Colour: ${variant.colourName}'),
                  Text('Barcode: ${variant.barcode}'),
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
                        'Qty: $cartQuantity',
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

  Widget _buildCartBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Items: ${_cart.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Total: ${money(_netTotal)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: amountColor(context, _netTotal),
                ),
              ),
            ],
          ),
          if (_itemDiscountTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text(
                    'Items ${money(_cartTotal)}',
                    style: TextStyle(
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Item discounts -${money(_itemDiscountTotal)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: amountColor(context, -_itemDiscountTotal),
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
                        ? 'Invoice discount %'
                        : 'Invoice discount',
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
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                ? 'Enter a percentage up to 100.'
                : _discount > 0
                ? 'Discount applied: -${money(_discount)} '
                      '${_discountIsPercent ? '(${_discountController.text.trim()}% of '
                                '${money(_cartTotalAfterItemDiscounts)})' : '(items '
                                '${money(_cartTotalAfterItemDiscounts)})'}'
                : 'Invoice discount, applied after item discounts.',
            style: TextStyle(
              color: _discountEntryInvalid
                  ? theme.colorScheme.error
                  : _discount > 0
                  ? amountColor(context, -_discount)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                final gross = item.variant.price * item.totalQuantity;
                final net = gross - item.discountTotal;
                final discountError = item.discountError;

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
                            tooltip: 'Decrease quantity',
                            icon: const Icon(Icons.remove_circle_outline),
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
                            tooltip: 'Increase quantity',
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      ...item.allocations.map(
                        (allocation) => Text(
                          '  ${allocation.location.name}: '
                          '${allocation.quantity}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (item.discountTotal > 0)
                        Text(
                          '  Unit: ${money(item.variant.price)} → '
                          '${money(item.variant.price - (item.unitDiscount ?? 0))}'
                          '${item.discountIsPercent ? ' (-${item.discountController.text}%)' : ''}'
                          ' · line -${money(item.discountTotal)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Row(
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
                                    ? 'Discount %'
                                    : 'Discount/unit',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                          const SizedBox(width: 4),
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
                      item.discountTotal > 0
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(gross),
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                Text(
                                  money(net),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: amountColor(context, net),
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
                      IconButton(
                        onPressed: () => _removeCartItem(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCreating ? null : _createInvoice,
              icon: _isCreating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: const Text('Create Invoice'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Sales',
      destinationId: 'sales',
      body: _isLoading
          ? const LoadingState()
          : Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child:
                      _filteredVariants.isEmpty &&
                          _searchController.text.trim().isEmpty
                      ? _buildVariantResults()
                      : _buildVariantResults(),
                ),
                if (_cart.isNotEmpty) _buildCartBar(),
              ],
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

  String? get discountError {
    if (!hasEntry) return null;

    final value = entryValue;

    if (value == null || value < 0) {
      return 'Enter 0 or more.';
    }

    if (discountIsPercent && value > 100) {
      return 'Enter a percentage up to 100.';
    }

    if (!discountIsPercent && value > variant.price) {
      return 'Max ${money(variant.price)} per unit.';
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
        const SnackBar(content: Text('Please choose a stock location.')),
      );
      return;
    }

    final value = int.tryParse(_controller.text.trim());

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
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
            'Available stock at '
            '${_selectedStockLocation!.name}: $available',
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
      title: const Text('Add Item'),
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
            Text('Model: ${variant.modelNumber}'),
            if (variant.sizeName != null) Text('Size: ${variant.sizeName}'),
            if (variant.colourName != null)
              Text('Colour: ${variant.colourName}'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Price:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  money(variant.price),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: amountColor(context, variant.price),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Stock Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('stock-location-${_selectedStockLocation?.id}'),
              initialValue: _selectedStockLocation?.id,
              decoration: const InputDecoration(
                labelText: 'Choose stock location',
              ),
              items: widget.availableInventory.map((item) {
                return DropdownMenuItem<int>(
                  value: item.locationId,
                  child: Text('${item.locationName} (${item.quantity})'),
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
                  'Available: '
                  '${_availableAt(_selectedStockLocation!).quantity}',
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _add, child: const Text('Add')),
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
      appBar: AppBar(title: Text('Invoice #${invoice.id}')),
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
                      'Invoice #${invoice.id}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    InfoTile(
                      label: 'Cashier Location',
                      value: invoice.locationName,
                    ),
                    InfoTile(label: 'Date', value: '${invoice.createdAt}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Items',
              subtitle: 'Line items on this invoice',
            ),
            const SizedBox(height: 8),
            ...invoice.items.map((item) {
              final variantDetails = [
                if (item.sizeName != null) 'Size: ${item.sizeName}',
                if (item.colourName != null) 'Colour: ${item.colourName}',
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
                              'Qty: ',
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
                            text:
                                '\nDiscount: '
                                '-${money(item.discountAmount)}/unit'
                                '${item.discountPercent == null ? '' : ' (${percentLabel(item.discountPercent!)})'}',
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
            InfoTile(label: 'Subtotal', value: money(subtotal)),
            if (itemDiscountTotal > 0)
              InfoTile(
                label: 'Item discounts',
                value: moneyNegative(itemDiscountTotal),
                valueStyle: amountStyle(context, -itemDiscountTotal),
              ),
            if (invoice.discountAmount > 0)
              InfoTile(
                label: 'Discount',
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
                    'Total',
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
