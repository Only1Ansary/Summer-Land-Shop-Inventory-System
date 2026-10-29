import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../localization/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';

import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final List<Category> categories;

  const ProductFormScreen({super.key, this.product, required this.categories});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _modelController = TextEditingController();

  final _barcodeController = TextEditingController();

  final _purchasePriceController = TextEditingController();

  final _profitMarginController = TextEditingController();

  final _nameController = TextEditingController();

  final ProductService _productService = ProductService(ApiService());

  int? _selectedCategoryId;
  bool _isSaving = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    if (widget.product != null) {
      _modelController.text = widget.product!.modelNumber;

      _barcodeController.text = widget.product!.barcode;

      _purchasePriceController.text = _formatInt(widget.product!.purchasePrice);

      _profitMarginController.text = _formatInt(widget.product!.profitMargin);

      _nameController.text = widget.product!.name;

      _selectedCategoryId = widget.product!.categoryId;
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _profitMarginController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  static String _formatInt(double value) {
    final amount = value.round();

    if (amount == 0) return '';

    return amount.toString();
  }

  static int? _parseInt(String text) {
    final value = int.tryParse(text.trim());

    if (value == null) return null;

    return value;
  }

  double _computedSellingPrice() {
    final purchasePrice = _parseInt(_purchasePriceController.text) ?? 0;
    final profitMargin = _parseInt(_profitMarginController.text) ?? 0;

    return purchasePrice + (purchasePrice * profitMargin / 100);
  }

  Future<void> _save() async {
    if (!ensureOnlineForWrite(context)) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select a category.'))),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final modelNumber = _modelController.text.trim();
    final barcode = _barcodeController.text.trim();
    final purchasePrice = _parseInt(_purchasePriceController.text)!;
    final profitMargin = _parseInt(_profitMarginController.text)!;
    final categoryId = _selectedCategoryId!;

    final operation = isEditing
        ? () async {
            await _productService.updateProduct(
              id: widget.product!.id,
              modelNumber: modelNumber,
              barcode: barcode,
              purchasePrice: purchasePrice,
              profitMargin: profitMargin,
              name: name,
              categoryId: categoryId,
            );
          }
        : () async {
            await _productService.createProduct(
              modelNumber: modelNumber,
              barcode: barcode,
              purchasePrice: purchasePrice,
              profitMargin: profitMargin,
              name: name,
              categoryId: categoryId,
            );
          };

    Navigator.pop(
      context,
      DeferredCrud(
        message: isEditing
            ? context.tr(
                'Changes to "{0}" will be saved. Tap Undo to cancel.',
                [name],
              )
            : context.tr('"{0}" will be added. Tap Undo to cancel.', [name]),
        operation: operation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? context.tr('Edit Product') : context.tr('Add Product'),
        ),
      ),
      body: ResponsiveFormPage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: context.tr('Model Number'),
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('Model number is required.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: context.tr('Barcode (optional)'),
                  prefixIcon: const Icon(Icons.qr_code_2),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('Product Name'),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('Product name is required.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _purchasePriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Purchase Price'),
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: '₦',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('Purchase price is required.');
                  }

                  final price = _parseInt(value);

                  if (price == null || price <= 0) {
                    return context.tr('Enter a positive whole number.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _profitMarginController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Profit Margin (%)'),
                  prefixIcon: const Icon(Icons.percent),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('Profit margin is required.');
                  }

                  final margin = _parseInt(value);

                  if (margin == null || margin <= 0) {
                    return context.tr('Enter a positive whole number.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              if (_computedSellingPrice() > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sell_outlined),
                  title: Text(context.tr('Selling Price')),
                  subtitle: Text(
                    context.tr('Purchase price plus your profit margin'),
                  ),
                  trailing: Text(
                    money(_computedSellingPrice()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: amountColor(context, _computedSellingPrice()),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                key: ValueKey('category-$_selectedCategoryId'),
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: context.tr('Category'),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return context.tr('Category is required.');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isEditing ? context.tr('Save') : context.tr('Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
