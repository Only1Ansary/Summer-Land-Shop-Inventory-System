import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../ui/app_widgets.dart';

class ShowSaleInvoiceScreen extends StatefulWidget {
  const ShowSaleInvoiceScreen({
    super.key,
    this.invoice,
    this.invoiceId,
  });

  final Invoice? invoice;
  final int? invoiceId;

  @override
  State<ShowSaleInvoiceScreen> createState() =>
      _ShowSaleInvoiceScreenState();
}

class _ShowSaleInvoiceScreenState
    extends State<ShowSaleInvoiceScreen> {
  final InvoiceService _invoiceService =
      InvoiceService(ApiService());

  Invoice? _invoice;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _invoice = widget.invoice;
    _isLoading = widget.invoice == null;

    if (widget.invoiceId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoice = await _invoiceService.getInvoice(
        widget.invoiceId!,
      );

      if (!mounted) return;

      setState(() {
        _invoice = invoice;
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

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? 'Sale Invoice'
              : 'Sale Invoice #${invoice.id}',
        ),
      ),
      body: _buildBody(invoice),
    );
  }

  Widget _buildBody(Invoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _load,
      );
    }

    if (invoice == null) {
      return const EmptyState(
        title: 'No sale invoice',
      );
    }

    return WideContent(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sale Invoice #${invoice.id}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  InfoTile(
                    label: 'Date',
                    value: '${invoice.createdAt}',
                  ),
                  InfoTile(
                    label: 'Location',
                    value: invoice.locationName,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Items',
            subtitle: 'Products sold on this invoice',
          ),
          const SizedBox(height: 8),
          if (invoice.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.assignment_return_outlined,
                  title: 'Fully returned',
                  message:
                      'Every item on this invoice was returned.',
                ),
              ),
            )
          else
            ...invoice.items.map((item) {
              final variant = [
                if (item.sizeName != null) 'Size: ${item.sizeName}',
                if (item.colourName != null)
                  'Colour: ${item.colourName}',
              ].join(', ');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    '${item.modelNumber}${variant.isEmpty ? '' : ' · $variant'}\n'
                    'Qty: ${item.quantity} × '
                    '${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    item.totalPrice.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: InfoTile(
              label: 'Total Amount',
              value: money(invoice.totalAmount),
            ),
          ),
        ],
      ),
    );
  }
}