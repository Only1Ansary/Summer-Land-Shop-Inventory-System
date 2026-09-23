import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../services/product_variant_service.dart';

import '../../ui/app_widgets.dart';

import 'product_form_screen.dart';
import 'product_variant_form_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final List<SizeModel> sizes;
  final List<Colour> colours;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.sizes,
    required this.colours,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  final ProductVariantService _variantService =
      ProductVariantService(ApiService());

  final ProductService _productService =
      ProductService(ApiService());

  List<ProductVariant> _variants = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final variants =
          await _variantService.getVariants();

      if (!mounted) return;

      setState(() {
        _variants = variants
            .where(
              (variant) =>
                  variant.productId == widget.product.id,
            )
            .toList();
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

  Future<void> _editProduct() async {
    final categories =
        await _loadCategories();

    if (!mounted) return;

    if (categories == null) return;

    final updatedProduct = await _productService
        .getProduct(widget.product.id);

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          product: updatedProduct,
          categories: categories,
        ),
      ),
    );

    if (result == true) {
      _loadVariants();
    }
  }

  Future<dynamic> _loadCategories() async {
    try {
      final service = CategoryService(
        ApiService(),
      );

      return await service.getCategories();
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );

      return null;
    }
  }

  Future<void> _addVariant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductVariantFormScreen(
              product: widget.product,
              sizes: widget.sizes,
              colours: widget.colours,
            ),
      ),
    );

    if (result == true) {
      _loadVariants();
    }
  }

  Future<void> _editVariant(
      ProductVariant variant,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductVariantFormScreen(
              product: widget.product,
              sizes: widget.sizes,
              colours: widget.colours,
              variant: variant,
            ),
      ),
    );

    if (result == true) {
      _loadVariants();
    }
  }

  Future<void> _deleteVariant(
      ProductVariant variant,
      ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Variant',
      message: 'Are you sure you want to delete this variant?',
    );

    if (!confirmed) return;

    try {
      await _variantService.deleteVariant(
        variant.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Variant deleted successfully.',
          ),
        ),
      );

      _loadVariants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            tooltip: 'Edit product',
            onPressed: _editProduct,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVariant,
        tooltip: 'Add variant',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadVariants,
        child: WideContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProductInfo(),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Variants',
                subtitle: 'Size, colour and pricing combinations',
              ),
              const SizedBox(height: 4),
              _buildVariants(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            InfoTile(
              label: 'Model',
              value: widget.product.modelNumber,
            ),
            InfoTile(
              label: 'Category',
              value: widget.product.categoryName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariants() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadVariants,
      );
    }

    if (_variants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              EmptyState(
                icon: Icons.category_outlined,
                title: 'No variants yet',
                message:
                    'Add a variant to track stock and pricing for this product.',
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _variants.map(
        (variant) {
          return _buildVariantCard(
            variant,
          );
        },
      ).toList(),
    );
  }

  Widget _buildVariantCard(
      ProductVariant variant,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Variant #${variant.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (variant.isLowStock) const LowStockBadge(),
              ],
            ),
            const Divider(height: 20),
            InfoTile(
              label: 'Size',
              value: variant.sizeName ?? 'N/A',
            ),
            InfoTile(
              label: 'Colour',
              value: variant.colourName ?? 'N/A',
            ),
            InfoTile(
              label: 'Price',
              value: money(variant.price),
            ),
            InfoTile(
              label: 'Barcode',
              value: variant.barcode,
            ),
            InfoTile(
              label: 'Total Stock',
              value: '${variant.totalQuantity}',
            ),
            InfoTile(
              label: 'Low Stock Threshold',
              value: '${variant.lowStockThreshold}',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editVariant(variant),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteVariant(variant),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}