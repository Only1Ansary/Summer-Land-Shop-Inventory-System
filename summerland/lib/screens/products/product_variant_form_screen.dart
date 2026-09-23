import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/product_variant_service.dart';

import '../../ui/app_widgets.dart';

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

class _ProductVariantFormScreenState
    extends State<ProductVariantFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeController =
      TextEditingController();

  final _priceController =
      TextEditingController();

  final _thresholdController =
      TextEditingController();

  final ProductVariantService _variantService =
      ProductVariantService(ApiService());

  int? _selectedSizeId;
  int? _selectedColourId;

  int _barcodeType = 1;

  bool _isSaving = false;

  bool get isEditing => widget.variant != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final variant = widget.variant!;

      _selectedSizeId = variant.sizeId;
      _selectedColourId = variant.colourId;

      _barcodeController.text =
          variant.barcode;

      _priceController.text =
          variant.price.toString();

      _thresholdController.text =
          variant.lowStockThreshold.toString();

      _barcodeType = variant.barcodeType;
    } else {
      _priceController.text = '0';
      _thresholdController.text = '0';
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final price = double.tryParse(
      _priceController.text.trim(),
    );

    final threshold = int.tryParse(
      _thresholdController.text.trim(),
    );

    if (price == null || price < 0) {
      return;
    }

    if (threshold == null || threshold < 0) {
      return;
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
        await _variantService.createVariant(
          productId: widget.product.id,
          sizeId: _selectedSizeId,
          colourId: _selectedColourId,
          barcodeType: _barcodeType,
          barcode:
              _barcodeController.text.trim().isEmpty
                  ? null
                  : _barcodeController.text.trim(),
          price: price,
          lowStockThreshold: threshold,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Variant'
              : 'Add Variant',
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
                        'Model: ${widget.product.modelNumber}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<int?>(
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
                  ...widget.sizes.map(
                    (size) =>
                        DropdownMenuItem<int?>(
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

              const SizedBox(height: 16),

              DropdownButtonFormField<int?>(
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
                  ...widget.colours.map(
                    (colour) =>
                        DropdownMenuItem<int?>(
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
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        'Internal',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(
                        'Manufacturer',
                      ),
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

              if (!isEditing)
                const SizedBox(height: 16),

              if (isEditing ||
                  _barcodeType == 2)
                TextFormField(
                  controller: _barcodeController,
                  enabled: isEditing || _barcodeType == 2,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Barcode' : 'Manufacturer Barcode',
                    prefixIcon: const Icon(Icons.barcode_reader),
                    helperText:
                        !isEditing && _barcodeType == 2
                            ? 'Enter the manufacturer barcode.'
                            : null,
                  ),
                  validator: (value) {
                    if (!isEditing &&
                        _barcodeType == 2 &&
                        (value == null ||
                            value.trim().isEmpty)) {
                      return 'Manufacturer barcode is required.';
                    }

                    if (isEditing &&
                        (value == null ||
                            value.trim().isEmpty)) {
                      return 'Barcode is required.';
                    }

                    return null;
                  },
                ),

              if (!isEditing &&
                  _barcodeType == 1)
                const SizedBox(height: 16),

              if (!isEditing &&
                  _barcodeType == 1)
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
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final price =
                      double.tryParse(
                        value?.trim() ?? '',
                      );

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
                  final threshold =
                      int.tryParse(
                        value?.trim() ?? '',
                      );

                  if (threshold == null) {
                    return 'Enter a valid threshold.';
                  }

                  if (threshold < 0) {
                    return 'Threshold cannot be negative.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isEditing
                        ? 'Save'
                        : 'Add Variant',
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