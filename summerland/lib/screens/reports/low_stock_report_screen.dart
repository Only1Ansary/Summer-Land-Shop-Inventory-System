import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/report_service.dart';
import '../../models/category.dart';
import '../../models/reports/low_stock_report.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/barcode_view.dart';
import '../../ui/reconnect_reloader.dart';
import '../../ui/report_widgets.dart';

enum _StockFilter { all, low, out }

class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen>
    with ReconnectReloader<LowStockReportScreen> {
  late final ReportService _reportService;
  late final CategoryService _categoryService;

  LowStockReport? _report;
  List<Category> _categories = [];
  int? _categoryId;
  _StockFilter _filter = _StockFilter.all;

  bool _loading = true;
  String? _error;

  static const int _pageSize = 10;
  int _currentPage = 0;

  List<T> _pageSlice<T>(List<T> items) {
    final start = _currentPage * _pageSize;

    if (start >= items.length) return const [];

    final end = start + _pageSize;

    return items.sublist(start, end > items.length ? items.length : end);
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  void initState() {
    super.initState();
    _reportService = ReportService(ApiService());
    _categoryService = CategoryService(ApiService());

    _loadCategories();
    _loadReport();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (_) {
      // The report still works without the dropdown if this fails.
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _reportService.getLowStockReport(
        categoryId: _categoryId,
      );

      setState(() {
        _report = report;
        _currentPage = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(context, e);
        _loading = false;
      });
    }
  }

  @override
  void onReconnected() {
    _loadReport();
  }

  String _variantLabel(BuildContext context, LowStockItem item) {
    final parts = <String>[];

    if (item.sizeName != null && item.sizeName!.isNotEmpty) {
      parts.add(item.sizeName!);
    }

    if (item.colourName != null && item.colourName!.isNotEmpty) {
      parts.add(item.colourName!);
    }

    if (parts.isEmpty) {
      return context.tr('Variant #{0}', [item.productVariantId]);
    }

    return parts.join(' / ');
  }

  /// How full the variant is compared with its threshold (0 = empty).
  double _fill(LowStockItem item) {
    final threshold = item.lowStockThreshold;

    if (threshold <= 0) return item.totalQuantity > 0 ? 1.0 : 0.0;

    return (item.totalQuantity / threshold).clamp(0.0, 1.0).toDouble();
  }

  /// Most urgent first: empty variants, then the furthest below threshold.
  List<LowStockItem> _byUrgency(List<LowStockItem> items) {
    final sorted = List<LowStockItem>.of(items);
    sorted.sort((a, b) => _fill(a).compareTo(_fill(b)));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    // Everything the report returned, most urgent first. The hero and the
    // chip counts always use this full list.
    final all = _byUrgency(_report?.items ?? const <LowStockItem>[]);
    final outOfStock = all.where((i) => i.totalQuantity <= 0).length;
    final running = all.length - outOfStock;

    // What the list shows after the Low / Out of stock filter.
    final items = all.where((i) {
      switch (_filter) {
        case _StockFilter.all:
          return true;
        case _StockFilter.low:
          return i.totalQuantity > 0;
        case _StockFilter.out:
          return i.totalQuantity <= 0;
      }
    }).toList();

    return AppShell(
      title: context.tr('Low Stock'),
      destinationId: 'report-low-stock',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadReport)
          : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadReport,
              child: WideContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (all.isNotEmpty) ...[
                      ReportHeroCard(
                        label: context.tr('Needs Reordering'),
                        value: '${all.length}',
                        icon: Icons.warning_amber_rounded,
                        color: outOfStock > 0
                            ? AppPalette.danger
                            : AppPalette.warning,
                        caption: context.tr(
                          'Variants below their low stock threshold',
                        ),
                        chips: [
                          if (outOfStock > 0)
                            ReportPill(
                              label: context.tr('{0} out of stock', [
                                outOfStock,
                              ]),
                              icon: Icons.remove_shopping_cart_outlined,
                              color: AppPalette.danger,
                            ),
                          if (running > 0)
                            ReportPill(
                              label: context.tr('{0} running low', [
                                running,
                              ]),
                              icon: Icons.trending_down_rounded,
                              color: AppPalette.warning,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Kept above the list so a category with nothing
                    // to reorder can still be changed.
                    DropdownButtonFormField<int?>(
                      key: ValueKey('category-$_categoryId'),
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: context.tr('Category'),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(context.tr('All Categories')),
                        ),
                        ..._categories.map(
                              (category) => DropdownMenuItem<int?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        setState(() {
                          _categoryId = value;
                        });

                        await _loadReport();
                      },
                    ),
                    if (all.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ReportChoiceChips<_StockFilter>(
                        selected: _filter,
                        onSelected: (value) => setState(() {
                          _filter = value;
                          _currentPage = 0;
                        }),
                        options: [
                          ChoiceOption(
                            _StockFilter.all,
                            '${context.tr('All')} (${all.length})',
                          ),
                          ChoiceOption(
                            _StockFilter.low,
                            '${context.tr('Low')} ($running)',
                            icon: Icons.trending_down_rounded,
                          ),
                          ChoiceOption(
                            _StockFilter.out,
                            '${context.tr('Out of stock')} ($outOfStock)',
                            icon: Icons.remove_shopping_cart_outlined,
                          ),
                        ],
                      ),
                    ],
                    if (all.isEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: EmptyState(
                          icon: Icons.verified_rounded,
                          title: context.tr('No low stock items'),
                          message: context.tr(
                            'All variants are above their thresholds.',
                          ),
                        ),
                      ),
                    ] else if (items.isEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: EmptyState(
                          icon: Icons.verified_rounded,
                          title: _filter == _StockFilter.out
                              ? context.tr('Nothing is out of stock')
                              : context.tr('Nothing is running low'),
                          message: context.tr(
                            'Try a different filter.',
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: context.tr('Most Urgent First'),
                        subtitle: context.tr(
                          'Tap a variant for barcode and stock by location',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._pageSlice(items).map(
                            (item) => _LowStockCard(
                          item: item,
                          variantLabel: _variantLabel(context, item),
                          fill: _fill(item),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (items.isNotEmpty)
            WideContent(
              child: PaginationBar(
                page: _currentPage,
                pageSize: _pageSize,
                totalItems: items.length,
                onPageChanged: _goToPage,
              ),
            ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({
    required this.item,
    required this.variantLabel,
    required this.fill,
  });

  final LowStockItem item;
  final String variantLabel;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = item.totalQuantity <= 0;
    final shortBy = item.lowStockThreshold - item.totalQuantity;

    // Empty or under half of the threshold is critical; the rest is a warning.
    final color = (isOut || fill < 0.5) ? AppPalette.danger : AppPalette.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ReportPill(
                label: isOut ? context.tr('Out of stock') : context.tr('Low'),
                icon: isOut
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.trending_down_rounded,
                color: color,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variantLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  item.categoryName.isEmpty
                      ? item.modelNumber
                      : '${item.modelNumber} • ${item.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ShareBar(fraction: fill, color: color, height: 8),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('{0} left of {1}', [
                          item.totalQuantity,
                          item.lowStockThreshold,
                        ]),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (shortBy > 0)
                      Text(
                        context.tr('Short by {0}', [shortBy]),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.qr_code_2_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BarcodeView(item.barcode, showText: false),
            if (item.locations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('Stock by location'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final location in item.locations)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location.locationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${location.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}