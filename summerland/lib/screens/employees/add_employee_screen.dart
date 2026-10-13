import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../services/api_service.dart';
import '../../services/employee_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

/// Adds a new employee, or edits an existing one.
///
/// A new employee only needs a name, salary and target - the bonus starts
/// at zero. While editing, the bonus can be set as a fixed amount or as a
/// percentage of the employee's total sales. Total sales and the "achieved
/// target" flag are recorded from sales data, so they are shown while
/// editing but never entered here.
class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key, this.employee});

  final Employee? employee;

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final EmployeeService _employeeService = EmployeeService(ApiService());

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _salaryController;
  late final TextEditingController _targetController;
  late final TextEditingController _bonusController;

  bool _isSaving = false;

  BonusType _bonusType = BonusType.fixed;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();

    final employee = widget.employee;

    _nameController = TextEditingController(text: employee?.name ?? '');
    _salaryController = TextEditingController(
      text: employee == null ? '' : _formatInput(employee.salary),
    );
    _targetController = TextEditingController(
      text: employee == null ? '' : _formatInput(employee.target),
    );
    _bonusController = TextEditingController(
      text: _formatInput(employee?.bonus ?? 0),
    );
    _bonusType = employee?.bonusType ?? BonusType.fixed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    _targetController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  /// Pre-fills a money field without a trailing ".0" for whole numbers.
  String _formatInput(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the employee name.';
    }

    return null;
  }

  String? _validateMoney(String? value, String label) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter the $label.';
    }

    final parsed = double.tryParse(text);

    if (parsed == null) {
      return 'Enter a valid $label.';
    }

    if (parsed < 0) {
      return 'Enter a $label of 0 or more.';
    }

    return null;
  }

  String? _validateBonus(String? value) {
    final error = _validateMoney(value, 'bonus');

    if (error != null) {
      return error;
    }

    if (_bonusType == BonusType.percentage &&
        double.parse(value!.trim()) > 100) {
      return 'Enter a bonus percent between 0 and 100.';
    }

    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final salary = double.parse(_salaryController.text.trim());
    final target = double.parse(_targetController.text.trim());

    try {
      if (_isEditing) {
        await _employeeService.updateEmployee(
          widget.employee!.id,
          name: name,
          salary: salary,
          target: target,
          bonus: double.parse(_bonusController.text.trim()),
          bonusType: _bonusType,
        );
      } else {
        await _employeeService.createEmployee(
          name: name,
          salary: salary,
          target: target,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add Employee'),
      ),
      body: ResponsiveFormPage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Salary',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: 'EGP',
                ),
                validator: (value) => _validateMoney(value, 'salary'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Target',
                  prefixIcon: Icon(Icons.flag_outlined),
                  suffixText: 'EGP',
                  helperText: 'Sales the employee is expected to reach.',
                ),
                validator: (value) => _validateMoney(value, 'target'),
              ),

              // The bonus starts at zero when an employee is added, so it
              // is only entered while editing.
              if (_isEditing) ...[
                const SizedBox(height: 16),
                SegmentedButton<BonusType>(
                  segments: const [
                    ButtonSegment(
                      value: BonusType.fixed,
                      label: Text('Fixed amount'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: BonusType.percentage,
                      label: Text('Percent of sales'),
                      icon: Icon(Icons.percent),
                    ),
                  ],
                  selected: {_bonusType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _bonusType = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bonusController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _bonusType == BonusType.fixed
                        ? 'Bonus'
                        : 'Bonus Percent',
                    prefixIcon: const Icon(Icons.card_giftcard_outlined),
                    suffixText: _bonusType == BonusType.fixed ? 'EGP' : '%',
                    helperText: _bonusType == BonusType.fixed
                        ? 'A one-off amount paid with the salary.'
                        : 'Applied to the employee\'s total sales.',
                  ),
                  validator: _validateBonus,
                ),
                const SizedBox(height: 16),
                _SalesRecord(employee: widget.employee!),
              ],

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditing ? 'Save Changes' : 'Add Employee'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only view of the figures that come from sales data.
class _SalesRecord extends StatelessWidget {
  const _SalesRecord({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Recorded from sales (view only)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InfoTile(label: 'Total Sales', value: money(employee.totalSales)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Achieved target',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                employee.reachedTarget
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
          ),
        ],
      ),
    );
  }
}
