import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../services/supplier_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'add_suppliers_screen.dart';

class ShowSuppliersScreen extends StatefulWidget {
  const ShowSuppliersScreen({super.key});

  @override
  State<ShowSuppliersScreen> createState() =>
      _ShowSuppliersScreenState();
}

class _ShowSuppliersScreenState extends State<ShowSuppliersScreen> {
  final SupplierService _supplierService =
      SupplierService(ApiService());

  List<Supplier> _suppliers = [];
  final Set<int> _expanded = {};

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final suppliers = await _supplierService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addSupplier() async {
    final added = await pushScreen<bool>(
      context,
      (_) => const AddSuppliersScreen(),
    );

    if (added == true) {
      _loadSuppliers();
    }
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final updated = await pushScreen<bool>(
      context,
      (_) => AddSuppliersScreen(supplier: supplier),
    );

    if (updated == true) {
      _loadSuppliers();
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete supplier',
      message: 'Delete "${supplier.supplierName}"?',
    );

    if (!confirmed) return;

    try {
      await _supplierService.deleteSupplier(supplier.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${supplier.supplierName} deleted.')),
      );

      _loadSuppliers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _paySupplierDebt(Supplier supplier) async {
    final remaining = supplier.debt;

    final amountText = await showAppAmountDialog(
      context,
      title: 'Pay Debt',
      label: 'Amount',
      initialValue: remaining.toStringAsFixed(2),
      helperText: 'Remaining debt: ${money(remaining)}',
      confirmLabel: 'Pay',
    );

    if (amountText == null || !mounted) return;

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }

    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cannot exceed the remaining debt of '
            '${money(remaining)}.',
          ),
        ),
      );
      return;
    }

    try {
      await _supplierService.payDebt(
        supplierId: supplier.id,
        amount: amount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debt payment recorded.'),
        ),
      );

      _loadSuppliers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _toggleExpanded(int id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }

  void _showPaymentHistory(Supplier supplier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentHistorySheet(
        supplierService: _supplierService,
        supplier: supplier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Suppliers',
      destinationId: 'suppliers',
      floatingActionButton: FloatingActionButton(
        onPressed: _addSupplier,
        tooltip: 'Add supplier',
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
      return ErrorState(
        message: _error!,
        onRetry: _loadSuppliers,
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: _suppliers.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.factory_outlined,
                    title: 'No suppliers yet',
                    message:
                        'Suppliers are created automatically when you '
                        'save a purchase invoice, or by tapping + below.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _suppliers[index];
                  final expanded =
                      _expanded.contains(supplier.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.factory_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(supplier.supplierName),
                          subtitle: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Debt: '),
                                TextSpan(
                                  text: moneyNegative(supplier.debt),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: amountColor(
                                      context,
                                      -supplier.debt,
                                    ),
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '  ·  ${supplier.invoiceCount} '
                                      'invoice${supplier.invoiceCount == 1 ? '' : 's'}',
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (supplier.debt > 0)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.payments_outlined),
                                  tooltip: 'Pay debt',
                                  onPressed: () =>
                                      _paySupplierDebt(supplier),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.history),
                                tooltip: 'Payment history',
                                onPressed: () =>
                                    _showPaymentHistory(supplier),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                                onPressed: () =>
                                    _editSupplier(supplier),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _deleteSupplier(supplier),
                              ),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.expand_more),
                              ),
                            ],
                          ),
                          onTap: () => _toggleExpanded(supplier.id),
                        ),
                        if (expanded) _buildInvoices(supplier),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildInvoices(Supplier supplier) {
    if (supplier.purchaseInvoices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No purchase invoices recorded for this supplier.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return Column(
      children: [
        const Divider(height: 1),
        ...supplier.purchaseInvoices.map((invoice) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.receipt_long_outlined, size: 20),
            title: Text('#${invoice.id}'),
            subtitle: Text(_formatDate(invoice.date)),
            trailing: Text(
              moneyNegative(invoice.debt),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amountColor(context, -invoice.debt),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Bottom sheet that loads and lists a supplier's recorded payments.
class _PaymentHistorySheet extends StatefulWidget {
  const _PaymentHistorySheet({
    required this.supplierService,
    required this.supplier,
  });

  final SupplierService supplierService;
  final Supplier supplier;

  @override
  State<_PaymentHistorySheet> createState() => _PaymentHistorySheetState();
}

class _PaymentHistorySheetState extends State<_PaymentHistorySheet> {
  List<SupplierPayment>? _payments;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _payments = null;
      _error = null;
    });

    try {
      final payments =
          await widget.supplierService.getSupplierPayments(widget.supplier.id);

      if (!mounted) return;

      setState(() {
        _payments = payments;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }
  }

  String _formatDateTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour < 12 ? 'AM' : 'PM';

    return '${date.day}/${date.month}/${date.year}  $h:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final payments = _payments;
    final totalPaid = payments?.fold<double>(0, (sum, p) => sum + p.amount);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.supplier.supplierName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? ErrorState(
                      message: _error!,
                      onRetry: _load,
                    )
                  : payments == null
                      ? const LoadingState()
                      : payments.isEmpty
                          ? const EmptyState(
                              icon: Icons.history,
                              title: 'No payments recorded yet',
                              message:
                                  'Payments appear here when you pay a '
                                  'purchase invoice or supplier debt.',
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 16),
                              itemCount: payments.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Total paid: ${money(totalPaid!)}',
                                      style: theme.textTheme.titleSmall!
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }

                                final payment = payments[index - 1];

                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.payments_outlined,
                                    size: 20,
                                  ),
                                  title: Text(
                                    money(payment.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDateTime(payment.paidAt),
                                  ),
                                  trailing: payment.purchaseInvoiceId == null
                                      ? null
                                      : Text(
                                          'Invoice #${payment.purchaseInvoiceId}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}