import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/inventory_report.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() =>
      _InventoryReportScreenState();
}

class _InventoryReportScreenState
    extends State<InventoryReportScreen> {
  late final ReportService _reportService;

  InventoryReport? _report;
  bool _loading = true;
  String? _error;

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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return AppShell(
      title: 'Inventory Report',
      destinationId: 'report-inventory',
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _loadReport,
                )
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: WideContent(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Variants',
                              value: '${report!.totalVariants}',
                              icon: Icons.inventory_2_outlined,
                            ),
                            StatData(
                              label: 'Total Quantity',
                              value: '${report.totalQuantity}',
                              icon: Icons.numbers_rounded,
                            ),
                            StatData(
                              label: 'Inventory Value',
                              value: money(report.totalInventoryValue),
                              icon: Icons.payments_outlined,
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
                          subtitle:
                              'Tap a product to see stock by location',
                        ),
                        const SizedBox(height: 8),
                        ...report.items.map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ExpansionTile(
                              title: Text(item.productName),
                              subtitle: Text(
                                '${item.modelNumber} • Qty: ${item.totalQuantity}',
                              ),
                              trailing: item.isLowStock
                                  ? const LowStockBadge()
                                  : Text(
                                      money(item.inventoryValue),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.qr_code_2_outlined,
                                    size: 20,
                                  ),
                                  title: const Text('Barcode'),
                                  subtitle: Text(item.barcode),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.attach_money_outlined,
                                    size: 20,
                                  ),
                                  title: const Text('Price'),
                                  subtitle: Text(money(item.price)),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.low_priority_rounded,
                                    size: 20,
                                  ),
                                  title: const Text('Low Stock Threshold'),
                                  subtitle: Text('${item.lowStockThreshold}'),
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
                    ),
                  ),
                ),
    );
  }
}