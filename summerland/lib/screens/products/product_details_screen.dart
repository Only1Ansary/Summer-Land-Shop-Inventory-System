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
import '../../ui/app_widgets.dart';
import '../../ui/barcode_view.dart';
import '../../ui/reconnect_reloader.dart';

import 'product_form_screen.dart';
import 'product_variant_form_screen.dart';
import 'split_variant_screen.dart';

/// Screens at least this wide show the variant table and the selected
/// variant's details side by side. Narrower screens open a full page.
const double _kMasterDetailBreakpoint = 840;

/// Fixed width of the variant details panel on wide screens; the table
/// takes all the remaining space.
const double _kDetailPanelWidth = 500;

/// Height of the pinned block: the search row plus the table header bar.
const double _kPinnedHeaderExtent = 108;

/// Columns the variant table can be sorted by.
enum _SortColumn { size, colour, price, stock }

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

  final TextEditingController _searchController = TextEditingController();

  /// The product being shown. Starts as the one passed in and is
  /// refreshed after an edit so the details never go stale.
  late Product _product;

  List<ProductVariant> _variants = [];

  List<SizeModel> _sizes = [];

  List<Colour> _colours = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  /// Free-text search over barcode, size and colour. Purely local, so
  /// typing never re-fetches anything.
  String _searchQuery = '';

  /// Whether the inline size/colour filter panel is open.
  bool _showFilters = false;

  /// Table sorting. Null means the order the server returned.
  _SortColumn? _sortColumn;
  bool _sortAscending = true;

  /// The variant shown in the detail panel on wide screens.
  int? _selectedVariantId;

  bool _isLoading = false;
  String? _error;

  /// The variants after search, size and colour filters and sorting, which
  /// is what the table renders. All of it happens here so changing a filter
  /// or a sort is instant and never re-fetches the variants.
  List<ProductVariant> get _filteredVariants {
    final query = _searchQuery.trim().toLowerCase();

    final list = _variants.where((variant) {
      final matchesSize =
          _selectedSizeId == null || variant.sizeId == _selectedSizeId;

      final matchesColour =
          _selectedColourId == null || variant.colourId == _selectedColourId;

      final matchesSearch =
          query.isEmpty ||
              variant.barcode.toLowerCase().contains(query) ||
              (variant.sizeName ?? '').toLowerCase().contains(query) ||
              (variant.colourName ?? '').toLowerCase().contains(query);

      return matchesSize && matchesColour && matchesSearch;
    }).toList();

    final column = _sortColumn;

    if (column != null) {
      list.sort(
            (a, b) => _sortAscending
            ? _compare(a, b, column)
            : _compare(b, a, column),
      );
    }

    return list;
  }

  /// Empty names sort last when ascending.
  static String _nameKey(String? value) => (value ?? '\uffff').toLowerCase();

  static int _compare(ProductVariant a, ProductVariant b, _SortColumn column) {
    return switch (column) {
      _SortColumn.size => _nameKey(a.sizeName).compareTo(_nameKey(b.sizeName)),
      _SortColumn.colour => _nameKey(
        a.colourName,
      ).compareTo(_nameKey(b.colourName)),
      _SortColumn.price => a.price.compareTo(b.price),
      _SortColumn.stock => a.totalQuantity.compareTo(b.totalQuantity),
    };
  }

  /// Tap a column header: ascending, tap again: descending, again: off.
  void _sortBy(_SortColumn column) {
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null;
        _sortAscending = true;
      }
    });
  }

  int get _activeFilterCount =>
      (_selectedSizeId != null ? 1 : 0) + (_selectedColourId != null ? 1 : 0);

  bool get _hasFilters => _activeFilterCount > 0 || _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _product = widget.product;

    _loadVariants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    final result = await pushScreen<DeferredCrud>(
      context,
          (_) => ProductFormScreen(product: updatedProduct, categories: categories),
    );

    if (result == null) return;

    scheduleDeferredCrud(
      context,
      result,
      onCommitted: () async {
        await _refreshProduct();
        await _loadVariants();
      },
    );
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

    final result = await pushScreen<DeferredCrud>(
      context,
          (_) => ProductVariantFormScreen(
        product: _product,
        sizes: _sizes,
        colours: _colours,
      ),
    );

    if (result == null) return;

    scheduleDeferredCrud(context, result, onCommitted: _loadVariants);
  }

  /// Returns true when an edit was submitted (false if the person backed
  /// out or is offline).
  Future<bool> _editVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return false;

    final result = await pushScreen<DeferredCrud>(
      context,
          (_) => ProductVariantFormScreen(
        product: _product,
        sizes: _sizes,
        colours: _colours,
        variant: variant,
      ),
    );

    if (result == null) return false;

    if (!mounted) return true;

    scheduleDeferredCrud(context, result, onCommitted: _loadVariants);

    return true;
  }

  /// A variant with no size and no colour: stock created by a purchase before
  /// it was broken down into real size/colour combinations.
  bool _isDefaultVariant(ProductVariant variant) {
    return variant.sizeId == null && variant.colourId == null;
  }

  bool _canSplit(ProductVariant variant) {
    return _isDefaultVariant(variant) && variant.totalQuantity > 0;
  }

  Future<bool> _splitVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return false;

    final result = await pushScreen<bool>(
      context,
          (_) => SplitVariantScreen(
        product: _product,
        sourceVariant: variant,
        sizes: _sizes,
        colours: _colours,
      ),
    );

    if (result == true) {
      _loadVariants();
      return true;
    }

    return false;
  }

  Future<bool> _deleteVariant(ProductVariant variant) async {
    if (!ensureOnlineForWrite(context)) return false;

    final confirmed = await showAppConfirmDialog(
      context,
      title: context.tr('Delete Variant'),
      message: context.tr('Are you sure you want to delete this variant?'),
    );

    if (!confirmed) return false;

    if (!mounted) return true;

    scheduleUndoable(
      context,
      message: context.tr('This variant will be deleted. Tap Undo to cancel.'),
      operation: () => _variantService.deleteVariant(variant.id),
      onCommitted: _loadVariants,
    );

    return true;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _kMasterDetailBreakpoint;

          if (!wide) {
            return WideContent(child: _buildListPane(wide: false));
          }

          return Row(
            children: [
              Expanded(child: _buildListPane(wide: true)),
              const VerticalDivider(width: 1),
              SizedBox(width: _kDetailPanelWidth, child: _buildDetailPane()),
            ],
          );
        },
      ),
    );
  }

  /// The variant shown in the side panel: the one the person tapped,
  /// or the first visible one when nothing (valid) is selected yet.
  ProductVariant? get _panelVariant {
    final visible = _filteredVariants;

    for (final variant in visible) {
      if (variant.id == _selectedVariantId) return variant;
    }

    return visible.isEmpty ? null : visible.first;
  }

  Widget _buildListPane({required bool wide}) {
    final showTable = _variants.isNotEmpty || _hasFilters;

    return RefreshIndicator(
      onRefresh: _loadVariants,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildProductInfo(),
            ),
          ),
          if (showTable)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                extent: _kPinnedHeaderExtent,
                child: Column(
                  children: [_buildSearchRow(), _buildTableHeader()],
                ),
              ),
            ),
          if (showTable)
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _showFilters
                    ? _buildFilterPanel()
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ..._buildVariantSlivers(wide: wide),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Product info (always visible)
  // ---------------------------------------------------------------------

  /// Everything about the product in one card: name, the three prices as
  /// a stat row, the details and the barcode.
  Widget _buildProductInfo() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: context.tr('Purchase Price'),
                        value: money(_product.purchasePrice),
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.outlineVariant),
                    Expanded(
                      child: _MiniStat(
                        label: context.tr('Profit Margin'),
                        value: '${_formatPercent(_product.profitMargin)}%',
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.outlineVariant),
                    Expanded(
                      child: _MiniStat(
                        label: context.tr('Selling Price'),
                        value: money(_product.sellingPrice),
                        highlight: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
            Center(child: BarcodeView(_product.barcode, showText: false)),
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

  // ---------------------------------------------------------------------
  // Pinned search, table header and inline filters
  // ---------------------------------------------------------------------

  Widget _buildSearchRow() {
    final hasLookups = _sizes.isNotEmpty || _colours.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: context.tr('Search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  tooltip: context.tr('Clear filters'),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (hasLookups) ...[
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              child: IconButton.filledTonal(
                tooltip: '${context.tr('Size')} / ${context.tr('Colour')}',
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(_showFilters ? Icons.expand_less : Icons.tune),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A tinted bar of column titles that double as sort buttons.
  Widget _buildTableHeader() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _headerCell(context.tr('Size'), _SortColumn.size, flex: 3),
            _headerCell(context.tr('Colour'), _SortColumn.colour, flex: 4),
            _headerCell(
              context.tr('Price'),
              _SortColumn.price,
              flex: 3,
              alignEnd: true,
            ),
            _headerCell(
              context.tr('Stock'),
              _SortColumn.stock,
              flex: 2,
              alignEnd: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(
      String label,
      _SortColumn column, {
        required int flex,
        bool alignEnd = false,
      }) {
    final colors = Theme.of(context).colorScheme;
    final active = _sortColumn == column;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _sortBy(column),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (active)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tap-to-filter chips that open right under the header, so picking a
  /// size or colour is one tap and the table stays visible. Only sizes and
  /// colours this product actually uses are offered, so a filter can never
  /// lead to an empty list.
  Widget _buildFilterPanel() {
    final usedSizeIds = _variants.map((v) => v.sizeId).toSet();
    final usedColourIds = _variants.map((v) => v.colourId).toSet();

    final sizes = _sizes.where((size) => usedSizeIds.contains(size.id)).toList();
    final colours = _colours
        .where((colour) => usedColourIds.contains(colour.id))
        .toList();

    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sizes.isNotEmpty) ...[
                  Text(context.tr('Size'), style: labelStyle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: sizes.map((size) {
                      return FilterChip(
                        label: Text(size.name),
                        selected: _selectedSizeId == size.id,
                        onSelected: (selected) {
                          setState(() {
                            _selectedSizeId = selected ? size.id : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (sizes.isNotEmpty && colours.isNotEmpty)
                  const SizedBox(height: 10),
                if (colours.isNotEmpty) ...[
                  Text(context.tr('Colour'), style: labelStyle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: colours.map((colour) {
                      return FilterChip(
                        label: Text(colour.name),
                        selected: _selectedColourId == colour.id,
                        onSelected: (selected) {
                          setState(() {
                            _selectedColourId = selected ? colour.id : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (_activeFilterCount > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSizeId = null;
                          _selectedColourId = null;
                        });
                      },
                      child: Text(context.tr('Clear filters')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Variant table
  // ---------------------------------------------------------------------

  List<Widget> _buildVariantSlivers({required bool wide}) {
    Widget box(Widget child) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        sliver: SliverToBoxAdapter(child: child),
      );
    }

    if (_isLoading) {
      return [box(const LoadingState())];
    }

    if (_error != null) {
      return [box(ErrorState(message: _error!, onRetry: _loadVariants))];
    }

    if (_variants.isEmpty) {
      return [
        box(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.category_outlined,
                title: context.tr('No variants yet'),
                message: context.tr(
                  'Add a variant to track stock and pricing for this product.',
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final variants = _filteredVariants;

    if (variants.isEmpty) {
      return [
        box(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: context.tr('No matching variants'),
                message: context.tr('Try a different search, size or colour.'),
              ),
            ),
          ),
        ),
      ];
    }

    final selectedId = wide ? _panelVariant?.id : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 2, bottom: 88),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final variant = variants[index];

            return _buildVariantRow(
              variant,
              wide: wide,
              selected: variant.id == selectedId,
            );
          }, childCount: variants.length),
        ),
      ),
    ];
  }

  /// One rounded table row. The size sits in a tinted tag, stock in a pill,
  /// and low stock adds a red edge on the left plus a red pill; nothing
  /// else is coloured.
  Widget _buildVariantRow(
      ProductVariant variant, {
        required bool wide,
        required bool selected,
      }) {
    final colors = Theme.of(context).colorScheme;
    final low = variant.isLowStock;

    final cells = <Widget>[
      if (_isDefaultVariant(variant))
        Expanded(
          flex: 7,
          child: Text(
            context.tr('Variant #{0}', [variant.id]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        )
      else ...[
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: variant.sizeName == null
                ? const Text('—')
                : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                variant.sizeName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            variant.colourName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ],
      Expanded(
        flex: 3,
        child: Text(
          money(variant.price),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
        ),
      ),
      Expanded(
        flex: 2,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: low
                  ? colors.errorContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (low) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  '${variant.totalQuantity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: low ? colors.onErrorContainer : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.07)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openVariant(variant, wide: wide),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(children: cells),
              ),
              if (low)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: colors.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Variant details
  // ---------------------------------------------------------------------

  /// Wide screens: select the row and show it in the side panel.
  /// Phones: open the full details page.
  void _openVariant(ProductVariant variant, {required bool wide}) {
    if (wide) {
      setState(() {
        _selectedVariantId = variant.id;
      });

      return;
    }

    pushScreen<void>(
      context,
          (pageContext) => _VariantDetailPage(
        body: _VariantDetailView(variant: variant),
        actions: _buildVariantActions(variant, pageContext: pageContext),
      ),
    );
  }

  /// Edit / Split / Delete for one variant. On the full page the page closes
  /// after an action completes, since the list reloads behind it.
  Widget _buildVariantActions(
      ProductVariant variant, {
        BuildContext? pageContext,
      }) {
    Future<void> finish(Future<bool> action) async {
      final done = await action;

      if (done && pageContext != null && pageContext.mounted) {
        Navigator.pop(pageContext);
      }
    }

    return _VariantActions(
      canSplit: _canSplit(variant),
      onSplit: () => finish(_splitVariant(variant)),
      onEdit: () => finish(_editVariant(variant)),
      onDelete: () => finish(_deleteVariant(variant)),
    );
  }

  Widget _buildDetailPane() {
    final variant = _panelVariant;

    if (variant == null) {
      return Center(
        child: EmptyState(
          icon: Icons.touch_app_outlined,
          title: context.tr('Variants'),
          message: context.tr('Select a variant'),
        ),
      );
    }

    return SingleChildScrollView(
      key: ValueKey('detail-${variant.id}'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VariantDetailView(variant: variant),
          const SizedBox(height: 16),
          _buildVariantActions(variant),
        ],
      ),
    );
  }
}

/// The full-page version of the variant details, used on phones. The
/// actions sit in a bar at the bottom so they never scroll out of reach.
class _VariantDetailPage extends StatelessWidget {
  final Widget body;
  final Widget actions;

  const _VariantDetailPage({required this.body, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Product Details'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: actions,
            ),
          ),
        ),
      ),
    );
  }
}

/// One variant, laid out as: its size and colour as tags, a ring showing
/// how much stock there is against the low-stock threshold, the price, and
/// the barcode. Only the app's own cards and theme colours are used.
class _VariantDetailView extends StatelessWidget {
  final ProductVariant variant;

  const _VariantDetailView({required this.variant});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final low = variant.isLowStock;
    final threshold = variant.lowStockThreshold;

    // Full ring at twice the threshold, so a variant at its threshold is
    // visibly half empty.
    final double level = threshold > 0
        ? (variant.totalQuantity / (threshold * 2)).clamp(0.0, 1.0).toDouble()
        : (variant.totalQuantity > 0 ? 1.0 : 0.0);

    const tagStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

    final tags = <Widget>[
      if (variant.sizeName != null)
        Chip(
          avatar: const Icon(Icons.straighten_outlined, size: 18),
          label: Text(variant.sizeName!),
          labelStyle: tagStyle,
        ),
      if (variant.colourName != null)
        Chip(
          avatar: const Icon(Icons.palette_outlined, size: 18),
          label: Text(variant.colourName!),
          labelStyle: tagStyle,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tags.isEmpty)
          Text(
            context.tr('Variant #{0}', [variant.id]),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          )
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: tags),
          const SizedBox(height: 8),
          Text(
            context.tr('Variant #{0}', [variant.id]),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: level,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: colors.surfaceContainerHighest,
                          color: low ? colors.error : colors.primary,
                        ),
                      ),
                      Center(
                        child: Text(
                          '${variant.totalQuantity}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: low ? colors.error : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Total Stock'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (low) ...[
                        const SizedBox(height: 6),
                        const LowStockBadge(),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${context.tr('Low Stock Threshold')}: $threshold',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(
                  context.tr('Price'),
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  money(variant.price),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Barcode'),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: BarcodeView(variant.barcode, showText: false)),
                const SizedBox(height: 8),
                Center(
                  child: SelectableText(
                    variant.barcode.isEmpty
                        ? context.tr('N/A')
                        : variant.barcode,
                    style: const TextStyle(
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small centred stat: label above, value below.
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: highlight ? colors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit (primary), Delete and, for unsplit stock, Split.
class _VariantActions extends StatelessWidget {
  final bool canSplit;
  final VoidCallback onSplit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariantActions({
    required this.canSplit,
    required this.onSplit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (canSplit) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSplit,
              icon: const Icon(Icons.call_split, size: 18),
              label: Text(context.tr('Split')),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(context.tr('Edit')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.tr('Delete')),
          ),
        ),
      ],
    );
  }
}

/// Keeps the search box and table header fixed at the top while the
/// variants scroll underneath them.
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _PinnedHeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) => true;
}