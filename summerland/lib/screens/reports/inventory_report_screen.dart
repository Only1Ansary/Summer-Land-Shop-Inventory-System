import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/inventory_report.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import '../../ui/report_widgets.dart';

enum _Sort { name, mostStock, leastStock }

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen>
    with ReconnectReloader<InventoryReportScreen> {
  late final ReportService _reportService;
  final TextEditingController _searchController = TextEditingController();

  InventoryReport? _report;
  bool _loading = true;
  String? _error;

  String _query = '';
  _Sort _sort = _Sort.name;

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
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _reportService.getInventoryReport();

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

  /// Adds up the report's variant rows into one row per product.
  ///
  /// A product's quantity is the sum of every variant's stock, and the
  /// per-location figures are merged the same way. Products with no stock
  /// at all are left out.
  List<_ProductStockRow> _groupByProduct(List<InventoryReportItem> items) {
    final order = <String>[];
    final names = <String, String>{};
    final models = <String, String>{};
    final quantities = <String, int>{};
    final locations = <String, Map<int, InventoryLocation>>{};

    for (final item in items) {
      final key = '${item.modelNumber}:${item.productName}';

      if (!quantities.containsKey(key)) {
        order.add(key);
        names[key] = item.productName;
        models[key] = item.modelNumber;
        quantities[key] = 0;
        locations[key] = {};
      }

      quantities[key] = quantities[key]! + item.totalQuantity;

      for (final location in item.locations) {
        final existing = locations[key]![location.locationId];

        locations[key]![location.locationId] = InventoryLocation(
          locationId: location.locationId,
          locationName: location.locationName,
          quantity: (existing?.quantity ?? 0) + location.quantity,
        );
      }
    }

    return order
        .where((key) => quantities[key]! > 0)
        .map(
          (key) => _ProductStockRow(
        productName: names[key]!,
        modelNumber: models[key]!,
        totalQuantity: quantities[key]!,
        locations: locations[key]!.values.toList(),
      ),
    )
        .toList();
  }

  /// Applies the search box and the chosen sort order.
  List<_ProductStockRow> _applyFilters(List<_ProductStockRow> rows) {
    final q = _query.trim().toLowerCase();

    final result = q.isEmpty
        ? List<_ProductStockRow>.of(rows)
        : rows
        .where(
          (p) =>
      p.productName.toLowerCase().contains(q) ||
          p.modelNumber.toLowerCase().contains(q),
    )
        .toList();

    switch (_sort) {
      case _Sort.name:
        result.sort(
              (a, b) =>
              a.productName.toLowerCase().compareTo(b.productName.toLowerCase()),
        );
      case _Sort.mostStock:
        result.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
      case _Sort.leastStock:
        result.sort((a, b) => a.totalQuantity.compareTo(b.totalQuantity));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <InventoryReportItem>[];
    final products = _groupByProduct(items);
    final visible = _applyFilters(products);

    return AppShell(
      title: context.tr('Inventory Report'),
      destinationId: 'report-inventory',
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
                    ReportHeroCard(
                      label: context.tr('Inventory Value'),
                      value: money(report!.totalInventoryValue),
                      icon: Icons.inventory_2_rounded,
                      caption: context.tr('{0} units across {1} products', [
                        report.totalQuantity,
                        products.length,
                      ]),
                      chips: [
                        report.lowStockVariants > 0
                            ? ReportPill(
                          label: context.tr('{0} low stock', [
                            report.lowStockVariants,
                          ]),
                          icon: Icons.warning_amber_rounded,
                          color: AppPalette.warning,
                        )
                            : ReportPill(
                          label: context.tr('No low stock'),
                          icon: Icons.check_circle_outline,
                          color: AppPalette.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ReportSearchField(
                      controller: _searchController,
                      hint: context.tr('Search by name or model number'),
                      onChanged: (value) => setState(() {
                        _query = value;
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(height: 10),
                    ReportChoiceChips<_Sort>(
                      selected: _sort,
                      onSelected: (value) => setState(() {
                        _sort = value;
                        _currentPage = 0;
                      }),
                      options: [
                        ChoiceOption(
                          _Sort.name,
                          context.tr('Name'),
                          icon: Icons.sort_by_alpha_rounded,
                        ),
                        ChoiceOption(
                          _Sort.mostStock,
                          context.tr('Most stock'),
                          icon: Icons.arrow_downward_rounded,
                        ),
                        ChoiceOption(
                          _Sort.leastStock,
                          context.tr('Least stock'),
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(
                      title: context.tr('Product Quantities'),
                      subtitle: _query.trim().isEmpty
                          ? context.tr(
                        'Tap a product to see stock by location',
                      )
                          : context.tr('{0} of {1} products', [
                        visible.length,
                        products.length,
                      ]),
                    ),
                    const SizedBox(height: 8),
                    if (visible.isEmpty)
                      SizedBox(
                        height: 220,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: context.tr('No matching products'),
                          message: context.tr(
                            'Try a different name or model number.',
                          ),
                        ),
                      )
                    else
                      ..._pageSlice(visible).map(
                            (product) => _ProductCard(product: product),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (visible.isNotEmpty)
            WideContent(
              child: PaginationBar(
                page: _currentPage,
                pageSize: _pageSize,
                totalItems: visible.length,
                onPageChanged: _goToPage,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final _ProductStockRow product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Locations holding the most stock first.
    final locations = List<InventoryLocation>.of(product.locations)
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_outlined, color: primary, size: 22),
          ),
          title: Text(
            product.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              context.tr('{0} • {1} locations', [
                product.modelNumber,
                locations.length,
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.totalQuantity}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                context.tr('units'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (final location in locations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${location.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ShareBar(
                      fraction: product.totalQuantity > 0
                          ? location.quantity / product.totalQuantity
                          : 0,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One product's stock, with every variant's quantity added together.
class _ProductStockRow {
  final String productName;
  final String modelNumber;
  final int totalQuantity;
  final List<InventoryLocation> locations;

  _ProductStockRow({
    required this.productName,
    required this.modelNumber,
    required this.totalQuantity,
    required this.locations,
  });
}