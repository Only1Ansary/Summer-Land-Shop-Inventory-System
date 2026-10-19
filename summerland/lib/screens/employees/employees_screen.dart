import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../services/api_service.dart';
import '../../services/employee_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import 'add_employee_screen.dart';
import 'employee_history_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen>
    with ReconnectReloader<EmployeesScreen> {
  final EmployeeService _employeeService = EmployeeService(ApiService());

  List<Employee> _employees = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employees = await _employeeService.getEmployees();

      if (!mounted) return;

      setState(() {
        _employees = employees;
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
  void onReconnected() {
    _loadEmployees();
  }

  Future<void> _addEmployee() async {
    final added = await pushScreen<bool>(
      context,
      (_) => const AddEmployeeScreen(),
    );

    if (added == true) {
      _loadEmployees();
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    final updated = await pushScreen<bool>(
      context,
      (_) => AddEmployeeScreen(employee: employee),
    );

    if (updated == true) {
      _loadEmployees();
    }
  }

  void _openHistory(Employee employee) {
    pushScreen<void>(context, (_) => EmployeeHistoryScreen(employee: employee));
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${employee.name}?'),
        content: const Text(
          'Their sales history will be removed. '
          'Invoices they sold keep the employee name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _employeeService.deleteEmployee(employee.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${employee.name} was deleted.')));
      _loadEmployees();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _payEmployee(Employee employee) async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => _PayEmployeeDialog(employee: employee),
    );

    if (paid != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment recorded for ${employee.name}.')),
    );
    _loadEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Employees',
      destinationId: 'employees',
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmployee,
        tooltip: 'Add employee',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadEmployees);
    }

    if (_employees.isEmpty) {
      return WideContent(
        child: RefreshIndicator(
          onRefresh: _loadEmployees,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.badge_outlined,
                title: 'No employees yet',
                message: 'Tap + to add your first employee.',
              ),
            ],
          ),
        ),
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadEmployees,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _employees.length,
          itemBuilder: (context, index) {
            final employee = _employees[index];

            return _EmployeeCard(
              employee: employee,
              onHistory: () => _openHistory(employee),
              onPay: () => _payEmployee(employee),
              onEdit: () => _editEmployee(employee),
              onDelete: () => _deleteEmployee(employee),
            );
          },
        ),
      ),
    );
  }
}

/// Trims a percent value to something short, e.g. 10 or 7.5.
String _formatPercent(double value) {
  return value == value.roundToDouble() ? '${value.round()}' : '$value';
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.onHistory,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final Employee employee;
  final VoidCallback onHistory;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            LayoutBuilder(
              builder: (context, constraints) {
                final double available = constraints.maxWidth;

                final Widget avatar = Container(
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
                );

                final Widget name = Text(
                  employee.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                );

                final Widget badge = employee.reachedTarget
                    ? const StatusBadge(
                        label: 'TARGET MET',
                        color: AppPalette.success,
                        icon: Icons.check_circle_outline,
                      )
                    : StatusBadge(
                        label: 'BELOW TARGET',
                        color: theme.colorScheme.outline,
                        icon: Icons.remove_circle_outline,
                      );

                final List<Widget> actions = [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.history),
                    tooltip: 'Monthly history',
                    onPressed: onHistory,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.payments_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: 'Record payment',
                    onPressed: onPay,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ];

                // On phones the badge and the four action buttons do not fit
                // beside the name, so the buttons take their own line instead
                // of pushing the card past the screen edge.
                if (available < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(child: name),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: name),
                    const SizedBox(width: 8),
                    badge,
                    ...actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Metric(label: 'Salary', value: money(employee.salary)),
                _Metric(label: 'Target', value: money(employee.target)),
                _Metric(
                  label: employee.bonusType == BonusType.percentage
                      ? 'Bonus (${_formatPercent(employee.bonus)}%)'
                      : 'Bonus',
                  value: money(employee.bonusAmount),
                ),
                _Metric(
                  label: 'Total sales',
                  value: money(employee.totalSales),
                ),
                _Metric(
                  label: 'Left to pay',
                  value: money(employee.effectiveLeftToPay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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

/// Asks for the amount actually paid out and records it.
///
/// The amount starts at salary + bonus; the bonus is a one-time payout that
/// the backend clears once the payment is recorded.
class _PayEmployeeDialog extends StatefulWidget {
  const _PayEmployeeDialog({required this.employee});

  final Employee employee;

  @override
  State<_PayEmployeeDialog> createState() => _PayEmployeeDialogState();
}

class _PayEmployeeDialogState extends State<_PayEmployeeDialog> {
  final EmployeeService _service = EmployeeService(ApiService());

  late final TextEditingController _amountController;

  bool _saving = false;
  String? _error;

  double get _defaultAmount => widget.employee.effectiveLeftToPay;

  String _plainAmount(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e12) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _plainAmount(_defaultAmount),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter a payment amount greater than zero.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.recordPayment(
        widget.employee.id,
        amount: amount,
        paidAt: DateTime.now(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Pay ${widget.employee.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Salary ${money(widget.employee.salary)}'
            ' + bonus ${money(widget.employee.bonusAmount)}'
            ' = ${money(widget.employee.totalCompensation)} due this month',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Left to pay: ${money(widget.employee.effectiveLeftToPay)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount paid',
              prefixIcon: const Icon(Icons.payments_outlined),
              helperText: 'Prefilled with what is left to pay.',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _record,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record payment'),
        ),
      ],
    );
  }
}
