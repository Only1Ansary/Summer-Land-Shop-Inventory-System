import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../models/location.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/colour_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/barcode_view.dart';

class ProductVariantFormScreen extends StatefulWidget {
  final Product product;
  final List<SizeModel> sizes;
  final List<Colour> colours;
  final ProductVariant? variant;

  const ProductVariantFormScreen({
    super.key,
    required this.product,
    required this.sizes,
    required this.colours,
    this.variant,
  });

  @override
  State<ProductVariantFormScreen> createState() =>
      _ProductVariantFormScreenState();
}

class _ProductVariantFormScreenState extends State<ProductVariantFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeController = TextEditingController();

  final _priceController = TextEditingController();

  final _thresholdController = TextEditingController();

  final _stockQuantityController = TextEditingController();

  final ProductVariantService _variantService = ProductVariantService(
    ApiService(),
  );

  final SizeService _sizeService = SizeService(ApiService());

  final ColourService _colourService = ColourService(ApiService());

  final InventoryService _inventoryService = InventoryService(ApiService());

  final LocationService _locationService = LocationService(ApiService());

  late List<SizeModel> _sizes;

  late List<Colour> _colours;

  List<Location> _locations = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  int? _selectedLocationId;

  int _barcodeType = 1;

  bool _isSaving = false;

  bool _isCreatingOption = false;

  bool _isAddingStock = false;

  late int _currentStock = 0;

  bool get isEditing => widget.variant != null;

  @override
  void initState() {
    super.initState();

    _sizes = List.of(widget.sizes);
    _colours = List.of(widget.colours);

    _loadLocations();

    if (isEditing) {
      final variant = widget.variant!;

      _selectedSizeId = variant.sizeId;
      _selectedColourId = variant.colourId;

      _barcodeController.text = variant.barcode;

      _priceController.text = variant.price.toString();

      _thresholdController.text = variant.lowStockThreshold.toString();

      _barcodeType = variant.barcodeType;

      _currentStock = variant.totalQuantity;
    } else {
      _priceController.text = _formatPrice(widget.product.sellingPrice);
      _thresholdController.text = '0';
    }
  }

  static String _formatPrice(double value) {
    if (value <= 0) return '0';

    final amount = value.round();

    if (value == amount) return amount.toString();

    return value.toString();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    _stockQuantityController.dispose();

    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await _locationService.getLocations();

      if (!mounted) return;

      setState(() {
        _locations = locations;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addSize() async {
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: 'Add Size',
      label: 'Size Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final trimmed = name.trim();

    final existing = _sizes.where(
      (size) => size.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      _showError('$trimmed already exists in sizes.');
      return;
    }

    setState(() {
      _isCreatingOption = true;
    });

    try {
      final size = await _sizeService.createSize(trimmed);

      if (!mounted) return;

      setState(() {
        _sizes = [..._sizes, size];
        _selectedSizeId = size.id;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOption = false;
        });
      }
    }
  }

  Future<void> _addColour() async {
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: 'Add Colour',
      label: 'Colour Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final trimmed = name.trim();

    final existing = _colours.where(
      (colour) => colour.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      _showError('$trimmed already exists in colours.');
      return;
    }

    setState(() {
      _isCreatingOption = true;
    });

    try {
      final colour = await _colourService.createColour(trimmed);

      if (!mounted) return;

      setState(() {
        _colours = [..._colours, colour];
        _selectedColourId = colour.id;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOption = false;
        });
      }
    }
  }

  int? _stockQuantity() {
    final quantity = int.tryParse(_stockQuantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      return null;
    }

    return quantity;
  }

  /// Validates the stock fields. Returns the quantity to add, or null when
  /// the entry is invalid (message already shown).
  int? _validatedStockQuantity() {
    final quantity = _stockQuantity();

    if (quantity == null) {
      _showError('Enter a stock quantity greater than zero.');
      return null;
    }

    if (quantity > 100000) {
      _showError('Quantity cannot exceed 100,000.');
      return null;
    }

    if (_selectedLocationId == null) {
      _showError('Please select a location.');
      return null;
    }

    return quantity;
  }

  Future<void> _refreshStock() async {
    if (!isEditing) return;

    try {
      final variant = await _variantService.getVariant(widget.variant!.id);

      if (!mounted) return;

      setState(() {
        _currentStock = variant.totalQuantity;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Failed to refresh stock: $e');
    }
  }

  Future<void> _addStockToExistingVariant() async {
    if (_isAddingStock) return;

    final quantity = _validatedStockQuantity();

    if (quantity == null) return;

    setState(() {
      _isAddingStock = true;
    });

    try {
      await _inventoryService.addInventory(
        productVariantId: widget.variant!.id,
        locationId: _selectedLocationId!,
        quantity: quantity,
      );

      if (!mounted) return;

      _stockQuantityController.clear();

      await _refreshStock();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock added. Total is now $_currentStock.')),
      );
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isAddingStock = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final price = double.tryParse(_priceController.text.trim());

    final threshold = int.tryParse(_thresholdController.text.trim());

    if (price == null || price < 0) {
      return;
    }

    if (threshold == null || threshold < 0) {
      return;
    }

    final initialStock = _stockQuantity();

    if (initialStock != null) {
      if (_selectedLocationId == null) {
        _showError('Select a location for the initial stock.');
        return;
      }

      if (initialStock > 100000) {
        _showError('Quantity cannot exceed 100,000.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (isEditing) {
        await _variantService.updateVariant(
          id: widget.variant!.id,
          sizeId: _selectedSizeId,
          colourId: _selectedColourId,
          barcode: _barcodeController.text.trim(),
          price: price,
          lowStockThreshold: threshold,
        );
      } else {
        final createdVariant = await _variantService.createVariant(
          productId: widget.product.id,
          sizeId: _selectedSizeId,
          colourId: _selectedColourId,
          barcodeType: _barcodeType,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          price: price,
          lowStockThreshold: threshold,
        );

        final initialStock = _stockQuantity();

        if (initialStock != null) {
          await _inventoryService.addInventory(
            productVariantId: createdVariant.id,
            locationId: _selectedLocationId!,
            quantity: initialStock,
          );
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildStockSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: isEditing ? 'Add Stock' : 'Initial Stock',
              subtitle: isEditing
                  ? 'Top up this variant at a location.'
                  : 'Optional. Leave empty to add stock later.',
            ),
            const SizedBox(height: 12),
            if (isEditing)
              InfoTile(
                label: 'Current Stock',
                value: '$_currentStock',
                valueStyle: amountStyle(context, _currentStock.toDouble()),
              ),
            if (_locations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No locations available.'),
              )
            else ...[
              DropdownButtonFormField<int>(
                key: ValueKey('location-$_selectedLocationId'),
                initialValue: _selectedLocationId,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: _locations
                    .map(
                      (location) => DropdownMenuItem<int>(
                        value: location.id,
                        child: Text(location.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLocationId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _stockQuantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _isAddingStock
                        ? null
                        : _addStockToExistingVariant,
                    icon: _isAddingStock
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_box_outlined),
                    label: const Text('Add Stock'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton.filledTonal(
        onPressed: _isCreatingOption ? null : onPressed,
        icon: _isCreatingOption
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Variant' : 'Add Variant')),
      body: ResponsiveFormPage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model: ${widget.product.modelNumber}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selling Price: ${money(widget.product.sellingPrice)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: amountColor(
                            context,
                            widget.product.sellingPrice,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('size-$_selectedSizeId'),
                      initialValue: _selectedSizeId,
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No Size'),
                        ),
                        ..._sizes.map(
                          (size) => DropdownMenuItem<int?>(
                            value: size.id,
                            child: Text(size.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSizeId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildAddButton(
                    icon: Icons.straighten_outlined,
                    label: 'Add size',
                    onPressed: _addSize,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('colour-$_selectedColourId'),
                      initialValue: _selectedColourId,
                      decoration: const InputDecoration(
                        labelText: 'Colour',
                        prefixIcon: Icon(Icons.palette_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No Colour'),
                        ),
                        ..._colours.map(
                          (colour) => DropdownMenuItem<int?>(
                            value: colour.id,
                            child: Text(colour.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedColourId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildAddButton(
                    icon: Icons.palette_outlined,
                    label: 'Add colour',
                    onPressed: _addColour,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (!isEditing)
                DropdownButtonFormField<int>(
                  key: ValueKey('barcode-type-$_barcodeType'),
                  initialValue: _barcodeType,
                  decoration: const InputDecoration(
                    labelText: 'Barcode Type',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Internal')),
                    DropdownMenuItem(value: 2, child: Text('Manufacturer')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _barcodeType = value;

                      if (_barcodeType == 1) {
                        _barcodeController.clear();
                      }
                    });
                  },
                ),

              if (!isEditing) const SizedBox(height: 16),

              if (isEditing || _barcodeType == 2)
                TextFormField(
                  controller: _barcodeController,
                  enabled: isEditing || _barcodeType == 2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Barcode' : 'Manufacturer Barcode',
                    prefixIcon: const Icon(Icons.barcode_reader),
                    helperText: !isEditing && _barcodeType == 2
                        ? 'Enter the manufacturer barcode.'
                        : null,
                  ),
                  validator: (value) {
                    if (!isEditing &&
                        _barcodeType == 2 &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Manufacturer barcode is required.';
                    }

                    if (isEditing && (value == null || value.trim().isEmpty)) {
                      return 'Barcode is required.';
                    }

                    return null;
                  },
                ),

              // Live preview: the numbers typed above are drawn as a real
              // Code 128 barcode, ready to print or scan.
              if ((isEditing || _barcodeType == 2) &&
                  _barcodeController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                BarcodeView(_barcodeController.text),
              ],

              if (!isEditing && _barcodeType == 1) const SizedBox(height: 16),

              if (!isEditing && _barcodeType == 1)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'The internal barcode will be generated automatically.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Defaults to the product selling price.',
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');

                  if (price == null) {
                    return 'Enter a valid price.';
                  }

                  if (price < 0) {
                    return 'Price cannot be negative.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Threshold',
                  prefixIcon: Icon(Icons.low_priority_outlined),
                ),
                validator: (value) {
                  final threshold = int.tryParse(value?.trim() ?? '');

                  if (threshold == null) {
                    return 'Enter a valid threshold.';
                  }

                  if (threshold < 0) {
                    return 'Threshold cannot be negative.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildStockSection(),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Save' : 'Add Variant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
