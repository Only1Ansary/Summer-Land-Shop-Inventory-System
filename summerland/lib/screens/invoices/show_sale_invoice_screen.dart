import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class ShowSaleInvoiceScreen extends StatefulWidget {
  const ShowSaleInvoiceScreen({super.key, this.invoice, this.invoiceId});

  final Invoice? invoice;
  final int? invoiceId;

  @override
  State<ShowSaleInvoiceScreen> createState() => _ShowSaleInvoiceScreenState();
}

class _ShowSaleInvoiceScreenState extends State<ShowSaleInvoiceScreen> {
  final InvoiceService _invoiceService = InvoiceService(ApiService());

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
      final invoice = await _invoiceService.getInvoice(widget.invoiceId!);

      if (!mounted) return;

      setState(() {
        _invoice = invoice;
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

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null ? 'Sale Invoice' : 'Sale Invoice #${invoice.id}',
        ),
      ),
      body: _buildBody(invoice),
    );
  }

  double _itemDiscountTotal(Invoice invoice) {
    return invoice.items.fold<double>(
      0,
      (total, item) => total + item.discountAmount * item.quantity,
    );
  }

  // The items total before any discount: everything still payable on the
  // invoice plus every discount that is still carried by its lines.
  double _subtotal(Invoice invoice) {
    return invoice.totalAmount +
        invoice.discountAmount +
        _itemDiscountTotal(invoice);
  }

  Widget _buildBody(Invoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (invoice == null) {
      return const EmptyState(title: 'No sale invoice');
    }

    final theme = Theme.of(context);

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
                  InfoTile(label: 'Date', value: '${invoice.createdAt}'),
                  InfoTile(label: 'Location', value: invoice.locationName),
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
                  message: 'Every item on this invoice was returned.',
                ),
              ),
            )
          else
            ...invoice.items.map((item) {
              final variant = [
                if (item.sizeName != null) 'Size: ${item.sizeName}',
                if (item.colourName != null) 'Colour: ${item.colourName}',
              ].join(', ');

              final discountLabel = item.discountPercent == null
                  ? '-${money(item.discountAmount)}/unit'
                  : '-${money(item.discountAmount)}/unit '
                        '(${percentLabel(item.discountPercent!)})';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${item.modelNumber}${variant.isEmpty ? '' : ' · $variant'}\n'
                              'Qty: ',
                        ),
                        TextSpan(text: '${item.quantity}'),
                        const TextSpan(text: ' × '),
                        if (!item.hasDiscount)
                          TextSpan(
                            text: money(item.unitPrice),
                            style: TextStyle(
                              color: amountColor(context, item.unitPrice),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else ...[
                          TextSpan(
                            text: money(item.unitPrice),
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          TextSpan(
                            text: ' → ${money(item.unitPriceAfterDiscount)}',
                            style: TextStyle(
                              color: amountColor(
                                context,
                                item.unitPriceAfterDiscount,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '\nDiscount: $discountLabel',
                            style: TextStyle(
                              color: amountColor(context, -item.discountAmount),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: item.hasDiscount
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(item.totalBeforeDiscount),
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            Text(
                              money(item.totalPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColor(context, item.totalPrice),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          money(item.totalPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: amountColor(context, item.totalPrice),
                          ),
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
            child: Column(
              children: [
                InfoTile(label: 'Subtotal', value: money(_subtotal(invoice))),
                if (_itemDiscountTotal(invoice) > 0)
                  InfoTile(
                    label: 'Item discounts',
                    value: moneyNegative(_itemDiscountTotal(invoice)),
                    valueStyle: amountStyle(
                      context,
                      -_itemDiscountTotal(invoice),
                    ),
                  ),
                if (invoice.discountAmount > 0)
                  InfoTile(
                    label: 'Discount',
                    value: invoice.discountPercent == null
                        ? moneyNegative(invoice.discountAmount)
                        : '${moneyNegative(invoice.discountAmount)} '
                              '(${percentLabel(invoice.discountPercent!)})',
                    valueStyle: amountStyle(context, -invoice.discountAmount),
                  ),
                InfoTile(
                  label: 'Total Amount',
                  value: money(invoice.totalAmount),
                  valueStyle: amountStyle(context, invoice.totalAmount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
