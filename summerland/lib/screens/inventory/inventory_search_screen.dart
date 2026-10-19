import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/inventory_report.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

/// The inventory report's product list, without the summary stats on top.
///
/// Meant for looking stock up quickly: every product with stock shows its
/// model, total quantity, and the per-location breakdown once expanded.
class InventorySearchScreen extends StatefulWidget {
  const InventorySearchScreen({super.key});

  @override
  State<InventorySearchScreen> createState() => _InventorySearchScreenState();
}

class _InventorySearchScreenState extends State<InventorySearchScreen>
    with ReconnectReloader<InventorySearchScreen> {
  static const int _pageSize = 10;

  late final ReportService _reportService;

  InventoryReport? _report;
  bool _loading = true;
  String? _error;

  int _currentPage = 0;
  String _query = '';

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

  List<_ProductStockRow> _matching(List<_ProductStockRow> products) {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return products;

    return products
        .where(
          (product) =>
              product.productName.toLowerCase().contains(query) ||
              product.modelNumber.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <InventoryReportItem>[];
    final products = _matching(_groupByProduct(items));

    return AppShell(
      title: 'Inventory Search',
      destinationId: 'inventory-search',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadReport)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: WideContent(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search products',
                        hintText: 'Name or model number',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadReport,
                    child: WideContent(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (products.isEmpty)
                            const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No products found',
                              message:
                                  'No product with stock matches your search.',
                            ),
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
