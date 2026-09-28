import 'package:flutter/material.dart';

import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import 'create_purchase_invoice_screen.dart';
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
  final PurchaseInvoiceService _purchaseInvoiceService =
      PurchaseInvoiceService(ApiService());

  List<PurchaseInvoice> _invoices = [];

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
      final invoices = await _purchaseInvoiceService.getPurchaseInvoices();

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
      (_) => const SearchPurchaseInvoicesScreen(),
    );

    _loadInvoices();
  }

  Future<void> _addInvoice() async {
    await pushScreen<void>(
      context,
      (_) => const CreatePurchaseInvoiceScreen(),
    );

    _loadInvoices();
  }

  void _openInvoice(PurchaseInvoice invoice) {
    pushScreen<void>(
      context,
      (_) => ShowPurchaseInvoiceScreen(invoiceId: invoice.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Purchase Invoices',
      destinationId: 'purchase-invoices',
      actions: [
        IconButton(
          onPressed: _openSearch,
          tooltip: 'Search invoices',
          icon: const Icon(Icons.search),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _addInvoice,
        tooltip: 'Add purchase invoice',
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
                    title: 'No purchase invoices yet',
                    message: 'Tap + to record your first purchase.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
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
    );
  }
}