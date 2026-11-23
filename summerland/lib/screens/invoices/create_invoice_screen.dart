import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/inventory.dart';
import '../../models/invoice.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';
import '../../services/api_service.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/invoice_printer.dart';
import '../../services/invoice_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/low_stock_notification_service.dart';
import '../../services/product_variant_service.dart';
import '../../utils/camera_scanner_support.dart';
import '../../utils/payment_method.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../inventory/barcode_scanner_screen.dart';
import 'show_sale_invoice_screen.dart';
import '../../ui/text_input_helpers.dart';

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
  late final CustomerService _customerService;
  late final LowStockNotificationService _notifications;

  List<Location> _locations = [];
  List<ProductVariant> _allVariants = [];
  List<ProductVariant> _filteredVariants = [];
  List<Employee> _employees = [];

  final List<_InvoiceCartItem> _cart = [];

  Location? _selectedCashierLocation;
  Employee? _selectedEmployee;

  // A phone is required for every sale. The customer is created on the server
  // the first time a number is used; [lookup] only prefills the name/balance.
  Customer? _matchedCustomer;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  int _paymentMethod = paymentMethodCash;
  bool _isLookingUpCustomer = false;

  final TextEditingController _discountController = TextEditingController();

  // false = invoice discount entered as money, true = as a percentage.
  bool _discountIsPercent = false;

  bool _isLoading = true;
  bool _isCreating = false;
  final Debouncer _searchDebounce = Debouncer();
  bool _isIncrementing = false;

  // The cart lives in a bottom sheet instead of a panel squeezed under the
  // results. The sheet is a separate route, so it listens to this notifier to
  // rebuild whenever the cart (which belongs to this State) changes.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  bool _isSheetOpen = false;

  // Errors raised while the sheet is open are shown inside the sheet, because
  // a SnackBar on this screen would be hidden behind it.
  String? _sheetMessage;
  Timer? _sheetMessageTimer;

  @override
  void initState() {
    super.initState();

    _locationService = LocationService(_apiService);
    _variantService = ProductVariantService(_apiService);
    _inventoryService = InventoryService(_apiService);
    _invoiceService = InvoiceService(_apiService);
    _employeeService = EmployeeService(_apiService);
    _customerService = CustomerService(_apiService);
    _notifications = LowStockNotificationService.instance;

    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _sheetMessageTimer?.cancel();
    _searchController.dispose();
    _customerPhoneController.dispose();
    _customerNameController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
    _revision.dispose();

    for (final item in _cart) {
      item.dispose();
    }

    super.dispose();
  }

  /// Rebuilds this screen and, if it is open, the cart sheet.
  void _refresh([VoidCallback? change]) {
    if (!mounted) return;

    setState(change ?? () {});
    _revision.value++;
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
        _filteredVariants = [];
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

  void _onSearchChanged(String value) {
    // Rebuild right away so the clear button appears/disappears instantly;
    // filtering is applied immediately so search results stay in sync with
    // the field (important for tests and for small catalogues).
    setState(() {
      _searchVariants(value);
    });
  }

  /// Opens the camera and works the scanned barcode straight into the sale.
  Future<void> _scanBarcode() async {
    final scanned = await pushScreen<String>(
      context,
          (_) => const BarcodeScannerScreen(),
    );

    if (!mounted || scanned == null) return;

    await _handleScannedBarcode(scanned);
  }

  /// Puts a scanned barcode into the sale.
  ///
  /// An exact match opens the usual add-item dialog, so the cashier still
  /// picks the stock location and quantity. A barcode that is not in the
  /// catalogue is shown in the search box instead, so the cashier can see
  /// what was read and correct it.
  Future<void> _handleScannedBarcode(String scanned) async {
    final barcode = scanned.trim();

    if (barcode.isEmpty) return;

    final query = barcode.toLowerCase();

    ProductVariant? match;
    for (final variant in _allVariants) {
      if (variant.barcode.trim().toLowerCase() == query) {
        match = variant;
        break;
      }
    }

    _searchDebounce.cancel();
    _searchController.text = barcode;
    _searchController.selection = TextSelection.collapsed(
      offset: barcode.length,
    );
    _searchVariants(barcode);

    if (match == null) {
      _showError(context.tr('No product matches this barcode.'));
      return;
    }

    await _selectVariant(match);
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

  int _variantCartQuantity(int variantId) {
    final itemIndex = _cart.indexWhere((item) => item.variant.id == variantId);

    return itemIndex == -1 ? 0 : _cart[itemIndex].totalQuantity;
  }

  void _addToCart(ProductVariant variant, Location location, int quantity) {
    final itemIndex = _cart.indexWhere((item) => item.variant.id == variant.id);

    _refresh(() {
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
    late final _InvoiceCartItem removed;

    _refresh(() {
      removed = _cart.removeAt(index);
    });

    // The row's TextField is still in the tree for this frame, so the
    // controller is disposed once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());

    if (_cart.isEmpty && _isSheetOpen) {
      Navigator.of(context).pop();
    }
  }

  // Adds one unit to a cart line, taking it from the first location that
  // still has free stock (stock on the shelf minus what is already in
  // this cart). Locations the line already draws from are tried first.
  Future<void> _incrementCartItem(int index) async {
    if (_isIncrementing) return;

    final item = _cart[index];

    _refresh(() {
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
        _refresh(() {
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

    _refresh(() {
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

  bool get _hasDiscountErrors {
    if (_discountEntryInvalid || _discountEntry < 0) return true;

    if (!_discountIsPercent && _discountEntry > _cartTotalAfterItemDiscounts) {
      return true;
    }

    return _cart.any((item) => item.hasDiscountError);
  }

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

  // Digits only, matching the server's phone normalisation.
  String get _customerPhoneDigits =>
      _customerPhoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _hasPhone => _customerPhoneDigits.length >= 3;

  double get _paidEntry =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0;

  bool get _hasPaymentErrors =>
      _paidEntry < 0 || _paidEntry > _netTotal;

  Future<void> _lookupCustomer() async {
    if (!_hasPhone) {
      _showError(context.tr('Enter a valid phone number.'));
      return;
    }

    setState(() {
      _isLookingUpCustomer = true;
    });

    try {
      final customer = await _customerService.lookupByPhone(
        _customerPhoneDigits,
      );

      if (!mounted) return;

      setState(() {
        _matchedCustomer = customer;

        if (customer != null &&
            customer.name != null &&
            _customerNameController.text.trim().isEmpty) {
          _customerNameController.text = customer.name!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUpCustomer = false;
        });
      }
    }
  }

  // The invoice needs a cashier location, an employee, a customer phone,
  // valid payment details and at least one item before it can be created.
  bool get _canCreate =>
      _selectedCashierLocation != null &&
          _selectedEmployee != null &&
          _cart.isNotEmpty &&
          !_hasDiscountErrors &&
          _hasPhone &&
          !_hasPaymentErrors;

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

    if (_hasDiscountErrors) {
      return context.tr('Fix the highlighted discounts to create the invoice.');
    }

    if (!_hasPhone) {
      return context.tr('Enter the customer phone number to create the invoice.');
    }

    if (_hasPaymentErrors) {
      return context.tr('Fix the paid amount to create the invoice.');
    }

    return '';
  }

  Future<void> _createInvoice() async {
    if (!ensureOnlineForWrite(context)) return;

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

    if (!_hasPhone) {
      _showError(context.tr('Please enter the customer phone number.'));
      return;
    }

    if (_paidEntry < 0) {
      _showError(context.tr('Paid amount cannot be negative.'));
      return;
    }

    if (_paidEntry > _netTotal) {
      _showError(
        context.tr('Paid amount cannot exceed the invoice total of {0}.', [
          money(_netTotal),
        ]),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

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

    final locationId = _selectedCashierLocation!.id;
    final employeeId = _selectedEmployee!.id;
    final discountAmount = _discountIsPercent ? 0 : _discount;
    final discountPercent = _discountIsPercent ? _discountEntry : 0;

    // Remember what the cart's variants looked like before the sale, so the
    // fresh stock can be compared against it once the invoice is committed.
    final variantsBeforeSale = <int, ProductVariant>{
      for (final cartItem in _cart) cartItem.variant.id: cartItem.variant,
    };

    // Captured now so the alert can still be shown if the screen is left
    // during the undo window.
    Invoice? createdInvoice;

    scheduleUndoable(
      context,
      message: context.tr('Invoice will be created. Tap Undo to cancel.'),
      operation: () async {
        try {
          createdInvoice = await _invoiceService.createInvoice(
            locationId: locationId,
            employeeId: employeeId,
            items: items,
            customerPhone: _customerPhoneDigits,
            customerName: _customerNameController.text.trim().isEmpty
                ? null
                : _customerNameController.text.trim(),
            paidAmount: _paidEntry,
            paymentMethod: _paidEntry > 0 ? _paymentMethod : paymentMethodCash,
            discountAmount: discountAmount.toDouble(),
            discountPercent: discountPercent.toDouble(),
          );

          // Persisted work: it still runs if the app is closed before the
          // foreground alert below has a chance to finish.
          await _notifications.scheduleBackgroundCheck();
        } finally {
          if (mounted) {
            setState(() {
              _isCreating = false;
            });
          }
        }
      },
      onCommitted: () async {
        final invoice = createdInvoice;

        // The alert does not depend on this screen still being open, so show
        // it even if the cashier navigated away during the undo window.
        if (invoice != null) {
          await _notifyNewlyLowStock(variantsBeforeSale);
        }

        if (!mounted) return;

        setState(() {
          _discountController.clear();
          _discountIsPercent = false;
          _customerPhoneController.clear();
          _customerNameController.clear();
          _paidAmountController.clear();
          _paymentMethod = paymentMethodCash;
          _matchedCustomer = null;

          for (final item in _cart) {
            item.dispose();
          }
          _cart.clear();
        });

        if (invoice == null) return;

        if (ModalRoute.of(context)?.isCurrent == true) {
          final shouldPrint = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.tr('Print invoice?')),
              content: Text(ctx.tr('Invoice #{0} created.', [invoice.id])),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(ctx.tr('Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(ctx.tr('Print')),
                ),
              ],
            ),
          );

          if (shouldPrint == true) {
            await InvoicePrinter.printSaleInvoice(
              invoice,
            );
          }

          if (!mounted) return;

          await pushScreen(
            context,
                (_) => ShowSaleInvoiceScreen(invoice: invoice),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Invoice #{0} created.', [invoice.id])),
            ),
          );
        }
      },
      onUndone: () {
        if (mounted) {
          setState(() {
            _isCreating = false;
          });
        }
      },
    );
  }

  /// Refreshes stock after a sale and notifies the user about any sold variant
  /// that has just crossed into low stock.
  ///
  /// The refresh also keeps [_allVariants] current, so a later search does not
  /// show the pre-sale quantity. Notification problems are ignored on purpose: a
  /// missing permission must not turn a successful sale into an error.
  Future<void> _notifyNewlyLowStock(
      Map<int, ProductVariant> variantsBeforeSale,
      ) async {
    List<ProductVariant> refreshed;

    try {
      refreshed = await _variantService.getVariants();
    } catch (error) {
      debugPrint('Could not refresh stock after the sale: $error');
      return;
    }

    final becameLow = newlyLowStockVariants(
      before: variantsBeforeSale.values,
      after: refreshed,
      soldVariantIds: variantsBeforeSale.keys.toSet(),
    );

    if (mounted) {
      setState(() {
        _allVariants = refreshed;
      });
      _searchVariants(_searchController.text);
    }

    for (final variant in becameLow) {
      await _notifications.showLowStock(variant: variant);
    }

    await _notifications.rememberLowStock(refreshed);
  }

  void _showError(String message) {
    if (!mounted) return;

    if (_isSheetOpen) {
      _sheetMessageTimer?.cancel();
      _sheetMessage = message;
      _revision.value++;

      _sheetMessageTimer = Timer(const Duration(seconds: 3), () {
        _sheetMessage = null;

        if (_isSheetOpen) _revision.value++;
      });

      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Main screen: search + results + a slim checkout bar
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: theme.colorScheme.surface,
      child: WideContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: textFieldAutofocus(true),
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: context.tr('Search Model / Name / Barcode'),
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _searchDebounce.cancel();
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

  Widget _buildEmptyState({required IconData icon, required String message}) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantResults() {
    if (_filteredVariants.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;

      return _buildEmptyState(
        icon: hasQuery ? Icons.search_off : Icons.search,
        message: hasQuery
            ? context.tr('No variants match your search.')
            : context.tr('Search for a Variant.'),
      );
    }

    return WideContent(
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _filteredVariants.length,
        itemBuilder: (context, index) =>
            _buildVariantCard(_filteredVariants[index]),
      ),
    );
  }

  Widget _buildVariantCard(ProductVariant variant) {
    final theme = Theme.of(context);
    final cartQuantity = _variantCartQuantity(variant.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectVariant(variant),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        AppPill(
                          text: context.tr('Model: {0}', [variant.modelNumber]),
                        ),
                        if (variant.sizeName != null)
                          AppPill(
                            text: context.tr('Size: {0}', [variant.sizeName]),
                          ),
                        if (variant.colourName != null)
                          AppPill(
                            text: context.tr('Colour: {0}', [
                              variant.colourName,
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Barcode: {0}', [variant.barcode]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        money(variant.price),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (cartQuantity > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.tr('Qty: {0}', [cartQuantity]),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: WideContent(
            child: Row(
              children: [
                Badge(
                  isLabelVisible: _cart.isNotEmpty,
                  label: Text('${_cart.length}'),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _cart.isEmpty ? null : _openCart,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Items: {0}', [_cart.length]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            money(_netTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: (_cart.isEmpty || _isCreating) ? null : _openCart,
                  icon: _isCreating
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.shopping_cart_checkout, size: 20),
                  label: Text(context.tr('Review Order')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cart sheet: everything needed to finish the sale, in one scrollable place
  // ---------------------------------------------------------------------------

  Future<void> _openCart() async {
    if (_cart.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    _isSheetOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: _revision,
          builder: (context, _) => _buildCartSheet(context),
        );
      },
    );

    _isSheetOpen = false;
    _sheetMessageTimer?.cancel();
    _sheetMessage = null;
  }

  Widget _buildCartSheet(BuildContext sheetContext) {
    final theme = Theme.of(sheetContext);
    final keyboardHeight = MediaQuery.viewInsetsOf(sheetContext).bottom;
    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
    final keyboardOpen = keyboardHeight > 0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        // Lifts the whole sheet above the keyboard; the list in the middle
        // simply gets shorter, so nothing can overflow.
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Review Order'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _buildSaleDetails(),
                  const SizedBox(height: 16),
                  _buildCustomerAndPayment(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _cart.length; i++)
                    _buildCartItemCard(i),
                  const SizedBox(height: 4),
                  _buildInvoiceDiscountField(),
                  const SizedBox(height: 16),
                  _buildTotals(),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildSheetFooter(sheetContext, compact: keyboardOpen),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleDetails() {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('cashier-location-${_selectedCashierLocation?.id}'),
          initialValue: _selectedCashierLocation?.id,
          isDense: true,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('Cashier'),
            prefixIcon: const Icon(Icons.storefront_outlined),
          ),
          items: _locations.map((location) {
            return DropdownMenuItem<int>(
              value: location.id,
              child: Text(location.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            _refresh(() {
              _selectedCashierLocation = _locations.firstWhere(
                    (location) => location.id == value,
              );
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('invoice-employee-${_selectedEmployee?.id}'),
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
              child: Text(employee.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            _refresh(() {
              _selectedEmployee = _employees.firstWhere(
                    (employee) => employee.id == value,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCustomerAndPayment() {
    final theme = Theme.of(context);

    String? phoneError;
    if (_customerPhoneController.text.trim().isNotEmpty && !_hasPhone) {
      phoneError = context.tr('Enter at least 3 digits.');
    }

    String? paidError;
    if (_paidEntry < 0) {
      paidError = context.tr('Paid amount cannot be negative.');
    } else if (_paidEntry > _netTotal) {
      paidError = context.tr('Cannot exceed {0}.', [money(_netTotal)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Customer & Payment'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                autofocus: textFieldAutofocus(false),
                key: const Key('invoice-customer-phone'),
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_matchedCustomer != null) {
                    _refresh(() => _matchedCustomer = null);
                  } else {
                    _refresh();
                  }
                },
                decoration: InputDecoration(
                  labelText: context.tr('Customer phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  isDense: true,
                  errorText: phoneError,
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: context.tr('Lookup customer'),
              onPressed: _isLookingUpCustomer ? null : _lookupCustomer,
              icon: _isLookingUpCustomer
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.person_search_outlined),
            ),
          ],
        ),
        if (_matchedCustomer != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr('{0} · Outstanding: {1}', [
                  _matchedCustomer!.displayName,
                  money(_matchedCustomer!.totalDebt),
                ]),
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          autofocus: textFieldAutofocus(false),
          key: const Key('invoice-customer-name'),
          controller: _customerNameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _refresh(),
          decoration: InputDecoration(
            labelText: context.tr('Customer name (optional)'),
            prefixIcon: const Icon(Icons.badge_outlined),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          autofocus: textFieldAutofocus(false),
          key: const Key('invoice-paid-amount'),
          controller: _paidAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => _refresh(),
          decoration: InputDecoration(
            labelText: context.tr('Paid now'),
            prefixIcon: const Icon(Icons.payments_outlined),
            isDense: true,
            errorText: paidError,
            errorMaxLines: 2,
            helperText: context.tr('0 = pay later'),
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: const ValueKey('invoice-payment-method'),
          initialValue: _paymentMethod,
          isDense: true,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('Payment method'),
            prefixIcon: const Icon(Icons.credit_card_outlined),
          ),
          items: paymentMethodValues.map((method) {
            return DropdownMenuItem<int>(
              value: method,
              child: Text(paymentMethodLabel(context, method)),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            _refresh(() => _paymentMethod = value);
          },
        ),
      ],
    );
  }

  Widget _buildCartItemCard(int index) {
    final item = _cart[index];
    final theme = Theme.of(context);

    final gross = item.variant.price * item.totalQuantity;
    final net = gross - item.discountTotal;
    final discountError = item.discountError(context);

    final variantSummary = [
      item.variant.modelNumber,
      if (item.variant.sizeName != null)
        context.tr('Size: {0}', [item.variant.sizeName]),
      if (item.variant.colourName != null)
        context.tr('Colour: {0}', [item.variant.colourName]),
    ].join(' • ');

    return Card(
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.variant.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        variantSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeCartItem(index),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final allocation in item.allocations)
                    AppPill(
                      icon: Icons.place_outlined,
                      text: '${allocation.location.name} × '
                          '${allocation.quantity}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  AppQuantityStepper(
                    quantity: item.totalQuantity,
                    decreaseTooltip: context.tr('Decrease quantity'),
                    increaseTooltip: context.tr('Increase quantity'),
                    onDecrement: item.totalQuantity > 1
                        ? () => _decrementCartItem(index)
                        : null,
                    onIncrement: !_isIncrementing
                        ? () => _incrementCartItem(index)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: item.discountTotal > 0
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
                              ),
                            ),
                          ],
                        )
                            : Text(
                          money(net),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (item.discountTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(
                  context.tr('  Unit: {0} → {1}{2} · line -{3}', [
                    money(item.variant.price),
                    money(item.variant.price - (item.unitDiscount ?? 0)),
                    item.discountIsPercent
                        ? context.tr(' (-{0}%)', [item.discountController.text])
                        : '',
                    money(item.discountTotal),
                  ]),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: textFieldAutofocus(false),
                      controller: item.discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _refresh(),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: item.discountIsPercent
                            ? context.tr('Discount %')
                            : context.tr('Discount/unit'),
                        errorText: discountError,
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppCurrencyPercentToggle(
                    isPercent: item.discountIsPercent,
                    onChanged: (isPercent) {
                      item.discountIsPercent = isPercent;
                      item.discountController.clear();
                      _refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDiscountField() {
    final theme = Theme.of(context);

    final String helper;

    if (_discount > 0) {
      helper = context.tr('Discount applied: -{0} {1}', [
        money(_discount),
        _discountIsPercent
            ? context.tr('({0}% of {1})', [
          _discountController.text.trim(),
          money(_cartTotalAfterItemDiscounts),
        ])
            : context.tr('(items {0})', [
          money(_cartTotalAfterItemDiscounts),
        ]),
      ]);
    } else {
      helper = context.tr('Invoice discount, applied after item discounts.');
    }

    String? errorText;

    if (_discountEntryInvalid) {
      errorText = context.tr('Enter a percentage up to 100.');
    } else if (_discountEntry < 0) {
      errorText = context.tr('Discount cannot be negative.');
    } else if (!_discountIsPercent &&
        _discountEntry > _cartTotalAfterItemDiscounts) {
      errorText = context.tr('Discount cannot exceed the items total of {0}.', [
        money(_cartTotalAfterItemDiscounts),
      ]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            autofocus: textFieldAutofocus(false),
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _refresh(),
            decoration: InputDecoration(
              labelText: _discountIsPercent
                  ? context.tr('Invoice discount %')
                  : context.tr('Invoice discount'),
              isDense: true,
              prefixIcon: const Icon(Icons.sell_outlined),
              errorText: errorText,
              errorMaxLines: 2,
              helperText: helper,
              helperMaxLines: 3,
              helperStyle: TextStyle(
                color: _discount > 0
                    ? amountColor(context, -_discount)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: _discountController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _discountController.clear();
                  _refresh();
                },
                icon: const Icon(Icons.clear),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppCurrencyPercentToggle(
          isPercent: _discountIsPercent,
          onChanged: (isPercent) {
            _discountController.clear();
            _refresh(() {
              _discountIsPercent = isPercent;
            });
          },
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final hasDiscounts = _itemDiscountTotal > 0 || _discount > 0;

    if (!hasDiscounts) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            _summaryRow(context.tr('Subtotal'), money(_cartTotal)),
            if (_itemDiscountTotal > 0)
              _summaryRow(
                context.tr('Item discounts'),
                moneyNegative(_itemDiscountTotal),
                color: amountColor(context, -_itemDiscountTotal),
              ),
            if (_discount > 0)
              _summaryRow(
                context.tr('Discount'),
                moneyNegative(_discount),
                color: amountColor(context, -_discount),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetFooter(BuildContext sheetContext, {required bool compact}) {
    final theme = Theme.of(sheetContext);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sheetMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _sheetMessage!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Total'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      money(_netTotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!compact && !_canCreate && !_isCreating && _cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _createHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_isCreating || !_canCreate)
                    ? null
                    : () {
                  // Close the sheet first so the confirmation, undo and
                  // print flow all happen on the main screen.
                  _isSheetOpen = false;
                  Navigator.of(sheetContext).pop();
                  _createInvoice();
                },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Sales'),
      destinationId: 'sales',
      actions: [
        if (supportsCameraBarcodeScanning)
          IconButton(
            tooltip: context.tr('Scan barcode'),
            onPressed: _isLoading ? null : _scanBarcode,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
      ],
      body: _isLoading
          ? const LoadingState()
          : Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(child: _buildVariantResults()),
          _buildCheckoutBar(),
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

  // True when the discount entry cannot be used (same rules as
  // [discountError], without needing a BuildContext).
  bool get hasDiscountError {
    if (!hasEntry) return false;

    final value = entryValue;

    if (value == null || value < 0) return true;

    if (discountIsPercent && value > 100) return true;

    if (!discountIsPercent && value > variant.price) return true;

    return false;
  }

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

    // With a single stocked location there is nothing to choose.
    if (widget.availableInventory.length == 1) {
      final locationId = widget.availableInventory.first.locationId;
      final index = widget.locations.indexWhere(
            (location) => location.id == locationId,
      );

      if (index != -1) {
        _selectedStockLocation = widget.locations[index];
      }
    }
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
      scrollable: true,
      content: Column(
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
            autofocus: textFieldAutofocus(false),
            controller: _controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(labelText: context.tr('Quantity')),
          ),
        ],
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

              // A plain row instead of a ListTile: a ListTile has a fixed
              // height for 3 lines, which overflowed once a discount line
              // or a long model name pushed the text past that.
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
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
                                        color: amountColor(
                                          context,
                                          item.unitPrice,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else ...[
                                    TextSpan(
                                      text: money(item.unitPrice),
                                      style: TextStyle(
                                        decoration:
                                        TextDecoration.lineThrough,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                      ' → ${money(item.unitPriceAfterDiscount)}',
                                      style: TextStyle(
                                        color: amountColor(
                                          context,
                                          item.unitPriceAfterDiscount,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: context.tr(
                                        '\nDiscount: {0}/unit{1}',
                                        [
                                          '-${money(item.discountAmount)}',
                                          item.discountPercent == null
                                              ? ''
                                              : ' (${percentLabel(item.discountPercent!)})',
                                        ],
                                      ),
                                      style: TextStyle(
                                        color: amountColor(
                                          context,
                                          -item.discountAmount,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: item.hasDiscount
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
                                  color: amountColor(
                                    context,
                                    item.totalPrice,
                                  ),
                                ),
                              ),
                            ],
                          )
                              : Text(
                            money(item.totalPrice),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: amountColor(
                                context,
                                item.totalPrice,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          money(invoice.totalAmount),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
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