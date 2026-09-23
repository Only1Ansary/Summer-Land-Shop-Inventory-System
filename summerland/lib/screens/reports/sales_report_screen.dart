import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/sales_report.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() =>
      _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late final ReportService _reportService;

  SalesReport? _report;
  bool _loading = true;
  String? _error;

  DateTime? _from;
  DateTime? _to;

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
      final report = await _reportService.getSalesReport(
        from: _from,
        to: _to,
      );

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

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_from ?? DateTime.now())
          : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });

    await _loadReport();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return AppShell(
      title: 'Sales Report',
      destinationId: 'report-sales',
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
                        DateFilterBar(
                          fromLabel: _from == null
                              ? 'From'
                              : _formatDate(_from!),
                          toLabel:
                              _to == null ? 'To' : _formatDate(_to!),
                          onFrom: () => _pickDate(true),
                          onTo: () => _pickDate(false),
                        ),
                        const SizedBox(height: 16),
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Invoices',
                              value: '${report!.invoiceCount}',
                              icon: Icons.receipt_long_outlined,
                            ),
                            StatData(
                              label: 'Items Sold',
                              value: '${report.itemsSold}',
                              icon: Icons.shopping_cart_outlined,
                            ),
                            StatData(
                              label: 'Gross Sales',
                              value: money(report.grossSales),
                              icon: Icons.attach_money_outlined,
                            ),
                            StatData(
                              label: 'Items Returned',
                              value: '${report.itemsReturned}',
                              icon: Icons.assignment_return_outlined,
                            ),
                            StatData(
                              label: 'Returns Amount',
                              value: money(report.returnsAmount),
                              icon: Icons.currency_exchange_rounded,
                              color: AppPalette.danger,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}