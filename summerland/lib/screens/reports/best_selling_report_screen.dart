import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/category.dart';
import '../../models/reports/best_selling_report.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/report_service.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import '../../ui/report_widgets.dart';

class BestSellingReportScreen extends StatefulWidget {
  const BestSellingReportScreen({super.key});

  @override
  State<BestSellingReportScreen> createState() =>
      _BestSellingReportScreenState();
}

class _BestSellingReportScreenState extends State<BestSellingReportScreen>
    with ReconnectReloader<BestSellingReportScreen> {
  late final ReportService _reportService;
  late final CategoryService _categoryService;

  BestSellingReport? _report;
  List<Category> _categories = [];

  int? _selectedCategoryId;
  DateTime? _from;
  DateTime? _to;

  /// How many ranks to show. Null means every product that was sold.
  int? _topLimit;
  String? _topError;
  final TextEditingController _topController = TextEditingController();

  bool _loading = true;
  String? _error;

  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    final apiService = ApiService();

    _reportService = ReportService(apiService);
    _categoryService = CategoryService(apiService);

    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 0;
    });

    try {
      final categories = await _categoryService.getCategories();

      final report = await _reportService.getBestSellingReport(
        from: _from,
        to: _to,
        categoryId: _selectedCategoryId,
      );

      setState(() {
        _categories = categories;
        _report = report;
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
  void dispose() {
    _topController.dispose();
    super.dispose();
  }

  @override
  void onReconnected() {
    _loadData();
  }

  /// The user types how many ranks they want. Empty means "all".
  void _applyTopLimit(String raw) {
    final text = raw.trim();

    if (text.isEmpty) {
      setState(() {
        _topLimit = null;
        _topError = null;
        _currentPage = 0;
      });
      return;
    }

    final value = int.tryParse(text);

    if (value == null || value < 1) {
      setState(() {
        _topError = context.tr('Enter a whole number of ranks, 1 or more.');
      });
      return;
    }

    setState(() {
      _topLimit = value;
      _topError = null;
      _currentPage = 0;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_from ?? nowInAppTimeZone())
          : (_to ?? nowInAppTimeZone()),
      firstDate: DateTime(2020),
      lastDate: nowInAppTimeZone(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });

    await _loadData();
  }

  String _formatDate(DateTime date) => formatDisplayDate(date);

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <BestSellingProduct>[];

    final totalRevenue = items.fold<double>(0, (sum, i) => sum + i.totalSales);
    final totalUnits = items.fold<int>(
      0,
          (sum, i) => sum + i.totalQuantitySold.toInt(),
    );
    final topSales = items.isEmpty ? 0.0 : items.first.totalSales;

    final limit = _topLimit;
    final visibleItems = limit == null || limit >= items.length
        ? items
        : items.take(limit).toList();

    final pageStart = _currentPage * _pageSize;
    final pageItems = pageStart >= visibleItems.length
        ? const <BestSellingProduct>[]
        : visibleItems.sublist(
      pageStart,
      (pageStart + _pageSize) > visibleItems.length
          ? visibleItems.length
          : pageStart + _pageSize,
    );

    return AppShell(
      title: context.tr('Best Selling'),
      destinationId: 'report-best-selling',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: WideContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (items.isNotEmpty) ...[
                      ReportHeroCard(
                        label: context.tr('Revenue From Products'),
                        value: money(totalRevenue),
                        icon: Icons.emoji_events_rounded,
                        color: AppPalette.success,
                        caption: context.tr(
                          '{0} units across {1} products sold',
                          [totalUnits, items.length],
                        ),
                        chips: [
                          ReportPill(
                            label: context.tr('Top: {0}', [
                              items.first.productName,
                            ]),
                            icon: Icons.emoji_events_outlined,
                            color: const Color(0xFFF5B301),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    ReportFiltersCard(
                      children: [
                        DatePresetBar(
                          from: _from,
                          to: _to,
                          today: nowInAppTimeZone(),
                          onSelected: (from, to) {
                            setState(() {
                              _from = from;
                              _to = to;
                            });
                            _loadData();
                          },
                        ),
                        DateFilterBar(
                          fromLabel: _from == null
                              ? context.tr('From')
                              : _formatDate(_from!),
                          toLabel: _to == null
                              ? context.tr('To')
                              : _formatDate(_to!),
                          onFrom: () => _pickDate(true),
                          onTo: () => _pickDate(false),
                        ),
                        DropdownButtonFormField<int?>(
                          key: ValueKey('category-$_selectedCategoryId'),
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: context.tr('Category'),
                            prefixIcon: const Icon(
                              Icons.category_outlined,
                            ),
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
                              _selectedCategoryId = value;
                            });

                            await _loadData();
                          },
                        ),
                      ],
                    ),
                    if (items.isEmpty)
                      SizedBox(
                        height: 320,
                        child: EmptyState(
                          icon: Icons.trending_down_rounded,
                          title: context.tr('No sales data'),
                          message: context.tr(
                            'Adjust the dates or add new sales.',
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: limit == null || limit >= items.length
                            ? context.tr('Top Sellers')
                            : context.tr('Top {0}', [limit]),
                        subtitle: context.tr(
                          'Ranked by units sold • {0} product{1} sold',
                          [items.length, items.length == 1 ? '' : 's'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _topController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: context.tr('Show top'),
                          hintText: context.tr('All'),
                          helperText:
                          limit != null && limit >= items.length
                              ? context.tr(
                            'Showing all {0} products sold',
                            [items.length],
                          )
                              : context.tr('Empty shows every product'),
                          errorText: _topError,
                          errorMaxLines: 2,
                          prefixIcon: const Icon(
                            Icons.emoji_events_outlined,
                          ),
                          suffixIcon: _topController.text.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _topController.clear();
                              _applyTopLimit('');
                            },
                          ),
                        ),
                        onChanged: _applyTopLimit,
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < pageItems.length; i++)
                        _ProductRankCard(
                          rank: pageStart + i + 1,
                          item: pageItems[i],
                          barFraction: topSales > 0
                              ? pageItems[i].totalSales / topSales
                              : 0,
                          shareOfSales: totalRevenue > 0
                              ? pageItems[i].totalSales / totalRevenue
                              : 0,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (visibleItems.isNotEmpty)
            WideContent(
              child: PaginationBar(
                page: _currentPage,
                pageSize: _pageSize,
                totalItems: visibleItems.length,
                onPageChanged: _goToPage,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductRankCard extends StatelessWidget {
  const _ProductRankCard({
    required this.rank,
    required this.item,
    required this.barFraction,
    required this.shareOfSales,
  });

  final int rank;
  final BestSellingProduct item;

  /// Length of the bar, relative to the best seller (the best seller is full).
  final double barFraction;

  /// This product's share of all sales in the period (0..1).
  final double shareOfSales;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharePercent = (shareOfSales * 100).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RankBadge(rank: rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.modelNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      money(item.totalSales),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: amountColor(context, item.totalSales),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShareBar(
              fraction: barFraction,
              color: rank <= 3 ? AppPalette.success : null,
              height: 7,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ReportPill(
                  label: context.tr('{0} sold', [item.totalQuantitySold]),
                  icon: Icons.shopping_cart_outlined,
                ),
                const Spacer(),
                Text(
                  context.tr('{0}% of sales', [sharePercent]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}