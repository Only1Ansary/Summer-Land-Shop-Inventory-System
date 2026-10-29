import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
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

  /// Stock held at each location for the variant being edited.
  Map<int, int> _locationStock = {};

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

    _priceController.text = _formatPrice(widget.product.sellingPrice);

    if (isEditing) {
      final variant = widget.variant!;

      _selectedSizeId = variant.sizeId;
      _selectedColourId = variant.colourId;

      _barcodeController.text = variant.barcode;

      _thresholdController.text = variant.lowStockThreshold.toString();

      _barcodeType = variant.barcodeType;

      _currentStock = variant.totalQuantity;
    } else {
      _thresholdController.text = '2';
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

      await _loadLocationStock();
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    }
  }

  Future<void> _loadLocationStock() async {
    if (!isEditing) return;

    try {
      final inventory = await _inventoryService.getVariantInventory(
        widget.variant!.id,
      );

      if (!mounted) return;

      setState(() {
        _locationStock = {
          for (final item in inventory) item.locationId: item.quantity,
        };
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Failed to load location stock: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addSize() async {
    if (!ensureOnlineForWrite(context)) return;
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Size'),
      label: context.tr('Size Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final trimmed = name.trim();

    final existing = _sizes.where(
      (size) => size.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      _showError(context.tr('{0} already exists in sizes.', [trimmed]));
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

      _showError(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOption = false;
        });
      }
    }
  }

  Future<void> _addColour() async {
    if (!ensureOnlineForWrite(context)) return;
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Colour'),
      label: context.tr('Colour Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final trimmed = name.trim();

    final existing = _colours.where(
      (colour) => colour.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      _showError(context.tr('{0} already exists in colours.', [trimmed]));
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

      _showError(friendlyErrorMessage(context, e));
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
      _showError(context.tr('Enter a stock quantity greater than zero.'));
      return null;
    }

    if (quantity > 100000) {
      _showError(context.tr('Quantity cannot exceed 100,000.'));
      return null;
    }

    if (_selectedLocationId == null) {
      _showError(context.tr('Please select a location.'));
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

      await _loadLocationStock();
    } catch (e) {
      if (!mounted) return;

      debugPrint('Failed to refresh stock: $e');
    }
  }

  Future<void> _addStockToExistingVariant() async {
    if (!ensureOnlineForWrite(context)) return;
    if (_isAddingStock) return;

    final quantity = _validatedStockQuantity();

    if (quantity == null) return;

    final locationId = _selectedLocationId!;
    final enteredText = _stockQuantityController.text;

    _stockQuantityController.clear();

    scheduleUndoable(
      context,
      message: context.tr('Stock will be added. Tap Undo to cancel.'),
      operation: () => _inventoryService.addInventory(
        productVariantId: widget.variant!.id,
        locationId: locationId,
        quantity: quantity,
      ),
      onCommitted: _refreshStock,
      onUndone: () {
        if (mounted) {
          _stockQuantityController.text = enteredText;
        }
      },
    );
  }

  Future<void> _save() async {
    if (!ensureOnlineForWrite(context)) return;

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
        _showError(context.tr('Select a location for the initial stock.'));
        return;
      }

      if (initialStock > 100000) {
        _showError(context.tr('Quantity cannot exceed 100,000.'));
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    final sizeId = _selectedSizeId;
    final colourId = _selectedColourId;
    final barcode = _barcodeController.text.trim();
    final locationId = _selectedLocationId;

    final operation = isEditing
        ? () async {
            await _variantService.updateVariant(
              id: widget.variant!.id,
              sizeId: sizeId,
              colourId: colourId,
              barcode: barcode,
              price: price,
              lowStockThreshold: threshold,
            );
          }
        : () async {
            final createdVariant = await _variantService.createVariant(
              productId: widget.product.id,
              sizeId: sizeId,
              colourId: colourId,
              barcodeType: _barcodeType,
              barcode: barcode.isEmpty ? null : barcode,
              price: price,
              lowStockThreshold: threshold,
            );

            if (initialStock != null) {
              await _inventoryService.addInventory(
                productVariantId: createdVariant.id,
                locationId: locationId!,
                quantity: initialStock,
              );
            }
          };

    Navigator.pop(
      context,
      DeferredCrud(
        message: isEditing
            ? context.tr(
                'Changes to this variant will be saved. Tap Undo to cancel.',
              )
            : context.tr('This variant will be added. Tap Undo to cancel.'),
        operation: operation,
      ),
    );
  }

  Widget _buildStockSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: isEditing
                  ? context.tr('Add Stock')
                  : context.tr('Initial Stock'),
              subtitle: isEditing
                  ? context.tr('Top up this variant at a location.')
                  : context.tr('Optional. Leave empty to add stock later.'),
            ),
            const SizedBox(height: 12),
            if (isEditing)
              InfoTile(
                label: context.tr('Current Stock'),
                value: '$_currentStock',
                valueStyle: amountStyle(context, _currentStock.toDouble()),
              ),
            if (_locations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.tr('No locations available.')),
              )
            else ...[
              DropdownButtonFormField<int>(
                key: ValueKey('location-$_selectedLocationId'),
                initialValue: _selectedLocationId,
                decoration: InputDecoration(
                  labelText: context.tr('Location'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                items: _locations
                    .map(
                      (location) => DropdownMenuItem<int>(
                        value: location.id,
                        child: Text(
                          context.tr('{0} · {1} in stock', [
                            location.name,
                            _locationStock[location.id] ?? 0,
                          ]),
                        ),
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
                decoration: InputDecoration(
                  labelText: context.tr('Quantity'),
                  prefixIcon: const Icon(Icons.pin_outlined),
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
                    label: Text(context.tr('Add Stock')),
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
      appBar: AppBar(
        title: Text(
          isEditing ? context.tr('Edit Variant') : context.tr('Add Variant'),
        ),
      ),
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
                        context.tr('Model: {0}', [widget.product.modelNumber]),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Selling Price: {0}', [
                          money(widget.product.sellingPrice),
                        ]),
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
                      decoration: InputDecoration(
                        labelText: context.tr('Size'),
                        prefixIcon: const Icon(Icons.straighten_outlined),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(context.tr('No Size')),
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
                    label: context.tr('Add size'),
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
                      decoration: InputDecoration(
                        labelText: context.tr('Colour'),
                        prefixIcon: const Icon(Icons.palette_outlined),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(context.tr('No Colour')),
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
                    label: context.tr('Add colour'),
                    onPressed: _addColour,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (!isEditing)
                DropdownButtonFormField<int>(
                  key: ValueKey('barcode-type-$_barcodeType'),
                  initialValue: _barcodeType,
                  decoration: InputDecoration(
                    labelText: context.tr('Barcode Type'),
                    prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(context.tr('Internal')),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(context.tr('Manufacturer')),
                    ),
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
                    labelText: isEditing
                        ? context.tr('Barcode')
                        : context.tr('Manufacturer Barcode'),
                    prefixIcon: const Icon(Icons.barcode_reader),
                    helperText: !isEditing && _barcodeType == 2
                        ? context.tr('Enter the manufacturer barcode.')
                        : null,
                  ),
                  validator: (value) {
                    if (!isEditing &&
                        _barcodeType == 2 &&
                        (value == null || value.trim().isEmpty)) {
                      return context.tr('Manufacturer barcode is required.');
                    }

                    if (isEditing && (value == null || value.trim().isEmpty)) {
                      return context.tr('Barcode is required.');
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
                        Expanded(
                          child: Text(
                            context.tr(
                              'The internal barcode will be generated automatically.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                readOnly: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('Price'),
                  prefixIcon: const Icon(Icons.payments_outlined),
                  helperText: context.tr(
                    "Price is derived from the product's selling price and cannot be edited.",
                  ),
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');

                  if (price == null) {
                    return context.tr('Enter a valid price.');
                  }

                  if (price < 0) {
                    return context.tr('Price cannot be negative.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Low Stock Threshold'),
                  prefixIcon: const Icon(Icons.low_priority_outlined),
                ),
                validator: (value) {
                  final threshold = int.tryParse(value?.trim() ?? '');

                  if (threshold == null) {
                    return context.tr('Enter a valid threshold.');
                  }

                  if (threshold < 0) {
                    return context.tr('Threshold cannot be negative.');
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
                  label: Text(
                    isEditing ? context.tr('Save') : context.tr('Add Variant'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
