import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/payment_method.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import 'add_suppliers_screen.dart';
import '../../ui/text_input_helpers.dart';

class ShowSuppliersScreen extends StatefulWidget {
  const ShowSuppliersScreen({super.key});

  @override
  State<ShowSuppliersScreen> createState() => _ShowSuppliersScreenState();
}

class _ShowSuppliersScreenState extends State<ShowSuppliersScreen>
    with ReconnectReloader<ShowSuppliersScreen> {
  final SupplierService _supplierService = SupplierService(ApiService());

  List<Supplier> _suppliers = [];
  String _query = '';
  final Debouncer _searchDebounce = Debouncer();

  bool _isLoading = false;
  String? _error;

  static const int _pageSize = 10;
  int _currentPage = 0;

  List<Supplier> get _filteredSuppliers {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return _suppliers;

    return _suppliers
        .where((s) => s.supplierName.toLowerCase().contains(query))
        .toList();
  }

  List<Supplier> get _pageSuppliers {
    final list = _filteredSuppliers;
    final start = _currentPage * _pageSize;

    if (start >= list.length) return const [];

    final end = start + _pageSize;

    return list.sublist(start, end > list.length ? list.length : end);
  }

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
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
        _error = friendlyErrorMessage(context, e);
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
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  Future<void> _addSupplier() async {
    if (!ensureOnlineForWrite(context)) return;

    final added = await pushScreen<DeferredCrud>(
      context,
          (_) => const AddSuppliersScreen(),
    );

    if (added == null) return;

    scheduleDeferredCrud(context, added, onCommitted: _loadSuppliers);
  }

  Future<void> _editSupplier(Supplier supplier) async {
    if (!ensureOnlineForWrite(context)) return;

    final updated = await pushScreen<DeferredCrud>(
      context,
          (_) => AddSuppliersScreen(supplier: supplier),
    );

    if (updated == null) return;

    scheduleDeferredCrud(context, updated, onCommitted: _loadSuppliers);
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    if (!ensureOnlineForWrite(context)) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: context.tr('Delete supplier'),
      message: context.tr('Delete "{0}"?', [supplier.supplierName]),
    );

    if (!confirmed) return;

    scheduleUndoable(
      context,
      message: context.tr('"{0}" will be deleted. Tap Undo to cancel.', [
        supplier.supplierName,
      ]),
      operation: () => _supplierService.deleteSupplier(supplier.id),
      onCommitted: _loadSuppliers,
    );
  }

  Future<void> _paySupplierDebt(Supplier supplier) async {
    if (!ensureOnlineForWrite(context)) return;

    final remaining = supplier.debt;

    // The dialog is its own StatefulWidget so that its TextEditingController
    // is created and disposed by the framework together with the dialog's
    // element tree. Disposing a controller right after `showDialog` returns
    // runs while the route's exit animation is still building the TextField,
    // which crashes on Android when the keyboard is open.
    final entry = await showDialog<_SupplierPaymentEntry>(
      context: context,
      builder: (dialogContext) => _SupplierPayDebtDialog(
        remaining: remaining,
        initialMethod: paymentMethodCash,
      ),
    );

    if (entry == null || !mounted) return;

    final amount = double.tryParse(entry.amountText.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter a valid payment amount.'))),
      );
      return;
    }

    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Payment cannot exceed the remaining debt of {0}.', [
              money(remaining),
            ]),
          ),
        ),
      );
      return;
    }

    scheduleUndoable(
      context,
      message: context.tr(
        'Payment to {0} will be recorded. Tap Undo to cancel.',
        [supplier.supplierName],
      ),
      operation: () => _supplierService.payDebt(
        supplierId: supplier.id,
        amount: amount,
        method: entry.method,
      ),
      onCommitted: _loadSuppliers,
    );
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
      title: context.tr('Suppliers'),
      destinationId: 'suppliers',
      floatingActionButton: FloatingActionButton(
        onPressed: _addSupplier,
        tooltip: context.tr('Add supplier'),
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
      return ErrorState(message: _error!, onRetry: _loadSuppliers);
    }

    return WideContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              autofocus: textFieldAutofocus(false),
              decoration: InputDecoration(
                labelText: context.tr('Search suppliers'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchDebounce.cancel();
                    setState(() {
                      _query = '';
                      _currentPage = 0;
                    });
                  },
                )
                    : null,
              ),
              onChanged: (value) {
                _searchDebounce.run(() {
                  setState(() {
                    _query = value;
                    _currentPage = 0;
                  });
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSuppliers,
              child: _suppliers.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.factory_outlined,
                    title: context.tr('No suppliers yet'),
                    message: context.tr(
                      'Suppliers are created automatically when you '
                          'save a purchase invoice, or by tapping + below.',
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pageSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _pageSuppliers[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 560;
                        final scheme = Theme.of(context).colorScheme;

                        final iconBox = Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.factory_rounded, color: scheme.primary),
                        );

                        final subtitle = Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: context.tr('Debt: ')),
                              TextSpan(
                                text: moneyNegative(supplier.debt),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: amountColor(context, -supplier.debt),
                                ),
                              ),
                              TextSpan(
                                text: context.tr('\n{0} {1}', [
                                  supplier.invoiceCount,
                                  supplier.invoiceCount == 1
                                      ? context.tr('invoice')
                                      : context.tr('invoices'),
                                ]),
                              ),
                            ],
                          ),
                        );

                        final title = Text(
                          supplier.supplierName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );

                        final details = Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle(
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall!
                                    .copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                child: title,
                              ),
                              const SizedBox(height: 4),
                              DefaultTextStyle(
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                child: subtitle,
                              ),
                            ],
                          ),
                        );

                        // ---------- WIDE: inline icon buttons ----------
                        if (isWide) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                iconBox,
                                const SizedBox(width: 12),
                                details,
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (supplier.debt > 0)
                                      IconButton(
                                        visualDensity:
                                        VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                        ),
                                        tooltip:
                                        context.tr('Pay debt'),
                                        onPressed: () =>
                                            _paySupplierDebt(supplier),
                                      ),
                                    IconButton(
                                      visualDensity:
                                      VisualDensity.compact,
                                      icon: const Icon(Icons.history),
                                      tooltip: context.tr(
                                        'Payment history',
                                      ),
                                      onPressed: () =>
                                          _showPaymentHistory(supplier),
                                    ),
                                    IconButton(
                                      visualDensity:
                                      VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                      ),
                                      tooltip: context.tr('Edit'),
                                      onPressed: () =>
                                          _editSupplier(supplier),
                                    ),
                                    IconButton(
                                      visualDensity:
                                      VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                      ),
                                      tooltip: context.tr('Delete'),
                                      onPressed: () =>
                                          _deleteSupplier(supplier),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        // ---------- NARROW: pay button + overflow menu ----------
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 12,
                            end: 4,
                            top: 8,
                            bottom: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              iconBox,
                              const SizedBox(width: 12),
                              details,
                              if (supplier.debt > 0)
                                IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.payments_outlined,
                                  ),
                                  tooltip: context.tr('Pay debt'),
                                  onPressed: () =>
                                      _paySupplierDebt(supplier),
                                ),
                              PopupMenuButton<String>(
                                tooltip: context.tr('More'),
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'history':
                                      _showPaymentHistory(supplier);
                                    case 'edit':
                                      _editSupplier(supplier);
                                    case 'delete':
                                      _deleteSupplier(supplier);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'history',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.history),
                                      title: Text(
                                        context.tr('Payment history'),
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.edit_outlined,
                                      ),
                                      title: Text(context.tr('Edit')),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: scheme.error,
                                      ),
                                      title: Text(
                                        context.tr('Delete'),
                                        style: TextStyle(
                                          color: scheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          PaginationBar(
            page: _currentPage,
            pageSize: _pageSize,
            totalItems: _suppliers.length,
            onPageChanged: _goToPage,
          ),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

}

// -----------------------------------------------------------------------------
// Pay debt dialog
// -----------------------------------------------------------------------------

class _SupplierPayDebtDialog extends StatefulWidget {
  const _SupplierPayDebtDialog({
    required this.remaining,
    required this.initialMethod,
  });

  final double remaining;
  final int initialMethod;

  @override
  State<_SupplierPayDebtDialog> createState() => _SupplierPayDebtDialogState();
}

class _SupplierPayDebtDialogState extends State<_SupplierPayDebtDialog> {
  late final TextEditingController _amountController;
  late int _method;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remaining.toStringAsFixed(2),
    );
    _method = widget.initialMethod;
  }

  @override
  void dispose() {
    // Runs only once the dialog route has been fully removed from the tree.
    _amountController.dispose();
    super.dispose();
  }

  void _cancel() {
    // Let the keyboard start closing before the route's exit animation.
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _SupplierPaymentEntry(
        amountText: _amountController.text,
        method: _method,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      // Keep the title and buttons inside the scrollable area so a tall
      // Android keyboard cannot squeeze them into an overflowing flex.
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('Pay Debt'))),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('Remaining debt: {0}', [money(widget.remaining)]),
            style: TextStyle(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            // Avoid opening the keyboard (and shrinking the viewport)
            // as soon as the dialog appears on Android.
            autofocus: textFieldAutofocus(true),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*$'),
              ),
            ],
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              prefixText: '\u20a6 ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('supplier-payment-method'),
            initialValue: _method,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Payment method'),
              prefixIcon: const Icon(Icons.credit_card_outlined),
              border: const OutlineInputBorder(),
            ),
            items: paymentMethodValues.map((value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Row(
                  children: [
                    Icon(paymentMethodIcon(value), size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        paymentMethodLabel(context, value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _method = value);
            },
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr(
                    'Applied to the oldest unpaid invoices first.',
                  ),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: _cancel,
                child: Text(context.tr('Cancel')),
              ),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('Pay')),
              ),
            ],
          ),
        ],
      ),
    );
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
      final payments = await widget.supplierService.getSupplierPayments(
        widget.supplier.id,
      );

      if (!mounted) return;

      setState(() {
        _payments = payments;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    }
  }

  String _formatDateTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour < 12 ? context.tr('AM') : context.tr('PM');

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
                          context.tr('Payment History'),
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
                    tooltip: context.tr('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : payments == null
                  ? const LoadingState()
                  : payments.isEmpty
                  ? EmptyState(
                icon: Icons.history,
                title: context.tr('No payments recorded yet'),
                message: context.tr(
                  'Payments appear here when you pay a '
                      'purchase invoice or supplier debt.',
                ),
              )
                  : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: payments.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.tr('Total paid: {0}', [
                          money(totalPaid!),
                        ]),
                        style: theme.textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  final payment = payments[index - 1];

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      paymentMethodIcon(payment.method),
                      size: 20,
                    ),
                    title: Text(
                      money(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${paymentMethodLabel(context, payment.method)} · '
                          '${_formatDateTime(payment.paidAt)}',
                    ),
                    trailing: payment.purchaseInvoiceId == null
                        ? null
                        : Text(
                      context.tr('Invoice #{0}', [
                        payment.purchaseInvoiceId,
                      ]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

/// Amount and method chosen in the supplier debt payment dialog.
class _SupplierPaymentEntry {
  const _SupplierPaymentEntry({required this.amountText, required this.method});

  final String amountText;
  final int method;
}