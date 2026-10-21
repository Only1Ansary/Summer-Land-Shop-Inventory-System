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

  @override
  Widget build(BuildContext context) {
    final items = _report?.items ?? const <LowStockItem>[];

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
                          const SizedBox(height: 16),
                          StatGrid(
                            stats: [
                              StatData(
                                label: context.tr('Low Stock Variants'),
                                value: '${items.length}',
                                icon: Icons.warning_amber_rounded,
                                color: AppPalette.warning,
                              ),
                            ],
                          ),
                          if (items.isEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: EmptyState(
                                icon: Icons.verified_rounded,
                                title: context.tr('No low stock items'),
                                message: context.tr(
                                  'All variants are above their thresholds.',
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            SectionHeader(
                              title: context.tr('Needs Reordering'),
                              subtitle: context.tr(
                                'Variants below their low stock threshold',
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._pageSlice(items).map(
                              (item) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ExpansionTile(
                                  title: Text(item.productName),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _variantLabel(context, item),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      Text(
                                        context.tr('{0} • Qty: {1}{2}', [
                                          item.modelNumber,
                                          item.totalQuantity,
                                          item.categoryName.isEmpty
                                              ? ''
                                              : '\n${item.categoryName}',
                                        ]),
                                      ),
                                    ],
                                  ),
                                  trailing: const LowStockBadge(),
                                  children: [
                                    ListTile(
                                      title: Text(context.tr('Threshold')),
                                      trailing: Text(
                                        '${item.lowStockThreshold}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.qr_code_2_outlined,
                                        size: 20,
                                      ),
                                      title: Text(context.tr('Barcode')),
                                      trailing: Text(item.barcode),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: BarcodeView(
                                        item.barcode,
                                        showText: false,
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ...item.locations.map(
                                      (location) => ListTile(
                                        title: Text(location.locationName),
                                        trailing: Text(
                                          '${location.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
