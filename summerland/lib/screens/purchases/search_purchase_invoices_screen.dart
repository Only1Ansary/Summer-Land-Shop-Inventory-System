import 'package:flutter/material.dart';

import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_widgets.dart';
import 'purchase_invoice_tile.dart';
import 'show_purchase_invoice_screen.dart';

class SearchPurchaseInvoicesScreen extends StatefulWidget {
  const SearchPurchaseInvoicesScreen({super.key});

  @override
  State<SearchPurchaseInvoicesScreen> createState() =>
      _SearchPurchaseInvoicesScreenState();
}

class _SearchPurchaseInvoicesScreenState
    extends State<SearchPurchaseInvoicesScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService = PurchaseInvoiceService(
    ApiService(),
  );

  final TextEditingController _nameController = TextEditingController();

  List<PurchaseInvoice> _invoices = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromDate = defaultFilterFromDate();
    _toDate = defaultFilterToDate();
    _loadInvoices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  List<PurchaseInvoice> get _results {
    final query = _nameController.text.trim().toLowerCase();

    return _invoices.where((invoice) {
      final nameOk =
          query.isEmpty || invoice.supplierName.toLowerCase().contains(query);

      final date = invoice.date ?? invoice.createdAt;

      final fromOk =
          _fromDate == null || !_dateOnly(date).isBefore(_dateOnly(_fromDate!));

      final toOk =
          _toDate == null || !_dateOnly(date).isAfter(_dateOnly(_toDate!));

      return nameOk && fromOk && toOk;
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
      _fromDate = defaultFilterFromDate();
      _toDate = defaultFilterToDate();
      _nameController.clear();
    });
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

  bool get _hasFilters => _nameController.text.isNotEmpty || !_datesAreDefault;

  bool get _datesAreDefault =>
      _sameDay(_fromDate, defaultFilterFromDate()) &&
      _sameDay(_toDate, defaultFilterToDate());

  bool _sameDay(DateTime? value, DateTime other) {
    if (value == null) return false;

    return value.year == other.year &&
        value.month == other.month &&
        value.day == other.day;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Invoices')),
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
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Supplier name',
              prefixIcon: const Icon(Icons.factory_outlined),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear name',
                      onPressed: () {
                        _nameController.clear();
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
                    _fromDate == null ? 'From date' : _formatDate(_fromDate!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _toDate == null ? 'To date' : _formatDate(_toDate!),
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

  Widget _buildResults(List<PurchaseInvoice> results) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadInvoices);
    }

    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try adjusting the supplier name or the date range.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final invoice = results[index];

        return PurchaseInvoiceTile(
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
