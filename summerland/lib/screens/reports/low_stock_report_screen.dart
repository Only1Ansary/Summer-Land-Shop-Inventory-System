import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/low_stock_report.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  State<LowStockReportScreen> createState() =>
      _LowStockReportScreenState();
}

class _LowStockReportScreenState
    extends State<LowStockReportScreen> {
  late final ReportService _reportService;

  LowStockReport? _report;
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
      final report = await _reportService.getLowStockReport();

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
      title: 'Low Stock',
      destinationId: 'report-low-stock',
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
                    child: report!.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              EmptyState(
                                icon: Icons.verified_rounded,
                                title: 'No low stock items',
                                message:
                                    'All variants are above their thresholds.',
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              StatGrid(
                                stats: [
                                  StatData(
                                    label: 'Low Stock Variants',
                                    value: '${report.items.length}',
                                    icon: Icons.warning_amber_rounded,
                                    color: AppPalette.warning,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const SectionHeader(
                                title: 'Needs Reordering',
                                subtitle:
                                    'Variants below their low stock threshold',
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
                                    trailing: const LowStockBadge(),
                                    children: [
                                      ListTile(
                                        title: const Text('Threshold'),
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
                                        title: const Text('Barcode'),
                                        trailing: Text(item.barcode),
                                      ),
                                      const Divider(height: 1),
                                      ...item.locations.map(
                                        (location) => ListTile(
                                          title: Text(
                                            location.locationName,
                                          ),
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