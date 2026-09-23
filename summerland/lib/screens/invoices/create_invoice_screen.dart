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
  State<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState
    extends State<CreateInvoiceScreen> {
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

  final TextEditingController _searchController =
      TextEditingController();

  bool _isLoading = true;
  bool _isCreating = false;

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

      _showError(e.toString());
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

  Future<void> _selectVariant(
    ProductVariant variant,
  ) async {
    if (_selectedCashierLocation == null) {
      _showError(
        'Please select the cashier location first.',
      );
      return;
    }

    try {
      final inventory =
          await _inventoryService.getVariantInventory(
        variant.id,
      );

      if (!mounted) return;

      await _showVariantDialog(
        variant,
        inventory,
      );
    } catch (e) {
      if (!mounted) return;

      _showError(e.toString());
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
      _showError(
        'This variant has no stock in any location.',
      );
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

    _addToCart(
      variant,
      quantity.location,
      quantity.quantity,
    );
  }

  int _getCartQuantity(
    int variantId,
    int locationId,
  ) {
    final itemIndex = _cart.indexWhere(
      (item) => item.variant.id == variantId,
    );

    if (itemIndex == -1) {
      return 0;
    }

    return _cart[itemIndex]
        .allocations
        .where(
          (allocation) => allocation.location.id == locationId,
        )
        .fold(
          0,
          (total, allocation) => total + allocation.quantity,
        );
  }

  void _addToCart(
    ProductVariant variant,
    Location location,
    int quantity,
  ) {
    final itemIndex = _cart.indexWhere(
      (item) => item.variant.id == variant.id,
    );

    setState(() {
      if (itemIndex == -1) {
        _cart.add(
          _InvoiceCartItem(
            variant: variant,
            allocations: [
              _StockAllocation(
                location: location,
                quantity: quantity,
              ),
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
          _StockAllocation(
            location: location,
            quantity: quantity,
          ),
        );
      } else {
        cartItem.allocations[allocationIndex] = _StockAllocation(
          location: location,
          quantity: cartItem.allocations[allocationIndex].quantity +
              quantity,
        );
      }
    });
  }

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double get _cartTotal {
    return _cart.fold(
      0,
      (total, item) => total + (item.variant.price * item.totalQuantity),
    );
  }

  Future<void> _createInvoice() async {
    if (_selectedCashierLocation == null) {
      _showError(
        'Please select the cashier location.',
      );
      return;
    }

    if (_cart.isEmpty) {
      _showError(
        'Please add at least one item.',
      );
      return;
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
          });
        }
      }

      final invoice = await _invoiceService.createInvoice(
        locationId: _selectedCashierLocation!.id,
        items: items,
      );

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(
            invoice: invoice,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _cart.clear();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: WideContent(
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey(
                'cashier-location-${_selectedCashierLocation?.id}',
              ),
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

          final inCart = _cart.any(
            (item) => item.variant.id == variant.id,
          );

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
              title: Text(
                variant.productName,
              ),
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
                    variant.price.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (inCart)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Qty: $cartQuantity',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.success,
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
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
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
                'Total: ${money(_cartTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.builder(
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];

                return ListTile(
                  dense: true,
                  title: Text(item.variant.productName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.variant.modelNumber}'
                        ' • Qty: ${item.totalQuantity}',
                      ),
                      ...item.allocations.map(
                        (allocation) => Text(
                          '  ${allocation.location.name}: '
                          '${allocation.quantity}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (item.variant.price * item.totalQuantity)
                            .toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                  child: _filteredVariants.isEmpty &&
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

  _InvoiceCartItem({
    required this.variant,
    required this.allocations,
  });

  int get totalQuantity {
    return allocations.fold(
      0,
      (total, allocation) => total + allocation.quantity,
    );
  }
}

class _StockAllocation {
  final Location location;
  final int quantity;

  _StockAllocation({
    required this.location,
    required this.quantity,
  });
}

class _StockSelection {
  final Location location;
  final int quantity;

  _StockSelection({
    required this.location,
    required this.quantity,
  });
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
        const SnackBar(
          content: Text(
            'Please choose a stock location.',
          ),
        ),
      );
      return;
    }

    final value = int.tryParse(
      _controller.text.trim(),
    );

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid quantity.',
          ),
        ),
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
      _StockSelection(
        location: _selectedStockLocation!,
        quantity: value,
      ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text('Model: ${variant.modelNumber}'),
            if (variant.sizeName != null)
              Text('Size: ${variant.sizeName}'),
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
                  variant.price.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.primary,
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
              key: ValueKey(
                'stock-location-${_selectedStockLocation?.id}',
              ),
              initialValue: _selectedStockLocation?.id,
              decoration: const InputDecoration(
                labelText: 'Choose stock location',
              ),
              items: widget.availableInventory.map((item) {
                return DropdownMenuItem<int>(
                  value: item.locationId,
                  child: Text(
                    '${item.locationName} (${item.quantity})',
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
                  'Available: ${_availableAt(_selectedStockLocation!).quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class InvoiceDetailsScreen extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${invoice.id}'),
      ),
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
                    InfoTile(
                      label: 'Date',
                      value: '${invoice.createdAt}',
                    ),
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
                  subtitle: Text(
                    '${item.modelNumber}'
                    '${variantDetails.isEmpty ? '' : ' • $variantDetails'}\n'
                    'Qty: ${item.quantity} × '
                    '${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    item.totalPrice.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    money(invoice.totalAmount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
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