import 'package:flutter/material.dart';

import '../../models/reports/employees_report.dart';
import '../../services/api_service.dart';
import '../../services/report_service.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

class EmployeesReportScreen extends StatefulWidget {
  const EmployeesReportScreen({super.key});

  @override
  State<EmployeesReportScreen> createState() => _EmployeesReportScreenState();
}

class _EmployeesReportScreenState extends State<EmployeesReportScreen>
    with ReconnectReloader<EmployeesReportScreen> {
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
        _error = friendlyErrorMessage(context, e);
        _loading = false;
      });
    }
  }

  @override
  void onReconnected() {
    _loadReport();
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
      title: context.tr('Employees Report'),
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
                      title: context.tr('Overview'),
                      subtitle: context.tr(
                        'Standings for {0} and what has been paid out',
                        [monthLabel(_year, _month)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatGrid(
                      stats: [
                        StatData(
                          label: context.tr('Employees'),
                          value: '${report.employeeCount}',
                          icon: Icons.people_outline,
                        ),
                        StatData(
                          label: context.tr('Total Sales'),
                          value: money(report.totalSales),
                          icon: Icons.shopping_cart_outlined,
                        ),
                        StatData(
                          label: context.tr('Targets Met'),
                          value: '${report.targetMetCount}',
                          icon: Icons.flag_outlined,
                        ),
                        StatData(
                          label: context.tr('Monthly Salaries'),
                          value: money(report.totalMonthlySalaries),
                          icon: Icons.payments_outlined,
                        ),
                        StatData(
                          label: context.tr('Bonus Owed'),
                          value: money(report.totalBonusOwed),
                          icon: Icons.card_giftcard_outlined,
                        ),
                        StatData(
                          label: context.tr('Paid in Month'),
                          value: money(report.paymentTotalInMonth),
                          icon: Icons.check_circle_outline,
                        ),
                        StatData(
                          label: context.tr('Total Paid (All Time)'),
                          value: money(report.totalPaid),
                          icon: Icons.history,
                        ),
                        StatData(
                          label: context.tr('Left to Pay'),
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
                    SectionHeader(
                      title: context.tr('By Employee'),
                      subtitle: context.tr('One card for each member of staff'),
                    ),
                    const SizedBox(height: 12),
                    if (report.employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.badge_outlined,
                          title: context.tr('No employees yet'),
                          message: context.tr(
                            'Add employees before running this report.',
                          ),
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
                    context.tr('Employee of the Month'),
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
                    context.tr('{0} in sales during {1}', [
                      money(sales),
                      monthLabel,
                    ]),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (tied)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: StatusBadge(
                  label: context.tr('TIED'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    final hasTarget = item.target > 0;
    final rawProgress = hasTarget ? item.totalSales / item.target : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0).toDouble();
    final percent = (rawProgress * 100).round();

    final accent = item.achievedTarget
        ? AppPalette.success
        : AppPalette.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  _EmployeeAvatar(name: item.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('Sales {0}', [money(item.totalSales)]),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        item.achievedTarget
                            ? StatusBadge(
                                label: context.tr('TARGET MET'),
                                color: AppPalette.success,
                                icon: Icons.check_circle_outline,
                              )
                            : StatusBadge(
                                label: context.tr('BELOW TARGET'),
                                color: theme.colorScheme.outline,
                                icon: Icons.remove_circle_outline,
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TargetRing(
                    progress: progress,
                    percent: hasTarget ? percent : null,
                    color: accent,
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 12),
                  if (hasTarget) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Target progress: {0}% of {1}', [
                        percent,
                        money(item.target),
                      ]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 10.0;
                      final width = (constraints.maxWidth - spacing) / 2;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _StatChip(
                            width: width,
                            icon: Icons.payments_outlined,
                            label: context.tr('Salary'),
                            value: money(item.salary),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.flag_outlined,
                            label: context.tr('Target'),
                            value: hasTarget
                                ? money(item.target)
                                : context.tr('No target'),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.card_giftcard_outlined,
                            label: context.tr('Bonus'),
                            value: money(item.bonusAmount),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.shopping_cart_outlined,
                            label: context.tr('Total Sales'),
                            value: money(item.totalSales),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.pending_actions_outlined,
                            label: context.tr('Left to Pay'),
                            value: money(item.leftToPay),
                            valueColor: amountColor(context, -item.leftToPay),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.event_available_outlined,
                            label: context.tr('Paid in Month'),
                            value: money(item.paymentTotalInMonth),
                          ),
                          _StatChip(
                            width: width,
                            icon: Icons.history,
                            label: context.tr('Total Paid'),
                            value: money(item.totalPaid),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular initials badge used as the avatar on each employee card.
class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.name});

  final String name;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}

/// Ring that shows how far an employee is towards their monthly target.
class _TargetRing extends StatelessWidget {
  const _TargetRing({
    required this.progress,
    required this.percent,
    required this.color,
  });

  /// Fraction of the ring that is filled, already clamped to 0..1.
  final double progress;

  /// Percentage shown in the middle, or null when there is no target.
  final int? percent;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: percent == null ? 0 : progress,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (percent == null)
            Icon(
              Icons.flag_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            )
          else
            Text(
              '$percent%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact tinted tile used for a single figure in the expanded details.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
