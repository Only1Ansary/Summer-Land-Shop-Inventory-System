import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/inventory_report.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen>
    with ReconnectReloader<InventoryReportScreen> {
  late final ReportService _reportService;

  InventoryReport? _report;
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
    _loadReport();
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
        _error = friendlyError(e);
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

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <InventoryReportItem>[];
    final products = _groupByProduct(items);

    return AppShell(
      title: 'Inventory Report',
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
                          StatGrid(
                            stats: [
                              StatData(
                                label: 'Products',
                                value: '${products.length}',
                                icon: Icons.inventory_2_outlined,
                              ),
                              StatData(
                                label: 'Total Quantity',
                                value: '${report!.totalQuantity}',
                                icon: Icons.numbers_rounded,
                              ),
                              StatData(
                                label: 'Inventory Value',
                                value: money(report.totalInventoryValue),
                                icon: Icons.payments_outlined,
                                valueColor: amountColor(
                                  context,
                                  report.totalInventoryValue,
                                ),
                              ),
                              StatData(
                                label: 'Low Stock',
                                value: '${report.lowStockVariants}',
                                icon: Icons.warning_amber_rounded,
                                color: AppPalette.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SectionHeader(
                            title: 'Product Quantities',
                            subtitle: 'Tap a product to see stock by location',
                          ),
                          const SizedBox(height: 8),
                          ..._pageSlice(products).map((product) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                title: Text(product.productName),
                                subtitle: Text(
                                  '${product.modelNumber} • Qty: '
                                  '${product.totalQuantity}',
                                ),
                                children: [
                                  const Divider(height: 1),
                                  ...product.locations.map(
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
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
                if (products.isNotEmpty)
                  WideContent(
                    child: PaginationBar(
                      page: _currentPage,
                      pageSize: _pageSize,
                      totalItems: products.length,
                      onPageChanged: _goToPage,
                    ),
                  ),
              ],
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
