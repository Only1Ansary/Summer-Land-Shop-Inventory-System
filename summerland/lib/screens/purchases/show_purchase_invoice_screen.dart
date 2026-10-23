import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/product.dart';
import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'return_purchase_items_screen.dart';

class ShowPurchaseInvoiceScreen extends StatefulWidget {
  const ShowPurchaseInvoiceScreen({super.key, this.invoice, this.invoiceId});

  final PurchaseInvoice? invoice;
  final int? invoiceId;

  @override
  State<ShowPurchaseInvoiceScreen> createState() =>
      _ShowPurchaseInvoiceScreenState();
}

class _ShowPurchaseInvoiceScreenState extends State<ShowPurchaseInvoiceScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService = PurchaseInvoiceService(
    ApiService(),
  );
  final ProductService _productService = ProductService(ApiService());

  PurchaseInvoice? _invoice;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _invoice = widget.invoice;
    _isLoading = widget.invoice == null;

    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.invoiceId != null) {
        final invoice = await _purchaseInvoiceService.getPurchaseInvoice(
          widget.invoiceId!,
        );

        if (!mounted) return;

        _invoice = invoice;
      } else {
        _invoice = widget.invoice;
      }

      await _enrichItemNames();
    } catch (e) {
      if (!mounted) return;

      if (_invoice != null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error = friendlyErrorMessage(context, e);
        _isLoading = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _enrichItemNames() async {
    final invoice = _invoice;

    if (invoice == null || invoice.items.isEmpty) return;

    try {
      final products = await _productService.getProducts();

      if (!mounted) return;

      final productById = {for (final product in products) product.id: product};

      for (final item in invoice.items) {
        final Product? product = productById[item.productId];

        item.productName = product?.name;
        item.modelNumber = product?.modelNumber;
      }

      setState(() {});
    } catch (e) {
      // Product lookup is best-effort; item rows still show prices.
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _load();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? context.tr('Purchase Invoice')
              : context.tr('Purchase Invoice #{0}', [invoice.id]),
        ),
        actions: [
          if (invoice != null && invoice.items.isNotEmpty)
            IconButton(
              tooltip: context.tr('Return Items'),
              icon: const Icon(Icons.assignment_return_outlined),
              onPressed: _openReturnScreen,
            ),
          if (invoice != null && invoice.debt > 0)
            IconButton(
              tooltip: context.tr('Pay Debt'),
              icon: const Icon(Icons.payments_outlined),
              onPressed: _payDebt,
            ),
        ],
      ),
      body: _buildBody(invoice),
    );
  }

  Future<void> _openReturnScreen() async {
    if (!ensureOnlineForWrite(context)) return;

    final invoice = _invoice;

    if (invoice == null) return;

    final returned = await pushScreen<bool>(
      context,
      (_) => ReturnPurchaseItemsScreen(invoice: invoice),
    );

    if (returned == true && mounted) {
      _retry();
    }
  }

  Future<void> _payDebt() async {
    if (!ensureOnlineForWrite(context)) return;

    final invoice = _invoice;

    if (invoice == null || invoice.debt <= 0) return;

    final remaining = invoice.debt;
    final controller = TextEditingController(
      text: remaining.toStringAsFixed(2),
    );

    final amountText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Pay Debt')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('Amount'),
            prefixText: '\u20a6 ',
            helperText: context.tr('Remaining debt: {0}', [money(remaining)]),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(context.tr('Pay')),
          ),
        ],
      ),
    );

    controller.dispose();

    if (amountText == null || !mounted) return;

    final amount = double.tryParse(amountText.trim());

    if (amount == null || amount <= 0) {
      _showMessage(context.tr('Enter a valid payment amount.'));
      return;
    }

    if (amount > remaining) {
      _showMessage(
        context.tr('Payment cannot exceed the remaining debt of {0}.', [
          money(remaining),
        ]),
      );
      return;
    }

    try {
      await _purchaseInvoiceService.payDebt(
        invoiceId: invoice.id,
        amount: amount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Debt payment recorded.'))),
      );

      _retry();
    } catch (e) {
      if (!mounted) return;

      _showMessage(friendlyErrorMessage(context, e));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildBody(PurchaseInvoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _retry);
    }

    if (invoice == null) {
      return EmptyState(title: context.tr('No purchase invoice'));
    }

    final date = invoice.date ?? invoice.createdAt;

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
                    context.tr('Purchase Invoice #{0}', [invoice.id]),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  InfoTile(
                    label: context.tr('Supplier'),
                    value: invoice.supplierName,
                  ),
                  InfoTile(label: context.tr('Date'), value: '$date'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (invoice.items.isNotEmpty) ...[
            SectionHeader(
              title: context.tr('Items'),
              subtitle: context.tr('Products received on this purchase'),
            ),
            const SizedBox(height: 8),
            ...invoice.items.map((item) {
              final displayName =
                  item.productName ??
                  context.tr('Product #{0}', [item.productId]);
              final model = item.modelNumber;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(displayName),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${model == null ? '' : '$model\n'}'
                              '${context.tr('Qty: ')}',
                        ),
                        TextSpan(text: '${item.quantity}'),
                        const TextSpan(text: ' × '),
                        TextSpan(
                          text: money(item.unitPurchasePrice),
                          style: TextStyle(
                            color: amountColor(context, item.unitPurchasePrice),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isThreeLine: model != null,
                  trailing: Text(
                    money(item.totalPrice),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor(context, item.totalPrice),
                    ),
                  ),
                ),
              );
            }),
          ],
          if (invoice.returns.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              title: context.tr('Returns'),
              subtitle: context.tr('Items returned against this purchase'),
            ),
            const SizedBox(height: 8),
            ...invoice.returns.map((ret) {
              final date = ret.createdAt;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    ret.productName.isEmpty
                        ? context.tr('Product #{0}', [ret.productId])
                        : ret.productName,
                  ),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${ret.quantity} × '),
                        TextSpan(
                          text: money(ret.unitPurchasePrice),
                          style: TextStyle(
                            color: amountColor(context, ret.unitPurchasePrice),
                          ),
                        ),
                        if (ret.reason.isNotEmpty)
                          TextSpan(text: '\n${ret.reason}'),
                        if (date != null) TextSpan(text: '\n$date'),
                      ],
                    ),
                  ),
                  isThreeLine: ret.reason.isNotEmpty || date != null,
                  trailing: Text(
                    money(ret.totalPrice),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor(context, ret.totalPrice),
                    ),
                  ),
                ),
              );
            }),
          ],
          if (invoice.fees.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(
              title: context.tr('Extra Fees'),
              subtitle: context.tr(
                'Paid fees add to the total cost; unpaid fees add to debt',
              ),
            ),
            const SizedBox(height: 4),
            ...invoice.fees.map(
              (fee) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    fee.isPaid
                        ? Icons.check_circle_outline
                        : Icons.local_shipping_outlined,
                    color: fee.isPaid
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(fee.description),
                  subtitle: Text(
                    fee.isPaid
                        ? context.tr('Paid (total cost)')
                        : context.tr('Unpaid (debt)'),
                  ),
                  trailing: Text(
                    money(fee.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: amountColor(context, fee.amount),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
                  label: context.tr('Total Cost'),
                  value: money(invoice.totalCost),
                ),
                InfoTile(
                  label: context.tr('Total Paid'),
                  value: money(invoice.totalPaid),
                ),
                InfoTile(
                  label: context.tr('Debt'),
                  value: moneyNegative(invoice.debt),
                  valueStyle: amountStyle(context, -invoice.debt),
                ),
                InfoTile(
                  label: context.tr('Supplier Total Debt'),
                  value: moneyNegative(invoice.supplierTotalDebt),
                  valueStyle: amountStyle(context, -invoice.supplierTotalDebt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
