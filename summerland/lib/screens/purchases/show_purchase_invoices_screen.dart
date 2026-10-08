import 'package:flutter/material.dart';

import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import 'purchase_invoice_tile.dart';
import 'search_purchase_invoices_screen.dart';
import 'show_purchase_invoice_screen.dart';

class ShowPurchaseInvoicesScreen extends StatefulWidget {
  const ShowPurchaseInvoicesScreen({super.key});

  @override
  State<ShowPurchaseInvoicesScreen> createState() =>
      _ShowPurchaseInvoicesScreenState();
}

class _ShowPurchaseInvoicesScreenState
    extends State<ShowPurchaseInvoicesScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService = PurchaseInvoiceService(
    ApiService(),
  );

  List<PurchaseInvoice> _invoices = [];

  DateTime? _from;
  DateTime? _to;
  bool _edited = false;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoices = await _purchaseInvoiceService.getPurchaseInvoices(
        from: _from,
        to: _to,
      );

      if (!mounted) return;

      setState(() {
        _invoices = invoices;
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

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _edited = true;
    });

    await _loadInvoices();
  }

  void _resetDates() {
    setState(() {
      _from = defaultFilterFromDate();
      _to = defaultFilterToDate();
      _edited = false;
    });

    _loadInvoices();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openSearch() async {
    await pushScreen<void>(
      context,
      (_) => const SearchPurchaseInvoicesScreen(),
    );

    _loadInvoices();
  }

  Future<void> _openInvoice(PurchaseInvoice invoice) async {
    await pushScreen<void>(
      context,
      (_) => ShowPurchaseInvoiceScreen(invoiceId: invoice.id),
    );

    if (mounted) {
      _loadInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Purchase Invoices',
      destinationId: 'purchase-invoices',
      actions: [
        IconButton(
          onPressed: _resetDates,
          tooltip: 'Reset to today',
          icon: const Icon(Icons.today_outlined),
        ),
        IconButton(
          onPressed: _openSearch,
          tooltip: 'Search invoices',
          icon: const Icon(Icons.search),
        ),
      ],
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadInvoices)
          : _buildList(),
    );
  }

  Widget _buildList() {
    return WideContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DateFilterBar(
              fromLabel: _from == null ? 'From' : _formatDate(_from!),
              toLabel: _to == null ? 'To' : _formatDate(_to!),
              onFrom: () => _pickDate(true),
              onTo: () => _pickDate(false),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInvoices,
              child: _invoices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _edited
                              ? 'No invoices in this period'
                              : 'No invoices today',
                          message: 'Try changing the date range.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = _invoices[index];

                        return PurchaseInvoiceTile(
                          invoice: invoice,
                          onTap: () => _openInvoice(invoice),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
