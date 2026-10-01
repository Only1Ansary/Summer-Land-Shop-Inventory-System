import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import 'create_invoice_screen.dart';
import 'sale_invoice_tile.dart';
import 'search_sale_invoices_screen.dart';
import 'show_sale_invoice_screen.dart';

class ShowSaleInvoicesScreen extends StatefulWidget {
  const ShowSaleInvoicesScreen({super.key});

  @override
  State<ShowSaleInvoicesScreen> createState() => _ShowSaleInvoicesScreenState();
}

class _ShowSaleInvoicesScreenState extends State<ShowSaleInvoicesScreen> {
  final InvoiceService _invoiceService = InvoiceService(ApiService());

  List<Invoice> _invoices = [];

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
      final invoices = await _invoiceService.getInvoices(from: _from, to: _to);

      if (!mounted) return;

      setState(() {
        _invoices = invoices;
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
    await pushScreen<void>(context, (_) => const SearchSaleInvoicesScreen());

    if (mounted) {
      _loadInvoices();
    }
  }

  Future<void> _newSale() async {
    await pushScreen<void>(context, (_) => const CreateInvoiceScreen());

    if (mounted) {
      _loadInvoices();
    }
  }

  void _openInvoice(Invoice invoice) {
    pushScreen<void>(
      context,
      (_) => ShowSaleInvoiceScreen(invoiceId: invoice.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Sale Invoices',
      destinationId: 'sale-invoices',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _newSale,
        tooltip: 'New sale',
        child: const Icon(Icons.add),
      ),
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

                        return SaleInvoiceTile(
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
