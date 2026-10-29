import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../services/supplier_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import 'add_suppliers_screen.dart';

class ShowSuppliersScreen extends StatefulWidget {
  const ShowSuppliersScreen({super.key});

  @override
  State<ShowSuppliersScreen> createState() => _ShowSuppliersScreenState();
}

class _ShowSuppliersScreenState extends State<ShowSuppliersScreen>
    with ReconnectReloader<ShowSuppliersScreen> {
  final SupplierService _supplierService = SupplierService(ApiService());

  List<Supplier> _suppliers = [];
  final Set<int> _expanded = {};
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

    final amountText = await showAppAmountDialog(
      context,
      title: context.tr('Pay Debt'),
      label: context.tr('Amount'),
      initialValue: remaining.toStringAsFixed(2),
      helperText: context.tr('Remaining debt: {0}', [money(remaining)]),
      confirmLabel: context.tr('Pay'),
    );

    if (amountText == null || !mounted) return;

    final amount = double.tryParse(amountText);

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
      operation: () =>
          _supplierService.payDebt(supplierId: supplier.id, amount: amount),
      onCommitted: _loadSuppliers,
    );
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

                              // ---------- WIDE: inline icon buttons ----------
                              if (isWide) {
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: iconBox,
                                  title: title,
                                  subtitle: subtitle,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (supplier.debt > 0)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.payments_outlined),
                                          tooltip: context.tr('Pay debt'),
                                          onPressed: () => _paySupplierDebt(supplier),
                                        ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.history),
                                        tooltip: context.tr('Payment history'),
                                        onPressed: () => _showPaymentHistory(supplier),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: context.tr('Edit'),
                                        onPressed: () => _editSupplier(supplier),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: context.tr('Delete'),
                                        onPressed: () => _deleteSupplier(supplier),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // ---------- NARROW: pay button + overflow menu ----------
                              return ListTile(
                                contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                                leading: iconBox,
                                title: title,
                                subtitle: subtitle,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (supplier.debt > 0)
                                      IconButton.filledTonal(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.payments_outlined),
                                        tooltip: context.tr('Pay debt'),
                                        onPressed: () => _paySupplierDebt(supplier),
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
                                            title: Text(context.tr('Payment history')),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons.edit_outlined),
                                            title: Text(context.tr('Edit')),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.delete_outline, color: scheme.error),
                                            title: Text(
                                              context.tr('Delete'),
                                              style: TextStyle(color: scheme.error),
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

  Widget _buildInvoices(Supplier supplier) {
    if (supplier.purchaseInvoices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            context.tr('No purchase invoices recorded for this supplier.'),
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
                          leading: const Icon(
                            Icons.payments_outlined,
                            size: 20,
                          ),
                          title: Text(
                            money(payment.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_formatDateTime(payment.paidAt)),
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
