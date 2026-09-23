import 'package:flutter/material.dart';

import '../../models/inventory.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';
import '../../services/api_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/stock_transfer_service.dart';

import '../../ui/app_widgets.dart';

class CreateStockTransferScreen extends StatefulWidget {
  const CreateStockTransferScreen({super.key});

  @override
  State<CreateStockTransferScreen> createState() =>
      _CreateStockTransferScreenState();
}

class _CreateStockTransferScreenState
    extends State<CreateStockTransferScreen> {
  late final LocationService _locationService;
  late final ProductVariantService _variantService;
  late final StockTransferService _transferService;
  late final InventoryService _inventoryService;

  List<Inventory> _variantInventory = [];

  List<Location> _locations = [];
  List<ProductVariant> _variants = [];

  Location? _fromLocation;
  Location? _toLocation;
  ProductVariant? _selectedVariant;

  final TextEditingController _searchController =
      TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  List<ProductVariant> _filteredVariants = [];

  @override
  void initState() {
    super.initState();

    final apiService = ApiService();

    _locationService = LocationService(apiService);
    _variantService = ProductVariantService(apiService);
    _transferService = StockTransferService(apiService);
    _inventoryService = InventoryService(apiService);

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadVariantInventory(
    ProductVariant variant,
  ) async {
    try {
      final inventory =
          await _inventoryService.getVariantInventory(
        variant.id,
      );

      if (!mounted) return;

      setState(() {
        _variantInventory = inventory;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(e.toString());
    }
  }

  Future<void> _loadData() async {
    try {
      final locations = await _locationService.getLocations();
      final variants = await _variantService.getVariants();

      if (!mounted) return;

      setState(() {
        _locations = locations;
        _variants = variants;
        _filteredVariants = variants;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _searchVariants(String query) {
    final value = query.trim().toLowerCase();

    setState(() {
      if (value.isEmpty) {
        _filteredVariants = _variants;
        return;
      }

      _filteredVariants = _variants.where((variant) {
        return variant.modelNumber.toLowerCase().contains(value) ||
            variant.productName.toLowerCase().contains(value) ||
            variant.totalQuantity > -1 ||
            variant.barcode.toLowerCase().contains(value) ||
            (variant.sizeName?.toLowerCase().contains(value) ?? false) ||
            (variant.colourName?.toLowerCase().contains(value) ?? false);
      }).toList();
    });
  }

  String _variantDisplayName(ProductVariant variant) {
    final parts = <String>[
      variant.productName,
      if (variant.sizeName != null) variant.sizeName!,
      if (variant.colourName != null) variant.colourName!,
    ];

    return parts.join(' - ');
  }

  Future<void> _createTransfer() async {
    if (_selectedVariant == null) {
      _showError('Please select a product variant.');
      return;
    }

    if (_fromLocation == null) {
      _showError('Please select the source location.');
      return;
    }

    if (_toLocation == null) {
      _showError('Please select the destination location.');
      return;
    }

    if (_fromLocation!.id == _toLocation!.id) {
      _showError(
        'Source and destination locations must be different.',
      );
      return;
    }

    final quantity = int.tryParse(
      _quantityController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      _showError('Quantity must be greater than zero.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _transferService.createTransfer(
        productVariantId: _selectedVariant!.id,
        fromLocationId: _fromLocation!.id,
        toLocationId: _toLocation!.id,
        quantity: quantity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock transfer created successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
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

  Widget _buildVariantSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '1. Product',
          subtitle: 'Search and select the variant to transfer',
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _searchController,
          onChanged: _searchVariants,
          decoration: const InputDecoration(
            labelText: 'Search Product',
            hintText: 'Model, name, barcode, size, colour',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),

        if (_selectedVariant != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_rounded),
              title: Text(
                _variantDisplayName(_selectedVariant!),
              ),
              subtitle: Text(
                'Model: ${_selectedVariant!.modelNumber}\n'
                'Quantity: ${_selectedVariant!.totalQuantity}\n'
                'Barcode: ${_selectedVariant!.barcode}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedVariant = null;
                  });
                },
              ),
            ),
          )
        else if (_searchController.text.trim().isNotEmpty)
          Container(
            constraints: const BoxConstraints(
              maxHeight: 300,
            ),
            child: _filteredVariants.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No variants found.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredVariants.length,
                    itemBuilder: (context, index) {
                      final variant = _filteredVariants[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            _variantDisplayName(variant),
                          ),
                          subtitle: Text(
                            'Model: ${variant.modelNumber}\n'
                            'Quantity: ${variant.totalQuantity}\n'
                            'Barcode: ${variant.barcode}',
                          ),
                          trailing: Text(
                            variant.price.toStringAsFixed(2),
                          ),
                          onTap: () async {
                            setState(() {
                              _selectedVariant = variant;
                              _searchController.clear();
                              _filteredVariants = _variants;
                              _variantInventory = [];
                            });

                            await _loadVariantInventory(variant);
                          },
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: '2. Transfer Details',
          subtitle: 'Pick source, destination and quantity',
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<Location>(
          key: ValueKey('from-${_fromLocation?.id}'),
          initialValue: _fromLocation,
          decoration: const InputDecoration(
            labelText: 'From Location',
            prefixIcon: Icon(Icons.file_upload_outlined),
          ),
          items: _locations.map((location) {
            final inventory = _variantInventory
                .where(
                  (item) => item.locationId == location.id,
                )
                .firstOrNull;

            final quantity = inventory?.quantity ?? 0;

            return DropdownMenuItem<Location>(
              value: location,
              child: Text(
                '${location.name} ($quantity)',
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _fromLocation = value;

              if (_toLocation?.id == value?.id) {
                _toLocation = null;
              }
            });
          },
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<Location>(
          key: ValueKey('to-${_toLocation?.id}'),
          initialValue: _toLocation,
          decoration: const InputDecoration(
            labelText: 'To Location',
            prefixIcon: Icon(Icons.file_download_outlined),
          ),
          items: _locations.map((location) {
            final inventory = _variantInventory
                .where(
                  (item) => item.locationId == location.id,
                )
                .firstOrNull;

            final quantity = inventory?.quantity ?? 0;

            return DropdownMenuItem<Location>(
              value: location,
              child: Text(
                '${location.name} ($quantity)',
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _toLocation = value;
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

        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: _isSubmitting ? null : _createTransfer,
          icon: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.swap_horiz_rounded),
          label: const Text('Transfer Stock'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Stock Transfer'),
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _loadData,
                )
              : ResponsiveFormPage(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildVariantSearch(),
                      const SizedBox(height: 24),
                      _buildTransferForm(),
                    ],
                  ),
                ),
    );
  }
}