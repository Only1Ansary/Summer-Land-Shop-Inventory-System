import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../models/employee_month.dart';
import '../../models/employee_payment.dart';
import '../../services/api_service.dart';
import '../../services/employee_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

/// Month-by-month record of one employee.
///
/// The figures come from the sales data, so this screen is for viewing
/// only - nothing here is entered by hand.
class EmployeeHistoryScreen extends StatefulWidget {
  const EmployeeHistoryScreen({super.key, required this.employee});

  final Employee employee;

  @override
  State<EmployeeHistoryScreen> createState() => _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends State<EmployeeHistoryScreen> {
  final EmployeeService _employeeService = EmployeeService(ApiService());

  List<EmployeeMonth> _months = [];
  List<EmployeePayment> _payments = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _employeeService.getEmployeeHistory(widget.employee.id),
        _employeeService.getPayments(widget.employee.id),
      ]);

      if (!mounted) return;

      setState(() {
        _months = results[0] as List<EmployeeMonth>;
        _payments = results[1] as List<EmployeePayment>;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '${widget.employee.name} · History',
      destinationId: 'employees',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadHistory);
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CurrentMonthCard(employee: widget.employee),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Monthly history',
              subtitle: 'Recorded from sales, newest first',
            ),
            const SizedBox(height: 12),
            if (_months.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No monthly history yet',
                  message:
                      'Each month appears here once sales are recorded '
                      'for this employee.',
                ),
              )
            else
              for (final month in _months)
                EmployeeMonthTile(
                  record: month,
                  target: widget.employee.target,
                  bonusType: widget.employee.bonusType,
                  bonusValue: widget.employee.bonus,
                ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Payments',
              subtitle: 'Salary and bonus paid out, newest first',
            ),
            const SizedBox(height: 12),
            if (_payments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No payments yet',
                  message:
                      'Tap the payments button on the Employees screen '
                      'to record what was paid out.',
                ),
              )
            else
              for (final payment in _payments) _PaymentTile(payment: payment),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final EmployeePayment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatDate(payment.paidAt),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              money(payment.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// The employee's figures for the month in progress.
class _CurrentMonthCard extends StatelessWidget {
  const _CurrentMonthCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This month',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            InfoTile(label: 'Total Sales', value: money(employee.totalSales)),
            InfoTile(label: 'Target', value: money(employee.target)),
            InfoTile(label: 'Bonus', value: money(employee.bonusAmount)),
          ],
        ),
      ),
    );
  }
}

/// A single month's recorded figures.
class EmployeeMonthTile extends StatelessWidget {
  const EmployeeMonthTile({
    super.key,
    required this.record,
    required this.target,
    required this.bonusType,
    required this.bonusValue,
  });

  final EmployeeMonth record;

  /// The employee's target, used to show progress for the month.
  final double target;

  /// The employee's bonus rule, used to work out the month's bonus.
  final BonusType bonusType;
  final double bonusValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (record.isCurrentMonth) ...[
                  StatusBadge(
                    label: 'THIS MONTH',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                record.reachedTarget(target)
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
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _MonthMetric(
                  label: 'Total sales',
                  value: money(record.totalSales),
                ),
                _MonthMetric(label: 'Target', value: money(target)),
                _MonthMetric(
                  label: 'Bonus',
                  value: money(record.bonusAmount(bonusType, bonusValue)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthMetric extends StatelessWidget {
  const _MonthMetric({required this.label, required this.value});

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
