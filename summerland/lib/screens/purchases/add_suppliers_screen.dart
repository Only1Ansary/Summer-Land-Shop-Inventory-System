import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../services/supplier_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class AddSuppliersScreen extends StatefulWidget {
  const AddSuppliersScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  State<AddSuppliersScreen> createState() => _AddSuppliersScreenState();
}

class _AddSuppliersScreenState extends State<AddSuppliersScreen> {
  final SupplierService _supplierService =
      SupplierService(ApiService());

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _paidController =
      TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.supplier != null;

  double get _currentDebt => widget.supplier?.debt ?? 0;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.supplier?.supplierName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final paidText = _paidController.text.trim();
    final paid = double.tryParse(paidText);
    final newDebt = paid == null
        ? _currentDebt
        : (_currentDebt - paid).clamp(0, double.infinity);

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await _supplierService.updateSupplier(
          widget.supplier!.id,
          supplierName: name,
          debt: newDebt.toDouble(),
        );
      } else {
        await _supplierService.createSupplier(name);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier'),
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
                  labelText: 'Supplier Name',
                  prefixIcon: Icon(Icons.factory_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Supplier name is required.';
                  }

                  return null;
                },
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current debt'),
                      Text(
                        moneyNegative(_currentDebt),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _currentDebt > 0
                              ? AppPalette.danger
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    prefixIcon: Icon(Icons.payments_outlined),
                    helperText: "Reduces the supplier's debt.",
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }

                    final parsed = double.tryParse(value.trim());

                    if (parsed == null) {
                      return 'Enter a valid amount.';
                    }

                    if (parsed <= 0) {
                      return 'Enter an amount greater than zero.';
                    }

                    if (_currentDebt <= 0) {
                      return 'No debt to pay.';
                    }

                    if (parsed > _currentDebt) {
                      return 'Amount cannot exceed the current debt.';
                    }

                    return null;
                  },
                ),
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
                label: Text(_isEditing ? 'Save Changes' : 'Add Supplier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}