import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../models/reports/employees_report.dart';
import '../../services/api_service.dart';
import '../../services/report_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class EmployeesReportScreen extends StatefulWidget {
  const EmployeesReportScreen({super.key});

  @override
  State<EmployeesReportScreen> createState() => _EmployeesReportScreenState();
}

class _EmployeesReportScreenState extends State<EmployeesReportScreen> {
  late final ReportService _reportService;

  EmployeesReport? _report;
  bool _loading = true;
  String? _error;

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

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
      final report = await _reportService.getEmployeesReport(
        year: _year,
        month: _month,
      );

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context,
      initial: DateTime(_year, _month),
    );

    if (picked == null) return;

    setState(() {
      _year = picked.year;
      _month = picked.month;
    });

    await _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return AppShell(
      title: 'Employees Report',
      destinationId: 'report-employees',
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
                    MonthFilterBar(
                      label: monthLabel(_year, _month),
                      onTap: _pickMonth,
                    ),
                    const SizedBox(height: 16),
                    if (report!.employeeOfTheMonth.isNotEmpty) ...[
                      _EmployeeOfTheMonthCard(
                        winners: report.employeeOfTheMonth,
                        monthLabel: monthLabel(_year, _month),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SectionHeader(
                      title: 'Overview',
                      subtitle:
                          'Standings for ${monthLabel(_year, _month)} and '
                          'what has been paid out',
                    ),
                    const SizedBox(height: 8),
                    StatGrid(
                      stats: [
                        StatData(
                          label: 'Employees',
                          value: '${report.employeeCount}',
                          icon: Icons.people_outline,
                        ),
                        StatData(
                          label: 'Total Sales',
                          value: money(report.totalSales),
                          icon: Icons.shopping_cart_outlined,
                        ),
                        StatData(
                          label: 'Targets Met',
                          value: '${report.targetMetCount}',
                          icon: Icons.flag_outlined,
                        ),
                        StatData(
                          label: 'Monthly Salaries',
                          value: money(report.totalMonthlySalaries),
                          icon: Icons.payments_outlined,
                        ),
                        StatData(
                          label: 'Bonus Owed',
                          value: money(report.totalBonusOwed),
                          icon: Icons.card_giftcard_outlined,
                        ),
                        StatData(
                          label: 'Paid in Month',
                          value: money(report.paymentTotalInMonth),
                          icon: Icons.check_circle_outline,
                        ),
                        StatData(
                          label: 'Total Paid (All Time)',
                          value: money(report.totalPaid),
                          icon: Icons.history,
                        ),
                        StatData(
                          label: 'Left to Pay',
                          value: money(report.totalLeftToPay),
                          icon: Icons.pending_actions_outlined,
                          valueColor: amountColor(
                            context,
                            -report.totalLeftToPay,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                      title: 'By Employee',
                      subtitle: 'One card for each member of staff',
                    ),
                    const SizedBox(height: 12),
                    if (report.employees.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.badge_outlined,
                          title: 'No employees yet',
                          message: 'Add employees before running this report.',
                        ),
                      )
                    else
                      for (final item in report.employees)
                        _EmployeeReportTile(item: item),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Highlights whoever sold the most in the reported month.
class _EmployeeOfTheMonthCard extends StatelessWidget {
  const _EmployeeOfTheMonthCard({
    required this.winners,
    required this.monthLabel,
  });

  final List<EmployeeOfMonth> winners;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = winners.map((e) => e.name).join(', ');
    final sales = winners.first.totalSales;
    final tied = winners.length > 1;

    return Card(
      margin: EdgeInsets.zero,
      color: AppPalette.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee of the Month',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    names,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${money(sales)} in sales during $monthLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (tied)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: StatusBadge(
                  label: 'TIED',
                  color: AppPalette.warning,
                  icon: Icons.handshake_outlined,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeReportTile extends StatefulWidget {
  const _EmployeeReportTile({required this.item});

  final EmployeeReportItem item;

  @override
  State<_EmployeeReportTile> createState() => _EmployeeReportTileState();
}

class _EmployeeReportTileState extends State<_EmployeeReportTile> {
  bool _expanded = false;

  String _bonusLabel() {
    final item = widget.item;

    if (item.bonus <= 0) {
      return money(0);
    }

    return item.bonusType == BonusType.percentage
        ? '${_percent(item.bonus)} of sales'
        : money(item.bonus);
  }

  String _percent(double value) {
    return value == value.roundToDouble() ? '${value.round()}%' : '$value%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Sales ${money(item.totalSales)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  item.achievedTarget
                      ? const StatusBadge(
                          label: 'TARGET MET',
                          color: AppPalette.success,
                          icon: Icons.check_circle_outline,
                        )
                      : StatusBadge(
                          label: 'BELOW TARGET',
                          color: theme.colorScheme.outline,
                          icon: Icons.remove_circle_outline,
                        ),
                  IconButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    tooltip: _expanded ? 'Hide details' : 'Show details',
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _Detail(label: 'Salary', value: money(item.salary)),
                  _Detail(label: 'Target', value: money(item.target)),
                  _Detail(
                    label: 'Bonus',
                    value: '${_bonusLabel()} = ${money(item.bonusAmount)}',
                  ),
                  _Detail(label: 'Total Sales', value: money(item.totalSales)),
                  _Detail(label: 'Left to Pay', value: money(item.leftToPay)),
                  _Detail(
                    label: 'Paid in Month',
                    value: money(item.paymentTotalInMonth),
                  ),
                  _Detail(label: 'Total Paid', value: money(item.totalPaid)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
