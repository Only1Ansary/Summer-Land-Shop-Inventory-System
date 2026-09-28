import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../ui/app_widgets.dart';
import 'sale_invoice_tile.dart';
import 'show_sale_invoice_screen.dart';

class SearchSaleInvoicesScreen extends StatefulWidget {
  const SearchSaleInvoicesScreen({super.key});

  @override
  State<SearchSaleInvoicesScreen> createState() =>
      _SearchSaleInvoicesScreenState();
}

class _SearchSaleInvoicesScreenState
    extends State<SearchSaleInvoicesScreen> {
  final InvoiceService _invoiceService =
      InvoiceService(ApiService());

  final TextEditingController _queryController =
      TextEditingController();

  List<Invoice> _invoices = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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

  List<Invoice> get _results {
    final query = _queryController.text.trim().toLowerCase();

    return _invoices.where((invoice) {
      final matchesId = query.isEmpty ||
          '#${invoice.id}'.contains(query) ||
          '${invoice.id}'.contains(query);

      final matchesLocation =
          query.isEmpty ||
              invoice.locationName.toLowerCase().contains(query);

      final matchesItem = query.isEmpty ||
          invoice.items.any((item) =>
              item.productName.toLowerCase().contains(query) ||
              item.modelNumber.toLowerCase().contains(query));

      final textOk = matchesId || matchesLocation || matchesItem;

      final fromOk = _fromDate == null ||
          !_dateOnly(invoice.createdAt).isBefore(_dateOnly(_fromDate!));

      final toOk = _toDate == null ||
          !_dateOnly(invoice.createdAt).isAfter(_dateOnly(_toDate!));

      return textOk && fromOk && toOk;
    }).toList();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _queryController.clear();
    });
  }

  void _openInvoice(Invoice invoice) {
    pushScreen<void>(
      context,
      (_) => ShowSaleInvoiceScreen(invoiceId: invoice.id),
    );
  }

  bool get _hasFilters =>
      _queryController.text.isNotEmpty ||
      _fromDate != null ||
      _toDate != null;

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Sale Invoices'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildResults(results)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _queryController,
            decoration: InputDecoration(
              labelText: 'Invoice #, location or product',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _queryController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _queryController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _fromDate == null
                        ? 'From date'
                        : _formatDate(_fromDate!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _toDate == null
                        ? 'To date'
                        : _formatDate(_toDate!),
                  ),
                ),
              ),
            ],
          ),
          if (_hasFilters) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(List<Invoice> results) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadInvoices,
      );
    }

    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message:
            'Try adjusting the invoice number, location, product or the date range.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final invoice = results[index];

        return SaleInvoiceTile(
          invoice: invoice,
          onTap: () => _openInvoice(invoice),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}