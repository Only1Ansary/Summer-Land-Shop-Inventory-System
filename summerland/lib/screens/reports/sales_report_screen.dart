import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/sales_report.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/category_pie_chart.dart';
import '../../ui/reconnect_reloader.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen>
    with ReconnectReloader<SalesReportScreen> {
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
    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _reportService.getSalesReport(from: _from, to: _to);

      setState(() {
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
  void onReconnected() {
    _loadReport();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
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
      title: context.tr('Sales Report'),
      destinationId: 'report-sales',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadReport)
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: WideContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
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
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Revenue'),
                      subtitle: context.tr('Money from sales in this period'),
                      initiallyExpanded: true,
                      child: StatGrid(
                        stats: [
                          StatData(
                            label: context.tr('Gross Sales'),
                            value: money(report!.grossSales),
                            icon: Icons.attach_money_outlined,
                            valueColor: amountColor(context, report.grossSales),
                          ),
                          StatData(
                            label: context.tr('Returns'),
                            value: moneyNegative(report.returnsAmount),
                            icon: Icons.currency_exchange_rounded,
                            color: AppPalette.danger,
                            valueColor: amountColor(
                              context,
                              -report.returnsAmount,
                            ),
                          ),
                          StatData(
                            label: context.tr('Net Revenue'),
                            value: money(report.netSales),
                            icon: Icons.account_balance_wallet_outlined,
                            valueColor: amountColor(context, report.netSales),
                          ),
                          StatData(
                            label: context.tr('Estimated Profit'),
                            value: money(report.profit),
                            icon: Icons.trending_up_outlined,
                            color: report.profit >= 0
                                ? null
                                : AppPalette.danger,
                            valueColor: amountColor(context, report.profit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Sales by Category'),
                      subtitle: context.tr('Share of net sales in this period'),
                      initiallyExpanded: true,
                      child: CategoryPieChart(categories: report.categorySales),
                    ),
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Sales Activity'),
                      subtitle: context.tr('Invoices and units moved'),
                      initiallyExpanded: true,
                      child: StatGrid(
                        stats: [
                          StatData(
                            label: context.tr('Invoices'),
                            value: '${report.invoiceCount}',
                            icon: Icons.receipt_long_outlined,
                          ),
                          StatData(
                            label: context.tr('Items Sold'),
                            value: '${report.itemsSold}',
                            icon: Icons.shopping_cart_outlined,
                          ),
                          StatData(
                            label: context.tr('Items Returned'),
                            value: '${report.itemsReturned}',
                            icon: Icons.assignment_return_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Purchases & Cost'),
                      subtitle: context.tr('Stock bought in this period'),
                      initiallyExpanded: true,
                      child: StatGrid(
                        stats: [
                          StatData(
                            label: context.tr('Purchase Invoices'),
                            value: '${report.purchaseInvoiceCount}',
                            icon: Icons.shopping_bag_outlined,
                          ),
                          StatData(
                            label: context.tr('Purchase Cost'),
                            value: money(report.purchaseTotalCost),
                            icon: Icons.local_shipping_outlined,
                          ),
                          StatData(
                            label: context.tr('Purchase Paid'),
                            value: money(report.purchaseTotalPaid),
                            icon: Icons.payments_outlined,
                          ),
                          StatData(
                            label: context.tr('Unpaid On Purchases'),
                            value: moneyNegative(report.purchaseDebt),
                            icon: Icons.hourglass_empty_outlined,
                            color: report.purchaseDebt > 0
                                ? AppPalette.danger
                                : null,
                            valueColor: amountColor(
                              context,
                              -report.purchaseDebt,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Staff Payments'),
                      subtitle: context.tr(
                        'Salary and bonuses paid in this period',
                      ),
                      initiallyExpanded: true,
                      child: StatGrid(
                        stats: [
                          StatData(
                            label: context.tr('Payments'),
                            value: '${report.employeePaymentCount}',
                            icon: Icons.people_outline,
                          ),
                          StatData(
                            label: context.tr('Total Paid'),
                            value: money(report.employeePaymentTotal),
                            icon: Icons.payments_outlined,
                            valueColor: amountColor(
                              context,
                              report.employeePaymentTotal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: context.tr('Debts & Suppliers'),
                      subtitle: context.tr('Current standing with suppliers'),
                      initiallyExpanded: true,
                      child: StatGrid(
                        stats: [
                          StatData(
                            label: context.tr('Suppliers'),
                            value: '${report.supplierCount}',
                            icon: Icons.factory_outlined,
                          ),
                          StatData(
                            label: context.tr('Total Supplier Debt'),
                            value: moneyNegative(report.supplierDebtTotal),
                            icon: Icons.balance_outlined,
                            color: report.supplierDebtTotal > 0
                                ? AppPalette.danger
                                : null,
                            valueColor: amountColor(
                              context,
                              -report.supplierDebtTotal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
