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
  State<ShowSaleInvoicesScreen> createState() =>
      _ShowSaleInvoicesScreenState();
}

class _ShowSaleInvoicesScreenState
    extends State<ShowSaleInvoicesScreen> {
  final InvoiceService _invoiceService =
      InvoiceService(ApiService());

  List<Invoice> _invoices = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoices = await _invoiceService.getInvoices();

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

  Future<void> _openSearch() async {
    await pushScreen<void>(
      context,
      (_) => const SearchSaleInvoicesScreen(),
    );

    if (mounted) {
      _loadInvoices();
    }
  }

  Future<void> _newSale() async {
    await pushScreen<void>(
      context,
      (_) => const CreateInvoiceScreen(),
    );

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
        onRetry: _loadInvoices,
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadInvoices,
        child: _invoices.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No sale invoices yet',
                    message:
                        'Tap + to record your first sale.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
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
    );
  }
}