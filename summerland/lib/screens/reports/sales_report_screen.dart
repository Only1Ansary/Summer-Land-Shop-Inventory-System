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
                        const SectionHeader(
                          title: 'Revenue',
                          subtitle: 'Money from sales in this period',
                        ),
                        const SizedBox(height: 8),
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Gross Sales',
                              value: money(report!.grossSales),
                              icon: Icons.attach_money_outlined,
                            ),
                            StatData(
                              label: 'Returns',
                              value: money(report.returnsAmount),
                              icon: Icons.currency_exchange_rounded,
                              color: AppPalette.danger,
                            ),
                            StatData(
                              label: 'Net Revenue',
                              value: money(report.netSales),
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            StatData(
                              label: 'Estimated Profit',
                              value: money(report.profit),
                              icon: Icons.trending_up_outlined,
                              color: report.profit >= 0
                                  ? null
                                  : AppPalette.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SectionHeader(
                          title: 'Sales Activity',
                          subtitle: 'Invoices and units moved',
                        ),
                        const SizedBox(height: 8),
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Invoices',
                              value: '${report.invoiceCount}',
                              icon: Icons.receipt_long_outlined,
                            ),
                            StatData(
                              label: 'Items Sold',
                              value: '${report.itemsSold}',
                              icon: Icons.shopping_cart_outlined,
                            ),
                            StatData(
                              label: 'Items Returned',
                              value: '${report.itemsReturned}',
                              icon: Icons.assignment_return_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SectionHeader(
                          title: 'Purchases & Cost',
                          subtitle: 'Stock bought in this period',
                        ),
                        const SizedBox(height: 8),
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Purchase Invoices',
                              value: '${report.purchaseInvoiceCount}',
                              icon: Icons.shopping_bag_outlined,
                            ),
                            StatData(
                              label: 'Purchase Cost',
                              value: money(report.purchaseTotalCost),
                              icon: Icons.local_shipping_outlined,
                            ),
                            StatData(
                              label: 'Purchase Paid',
                              value: money(report.purchaseTotalPaid),
                              icon: Icons.payments_outlined,
                            ),
                            StatData(
                              label: 'Unpaid On Purchases',
                              value: moneyNegative(report.purchaseDebt),
                              icon: Icons.hourglass_empty_outlined,
                              color: report.purchaseDebt > 0
                                  ? AppPalette.danger
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SectionHeader(
                          title: 'Debts & Suppliers',
                          subtitle: 'Current standing with suppliers',
                        ),
                        const SizedBox(height: 8),
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Suppliers',
                              value: '${report.supplierCount}',
                              icon: Icons.factory_outlined,
                            ),
                            StatData(
                              label: 'Total Supplier Debt',
                              value: moneyNegative(report.supplierDebtTotal),
                              icon: Icons.balance_outlined,
                              color: report.supplierDebtTotal > 0
                                  ? AppPalette.danger
                                  : null,
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