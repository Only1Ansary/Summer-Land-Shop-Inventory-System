import 'package:flutter/material.dart';

import '../../models/inventory.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';

import '../../services/api_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';

import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class AddInventoryScreen extends StatefulWidget {
  final ProductVariant variant;

  const AddInventoryScreen({
    super.key,
    required this.variant,
  });

  @override
  State<AddInventoryScreen> createState() =>
      _AddInventoryScreenState();
}

class _AddInventoryScreenState
    extends State<AddInventoryScreen> {
  final InventoryService _inventoryService =
      InventoryService(ApiService());

  final LocationService _locationService =
      LocationService(ApiService());

  final _quantityController =
      TextEditingController();

  List<Inventory> _inventory = [];
  List<Location> _locations = [];

  int? _selectedLocationId;

  bool _isLoading = false;
  bool _isAdding = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _inventoryService.getVariantInventory(
          widget.variant.id,
        ),
        _locationService.getLocations(),
      ]);

      if (!mounted) return;

      setState(() {
        _inventory =
            results[0] as List<Inventory>;

        _locations =
            results[1] as List<Location>;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addInventory() async {
    final quantity = int.tryParse(
      _quantityController.text.trim(),
    );

    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a location.',
          ),
        ),
      );

      return;
    }

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Quantity must be greater than zero.',
          ),
        ),
      );

      return;
    }

    if (quantity > 100000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Quantity cannot exceed 100,000.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      await _inventoryService.addInventory(
        productVariantId: widget.variant.id,
        locationId: _selectedLocationId!,
        quantity: quantity,
      );

      if (!mounted) return;

      _quantityController.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Inventory added successfully.',
          ),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  int get _totalQuantity {
    return _inventory.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }

  int _getLocationQuantity(int locationId) {
    final inventoryItem =
        _inventory.where(
          (item) => item.locationId == locationId,
        );

    if (inventoryItem.isEmpty) {
      return 0;
    }

    return inventoryItem.first.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: WideContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildVariantInfo(),

            const SizedBox(height: 16),

            _buildStockSummary(),

            const SizedBox(height: 16),

            const SectionHeader(
              title: 'Stock by Location',
              subtitle: 'Quantities held per store',
            ),
            const SizedBox(height: 8),

            _buildLocations(),

            const SizedBox(height: 20),

            _buildAddStockForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.variant.productName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 22),
            InfoTile(
              label: 'Model',
              value: widget.variant.modelNumber,
            ),
            InfoTile(
              label: 'Size',
              value: widget.variant.sizeName ?? 'N/A',
            ),
            InfoTile(
              label: 'Colour',
              value: widget.variant.colourName ?? 'N/A',
            ),
            InfoTile(
              label: 'Barcode',
              value: widget.variant.barcode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSummary() {
    final bool isLowStock =
        _totalQuantity <=
            widget.variant.lowStockThreshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_totalQuantity',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Threshold',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.variant.lowStockThreshold}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                isLowStock
                    ? const LowStockBadge()
                    : const StatusBadge(
                        label: 'NORMAL',
                        color: AppPalette.success,
                        icon: Icons.check_circle_outline,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocations() {
    if (_locations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No locations found.'),
        ),
      );
    }

    return Column(
      children: _locations.map(
        (location) {
          final int quantity =
              _getLocationQuantity(
                location.id,
              );

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
              ),
              title: Text(location.name),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: quantity == 0
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: quantity == 0
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildAddStockForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Add Stock'),
            const SizedBox(height: 8),

            DropdownButtonFormField<int>(
              key: ValueKey('location-$_selectedLocationId'),
              initialValue: _selectedLocationId,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _locations.map(
                (location) {
                  return DropdownMenuItem<int>(
                    value: location.id,
                    child: Text(
                      location.name,
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocationId =
                      value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isAdding
                    ? null
                    : _addInventory,
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.add_box_outlined,
                      ),
                label: const Text(
                  'Add Stock',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}