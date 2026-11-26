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
import '../../utils/payment_method.dart';
import '../../ui/daily_sales_chart.dart';

enum _Preset { today, last7, thisMonth, lastMonth, custom }

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
  _Preset _preset = _Preset.custom;

  @override
  void initState() {
    super.initState();
    _reportService = ReportService(ApiService());
    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();
    _preset = _detectPreset();
    _loadReport();
  }

  // ---------- Date presets ----------

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  (DateTime, DateTime) _rangeFor(_Preset preset) {
    final today = _dateOnly(nowInAppTimeZone());

    switch (preset) {
      case _Preset.today:
        return (today, today);
      case _Preset.last7:
        return (today.subtract(const Duration(days: 6)), today);
      case _Preset.thisMonth:
        return (DateTime(today.year, today.month, 1), today);
      case _Preset.lastMonth:
        final firstOfThis = DateTime(today.year, today.month, 1);
        final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
        return (DateTime(lastOfPrev.year, lastOfPrev.month, 1), lastOfPrev);
      case _Preset.custom:
        return (_from ?? today, _to ?? today);
    }
  }

  /// Highlights the preset chip that matches the current range, if any.
  _Preset _detectPreset() {
    if (_from == null || _to == null) return _Preset.custom;

    final from = _dateOnly(_from!);
    final to = _dateOnly(_to!);

    for (final preset in const [
      _Preset.today,
      _Preset.last7,
      _Preset.thisMonth,
      _Preset.lastMonth,
    ]) {
      final range = _rangeFor(preset);
      if (range.$1 == from && range.$2 == to) return preset;
    }
    return _Preset.custom;
  }

  Future<void> _applyPreset(_Preset preset) async {
    if (preset == _Preset.custom) {
      // Custom just means "use the date pickers below".
      setState(() => _preset = _Preset.custom);
      return;
    }

    final range = _rangeFor(preset);

    setState(() {
      _preset = preset;
      _from = range.$1;
      _to = range.$2;
    });

    await _loadReport();
  }

  String _presetLabel(BuildContext context, _Preset preset) {
    switch (preset) {
      case _Preset.today:
        return context.tr('Today');
      case _Preset.last7:
        return context.tr('Last 7 days');
      case _Preset.thisMonth:
        return context.tr('This month');
      case _Preset.lastMonth:
        return context.tr('Last month');
      case _Preset.custom:
        return context.tr('Custom');
    }
  }

  // ---------- Loading ----------

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
      initialDate: isFrom ? (_from ?? nowInAppTimeZone()) : (_to ?? nowInAppTimeZone()),
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
      _preset = _detectPreset();
    });

    await _loadReport();
  }

  String _formatDate(DateTime date) => formatDisplayDate(date);

  String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return AppShell(
      title: context.tr('Sales Report'),
      destinationId: 'report-sales',
      body: _loading || (report == null && _error == null)
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadReport)
          : RefreshIndicator(
        onRefresh: _loadReport,
        child: WideContent(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: _buildContent(context, report!),
          ),
        ),
      ),
    );
  }

  Widget _presetChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final preset in _Preset.values)
          ChoiceChip(
            label: Text(_presetLabel(context, preset)),
            selected: _preset == preset,
            onSelected: (_) => _applyPreset(preset),
          ),
      ],
    );
  }

  List<Widget> _buildContent(BuildContext context, SalesReport report) {
    final averageInvoice =
    report.invoiceCount > 0 ? report.netSales / report.invoiceCount : 0.0;
    final margin =
    report.netSales > 0 ? report.profit / report.netSales : 0.0;
    final returnRate =
    report.grossSales > 0 ? report.returnsAmount / report.grossSales : 0.0;

    return [
      // ----- Period selection -----
      _presetChips(context),
      const SizedBox(height: 12),
      DateFilterBar(
        fromLabel: _from == null ? context.tr('From') : _formatDate(_from!),
        toLabel: _to == null ? context.tr('To') : _formatDate(_to!),
        onFrom: () => _pickDate(true),
        onTo: () => _pickDate(false),
      ),
      const SizedBox(height: 16),

      // ----- Headline numbers -----
      CollapsibleSection(
        title: context.tr('Summary'),
        subtitle: context.tr('The numbers that matter for this period'),
        initiallyExpanded: true,
        child: StatGrid(
          stats: [
            StatData(
              label: context.tr('Net Revenue'),
              value: money(report.netSales),
              icon: Icons.account_balance_wallet_outlined,
              valueColor: amountColor(context, report.netSales),
            ),
            StatData(
              label: context.tr('Net Profit'),
              value: money(report.profit),
              icon: Icons.trending_up_outlined,
              color: report.profit >= 0 ? null : AppPalette.danger,
              valueColor: amountColor(context, report.profit),
            ),
            StatData(
              label: context.tr('Profit Margin'),
              value: _percent(margin),
              icon: Icons.percent_outlined,
              color: margin >= 0 ? null : AppPalette.danger,
            ),
            StatData(
              label: context.tr('Average Invoice'),
              value: money(averageInvoice),
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ----- Daily trend -----
      CollapsibleSection(
        title: context.tr('Sales per Day'),
        subtitle: context.tr('Net sales for each day in this period'),
        initiallyExpanded: true,
        child: DailySalesChart(days: report.dailySales, format: money),
      ),
      const SizedBox(height: 16),

      // ----- How profit is calculated -----
      CollapsibleSection(
        title: context.tr('Profit Breakdown'),
        subtitle: context.tr('From net revenue to net profit'),
        initiallyExpanded: true,
        child: Column(
          children: [
            _BreakdownRow(
              label: context.tr('Net Revenue'),
              value: money(report.netSales),
            ),
            _BreakdownRow(
              label: context.tr('Cost of Goods Sold'),
              value: moneyNegative(report.costOfGoodsSold),
            ),
            const Divider(height: 16),
            _BreakdownRow(
              label: context.tr('Gross Profit'),
              value: money(report.grossProfit),
              bold: true,
              valueColor: amountColor(context, report.grossProfit),
            ),
            _BreakdownRow(
              label: context.tr('Staff Payments'),
              value: moneyNegative(report.employeePaymentTotal),
            ),
            const Divider(height: 16),
            _BreakdownRow(
              label: context.tr('Net Profit'),
              value: money(report.profit),
              bold: true,
              valueColor: amountColor(context, report.profit),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ----- Category share -----
      CollapsibleSection(
        title: context.tr('Sales by Category'),
        subtitle: context.tr('Share of net sales in this period'),
        initiallyExpanded: true,
        child: CategoryPieChart(categories: report.categorySales),
      ),
      const SizedBox(height: 16),

      // ----- Activity -----
      CollapsibleSection(
        title: context.tr('Sales Activity'),
        subtitle: context.tr('Invoices, units and returns'),
        initiallyExpanded: false,
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
              label: context.tr('Gross Sales'),
              value: money(report.grossSales),
              icon: Icons.attach_money_outlined,
              valueColor: amountColor(context, report.grossSales),
            ),
            StatData(
              label: context.tr('Returns'),
              value: moneyNegative(report.returnsAmount),
              icon: Icons.currency_exchange_rounded,
              color: AppPalette.danger,
              valueColor: amountColor(context, -report.returnsAmount),
            ),
            StatData(
              label: context.tr('Items Returned'),
              value: '${report.itemsReturned}',
              icon: Icons.assignment_return_outlined,
            ),
            StatData(
              label: context.tr('Return Rate'),
              value: _percent(returnRate),
              icon: Icons.assignment_return_outlined,
              color: returnRate > 0.1 ? AppPalette.danger : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ----- Purchases & staff (money going out) -----
      CollapsibleSection(
        title: context.tr('Purchases & Staff'),
        subtitle: context.tr('Stock bought and salaries paid in this period'),
        initiallyExpanded: false,
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
              color: report.purchaseTotalCost > 0 ? AppPalette.danger : null,
              valueColor: amountColor(context, -report.purchaseTotalCost),
            ),
            StatData(
              label: context.tr('Unpaid On Purchases'),
              value: moneyNegative(report.purchaseDebt),
              icon: Icons.hourglass_empty_outlined,
              color: report.purchaseDebt > 0 ? AppPalette.danger : null,
            ),
            StatData(
              label: context.tr('Staff Payments'),
              value: money(report.employeePaymentTotal),
              icon: Icons.people_outline,
              valueColor: amountColor(context, -report.employeePaymentTotal),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ----- Debts & suppliers (kept as before) -----
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
              color: report.supplierDebtTotal > 0 ? AppPalette.danger : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ----- Customers & payments (kept as before) -----
      CollapsibleSection(
        title: context.tr('Customers & Payments'),
        subtitle: context.tr(
          'Collections in this period and customer balances',
        ),
        initiallyExpanded: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatGrid(
              stats: [
                StatData(
                  label: context.tr('Customers'),
                  value: '${report.customerCount}',
                  icon: Icons.people_outline,
                ),
                StatData(
                  label: context.tr('Payments Collected'),
                  value: money(report.customerPaymentsTotal),
                  icon: Icons.payments_outlined,
                  valueColor: amountColor(
                    context,
                    report.customerPaymentsTotal,
                  ),
                ),
                StatData(
                  label: context.tr('Customer Debt'),
                  value: moneyNegative(report.customerDebtTotal),
                  icon: Icons.balance_outlined,
                  color: report.customerDebtTotal > 0
                      ? AppPalette.danger
                      : null,
                ),
              ],
            ),
            if (report.paymentsByMethod.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('By payment method'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              for (final entry in report.paymentsByMethod)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(paymentMethodLabel(context, entry.method)),
                      ),
                      Text(money(entry.amount)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ];
  }
}

/// One line of the profit breakdown: label on the left, amount on the right.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = bold
        ? base?.copyWith(fontWeight: FontWeight.w700)
        : base;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}