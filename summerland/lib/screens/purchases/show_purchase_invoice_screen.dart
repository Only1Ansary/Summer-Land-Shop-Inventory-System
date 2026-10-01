import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'return_purchase_items_screen.dart';

class ShowPurchaseInvoiceScreen extends StatefulWidget {
  const ShowPurchaseInvoiceScreen({
    super.key,
    this.invoice,
    this.invoiceId,
  });

  final PurchaseInvoice? invoice;
  final int? invoiceId;

  @override
  State<ShowPurchaseInvoiceScreen> createState() =>
      _ShowPurchaseInvoiceScreenState();
}

class _ShowPurchaseInvoiceScreenState
    extends State<ShowPurchaseInvoiceScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService =
      PurchaseInvoiceService(ApiService());
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

      setState(() {
        _error = e.toString();
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

      final productById = {
        for (final product in products) product.id: product,
      };

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
              ? 'Purchase Invoice'
              : 'Purchase Invoice #${invoice.id}',
        ),
        actions: [
          if (invoice != null && invoice.items.isNotEmpty)
            IconButton(
              tooltip: 'Return Items',
              icon: const Icon(Icons.assignment_return_outlined),
              onPressed: _openReturnScreen,
            ),
          if (invoice != null && invoice.debt > 0)
            IconButton(
              tooltip: 'Pay Debt',
              icon: const Icon(Icons.payments_outlined),
              onPressed: _payDebt,
            ),
        ],
      ),
      body: _buildBody(invoice),
    );
  }

  Future<void> _openReturnScreen() async {
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
    final invoice = _invoice;

    if (invoice == null || invoice.debt <= 0) return;

    final remaining = invoice.debt;
    final controller = TextEditingController(
      text: remaining.toStringAsFixed(2),
    );

    final amountText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay Debt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '\u20a6 ',
            helperText: 'Remaining debt: ${money(remaining)}',
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Pay'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (amountText == null || !mounted) return;

    final amount = double.tryParse(amountText.trim());

    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    if (amount > remaining) {
      _showMessage(
        'Payment cannot exceed the remaining debt of '
        '${money(remaining)}.',
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
        const SnackBar(
          content: Text('Debt payment recorded.'),
        ),
      );

      _retry();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildBody(PurchaseInvoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _retry,
      );
    }

    if (invoice == null) {
      return const EmptyState(
        title: 'No purchase invoice',
      );
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
                    'Purchase Invoice #${invoice.id}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  InfoTile(
                    label: 'Supplier',
                    value: invoice.supplierName,
                  ),
                  InfoTile(
                    label: 'Date',
                    value: '$date',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Items',
            subtitle: 'Products received on this purchase',
          ),
          const SizedBox(height: 8),
          ...invoice.items.map((item) {
            final displayName = item.productName ?? 'Product #${item.productId}';
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
                            '${model == null ? '' : '$model\n'}Qty: ',
                      ),
                      TextSpan(
                        text: '${item.quantity}',
                      ),
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
          if (invoice.returns.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Returns',
              subtitle: 'Items returned against this purchase',
            ),
            const SizedBox(height: 8),
            ...invoice.returns.map((ret) {
              final date = ret.createdAt;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    ret.productName.isEmpty
                        ? 'Product #${ret.productId}'
                        : ret.productName,
                  ),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${ret.quantity} × ',
                        ),
                        TextSpan(
                          text: money(ret.unitPurchasePrice),
                          style: TextStyle(
                            color: amountColor(
                              context,
                              ret.unitPurchasePrice,
                            ),
                          ),
                        ),
                        if (ret.reason.isNotEmpty)
                          TextSpan(text: '\n${ret.reason}'),
                        if (date != null) TextSpan(text: '\n$date'),
                      ],
                    ),
                  ),
                  isThreeLine:
                      ret.reason.isNotEmpty || date != null,
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
            const SectionHeader(
              title: 'Extra Fees',
              subtitle: 'Shipping and other charges, not owed to the supplier',
            ),
            const SizedBox(height: 4),
            ...invoice.fees.map(
              (fee) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.local_shipping_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(fee.description),
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
                  label: 'Total Cost',
                  value: money(invoice.totalCost),
                ),
                InfoTile(
                  label: 'Total Paid',
                  value: money(invoice.totalPaid),
                ),
                InfoTile(
                  label: 'Debt',
                  value: moneyNegative(invoice.debt),
                  valueStyle: amountStyle(context, -invoice.debt),
                ),
                InfoTile(
                  label: 'Supplier Total Debt',
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