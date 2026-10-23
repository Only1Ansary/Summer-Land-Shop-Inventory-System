import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../localization/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/colour_service.dart';
import '../../services/product_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/size_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/barcode_view.dart';
import '../../ui/reconnect_reloader.dart';

import 'product_form_screen.dart';
import 'product_variant_form_screen.dart';
import 'split_variant_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with ReconnectReloader<ProductDetailsScreen> {
  final ProductVariantService _variantService = ProductVariantService(
    ApiService(),
  );

  final ProductService _productService = ProductService(ApiService());

  final SizeService _sizeService = SizeService(ApiService());

  final ColourService _colourService = ColourService(ApiService());

  /// The product being shown. Starts as the one passed in and is
  /// refreshed after an edit so the details never go stale.
  late Product _product;

  List<ProductVariant> _variants = [];

  List<SizeModel> _sizes = [];

  List<Colour> _colours = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  bool _isLoading = false;
  String? _error;

  /// The variants after the size and colour filters, which is what the
  /// list renders. Filtering happens here so switching a filter is instant
  /// and never re-fetches the variants.
  List<ProductVariant> get _filteredVariants {
    return _variants.where((variant) {
      final matchesSize =
          _selectedSizeId == null || variant.sizeId == _selectedSizeId;

      final matchesColour =
          _selectedColourId == null || variant.colourId == _selectedColourId;

      return matchesSize && matchesColour;
    }).toList();
  }

  bool get _hasFilters => _selectedSizeId != null || _selectedColourId != null;

  @override
  void initState() {
    super.initState();

    _product = widget.product;

    _loadVariants();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        _sizeService.getSizes(),
        _colourService.getColours(),
      ]);

      if (!mounted) return;

      setState(() {
        _sizes = results[0] as List<SizeModel>;
        _colours = results[1] as List<Colour>;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Failed to refresh sizes and colours: $e');
    }
  }

  Future<void> _loadVariants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadLookups();

      final variants = await _variantService.getVariants();

      if (!mounted) return;

      setState(() {
        _variants = variants
            .where((variant) => variant.productId == _product.id)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void onReconnected() {
    _loadVariants();
  }

  Future<void> _editProduct() async {
    if (!ensureOnlineForWrite(context)) return;

    final categories = await _loadCategories();

    if (!mounted) return;

    if (categories == null) return;

    final updatedProduct = await _productService.getProduct(_product.id);

    if (!mounted) return;

    final result = await pushScreen(
      context,
      (_) => ProductFormScreen(product: updatedProduct, categories: categories),
    );

    if (result == true) {
      await _refreshProduct();
      await _loadVariants();
    }
  }

  /// Reloads the product so edits are reflected without leaving the
  /// screen.
  Future<void> _refreshProduct() async {
    try {
      final product = await _productService.getProduct(_product.id);

      if (!mounted) return;

      setState(() {
        _product = product;
      });
    } catch (_) {
      // Keep the current details if the refresh fails.
    }
  }

  Future<dynamic> _loadCategories() async {
    try {
      final service = CategoryService(ApiService());

      return await service.getCategories();
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));

      return null;
    }
  }

  Future<void> _addVariant() async {
    if (!ensureOnlineForWrite(context)) return;

    final result = await pushScreen(
      context,
      (_) => ProductVariantFormScreen(
        product: _product,
        sizes: _sizes,
        colours: _colours,
      ),
    );

    if (result == true) {
      _loadVariants();
    }
  }

  Future<void> _editVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return;

    final result = await pushScreen(
      context,
      (_) => ProductVariantFormScreen(
        product: _product,
        sizes: _sizes,
        colours: _colours,
        variant: variant,
      ),
    );

    if (result == true) {
      _loadVariants();
    }
  }

  /// A variant with no size and no colour: stock created by a purchase before
  /// it was broken down into real size/colour combinations.
  bool _isDefaultVariant(ProductVariant variant) {
    return variant.sizeId == null && variant.colourId == null;
  }

  Future<void> _splitVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return;

    final result = await pushScreen(
      context,
      (_) => SplitVariantScreen(
        product: _product,
        sourceVariant: variant,
        sizes: _sizes,
        colours: _colours,
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Variant split successfully.'))),
      );

      _loadVariants();
    }
  }

  Future<void> _deleteVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: context.tr('Delete Variant'),
      message: context.tr('Are you sure you want to delete this variant?'),
    );

    if (!confirmed) return;

    try {
      await _variantService.deleteVariant(variant.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Variant deleted successfully.'))),
      );

      _loadVariants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Product Details')),
        actions: [
          IconButton(
            tooltip: context.tr('Edit product'),
            onPressed: _editProduct,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVariant,
        tooltip: context.tr('Add variant'),
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
              SectionHeader(
                title: context.tr('Variants'),
                subtitle: context.tr('Size, colour and pricing combinations'),
              ),
              const SizedBox(height: 12),
              _buildFilterBar(),
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
              _product.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            InfoTile(label: context.tr('Model'), value: _product.modelNumber),
            InfoTile(
              label: context.tr('Category'),
              value: _product.categoryName,
            ),
            InfoTile(
              label: context.tr('Barcode'),
              value: _product.barcode.isEmpty
                  ? context.tr('N/A')
                  : _product.barcode,
            ),
            BarcodeView(_product.barcode, showText: false),
            InfoTile(
              label: context.tr('Purchase Price'),
              value: money(_product.purchasePrice),
              valueStyle: amountStyle(context, _product.purchasePrice),
            ),
            InfoTile(
              label: context.tr('Profit Margin'),
              value: '${_formatPercent(_product.profitMargin)}%',
            ),
            InfoTile(
              label: context.tr('Selling Price'),
              value: money(_product.sellingPrice),
              valueStyle: amountStyle(context, _product.sellingPrice),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPercent(double value) {
    final amount = value.round();

    if (amount == value) return amount.toString();

    return value.toString();
  }

  Widget _buildFilterBar() {
    if (_sizes.isEmpty && _colours.isEmpty) return const SizedBox.shrink();

    final sizeDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('size-$_selectedSizeId'),
      initialValue: _selectedSizeId,
      decoration: InputDecoration(
        labelText: context.tr('Size'),
        prefixIcon: const Icon(Icons.straighten_outlined),
      ),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(context.tr('All'))),
        ..._sizes.map(
          (size) =>
              DropdownMenuItem<int?>(value: size.id, child: Text(size.name)),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSizeId = value;
        });
      },
    );

    final colourDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('colour-$_selectedColourId'),
      initialValue: _selectedColourId,
      decoration: InputDecoration(
        labelText: context.tr('Colour'),
        prefixIcon: const Icon(Icons.palette_outlined),
      ),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(context.tr('All'))),
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
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sizeDropdown),
        const SizedBox(width: 10),
        Expanded(child: colourDropdown),
        if (_hasFilters) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: context.tr('Clear filters'),
            onPressed: () {
              setState(() {
                _selectedSizeId = null;
                _selectedColourId = null;
              });
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ],
    );
  }

  Widget _buildVariants() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadVariants);
    }

    if (_variants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              EmptyState(
                icon: Icons.category_outlined,
                title: context.tr('No variants yet'),
                message: context.tr(
                  'Add a variant to track stock and pricing for this product.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final variants = _filteredVariants;

    if (variants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: context.tr('No matching variants'),
                message: context.tr('Try a different size or colour.'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: variants.map((variant) {
        return _buildVariantCard(variant);
      }).toList(),
    );
  }

  Widget _buildVariantCard(ProductVariant variant) {
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
                    context.tr('Variant #{0}', [variant.id]),
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
              label: context.tr('Size'),
              value: variant.sizeName ?? context.tr('N/A'),
            ),
            InfoTile(
              label: context.tr('Colour'),
              value: variant.colourName ?? context.tr('N/A'),
            ),
            InfoTile(
              label: context.tr('Price'),
              value: money(variant.price),
              valueStyle: amountStyle(context, variant.price),
            ),
            InfoTile(label: context.tr('Barcode'), value: variant.barcode),
            BarcodeView(variant.barcode, showText: false),
            InfoTile(
              label: context.tr('Total Stock'),
              value: '${variant.totalQuantity}',
            ),
            InfoTile(
              label: context.tr('Low Stock Threshold'),
              value: '${variant.lowStockThreshold}',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDefaultVariant(variant) && variant.totalQuantity > 0)
                  TextButton.icon(
                    onPressed: () => _splitVariant(variant),
                    icon: const Icon(Icons.call_split, size: 18),
                    label: Text(context.tr('Split')),
                  ),
                TextButton.icon(
                  onPressed: () => _editVariant(variant),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.tr('Edit')),
                ),
                TextButton.icon(
                  onPressed: () => _deleteVariant(variant),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(context.tr('Delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
