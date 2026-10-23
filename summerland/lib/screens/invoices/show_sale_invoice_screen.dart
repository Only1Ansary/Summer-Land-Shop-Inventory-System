import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
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
        if (_invoice != null) {
          _isLoading = false;
        } else {
          _error = friendlyErrorMessage(context, e);
        }
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
              ? context.tr('Sale Invoice')
              : context.tr('Sale Invoice #{0}', [invoice.id]),
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
      return EmptyState(title: context.tr('No sale invoice'));
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
                    context.tr('Sale Invoice #{0}', [invoice.id]),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  InfoTile(
                    label: context.tr('Date'),
                    value: '${invoice.createdAt}',
                  ),
                  InfoTile(
                    label: context.tr('Location'),
                    value: invoice.locationName,
                  ),
                  InfoTile(
                    label: context.tr('Employee'),
                    value: invoice.employeeName ?? context.tr('None'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: context.tr('Items'),
            subtitle: context.tr('Products sold on this invoice'),
          ),
          const SizedBox(height: 8),
          if (invoice.items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.assignment_return_outlined,
                  title: context.tr('Fully returned'),
                  message: context.tr(
                    'Every item on this invoice was returned.',
                  ),
                ),
              ),
            )
          else
            ...invoice.items.map((item) {
              final variant = [
                if (item.sizeName != null)
                  context.tr('Size: {0}', [item.sizeName]),
                if (item.colourName != null)
                  context.tr('Colour: {0}', [item.colourName]),
              ].join(', ');

              final discountLabel = item.discountPercent == null
                  ? context.tr('-{0}/unit', [money(item.discountAmount)])
                  : context.tr('-{0}/unit ({1})', [
                      money(item.discountAmount),
                      percentLabel(item.discountPercent!),
                    ]);

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
                              '${context.tr('Qty: ')}',
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
                            text: context.tr('\nDiscount: {0}', [
                              discountLabel,
                            ]),
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
                InfoTile(
                  label: context.tr('Subtotal'),
                  value: money(_subtotal(invoice)),
                ),
                if (_itemDiscountTotal(invoice) > 0)
                  InfoTile(
                    label: context.tr('Item discounts'),
                    value: moneyNegative(_itemDiscountTotal(invoice)),
                    valueStyle: amountStyle(
                      context,
                      -_itemDiscountTotal(invoice),
                    ),
                  ),
                if (invoice.discountAmount > 0)
                  InfoTile(
                    label: context.tr('Discount'),
                    value: invoice.discountPercent == null
                        ? moneyNegative(invoice.discountAmount)
                        : '${moneyNegative(invoice.discountAmount)} '
                              '(${percentLabel(invoice.discountPercent!)})',
                    valueStyle: amountStyle(context, -invoice.discountAmount),
                  ),
                InfoTile(
                  label: context.tr('Total Amount'),
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
