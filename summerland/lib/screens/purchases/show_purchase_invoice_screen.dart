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
                subtitle: Text(
                  '${model == null ? '' : '$model\n'}'
                  'Qty: ${item.quantity} × '
                  '${item.unitPurchasePrice.toStringAsFixed(2)}',
                ),
                isThreeLine: model != null,
                trailing: Text(
                  item.totalPrice.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                  subtitle: Text(
                    '${ret.quantity} × '
                    '${ret.unitPurchasePrice.toStringAsFixed(2)}'
                    '${ret.reason.isEmpty ? '' : '\n${ret.reason}'}'
                    '${date == null ? '' : '\n$date'}',
                  ),
                  isThreeLine:
                      ret.reason.isNotEmpty || date != null,
                  trailing: Text(
                    ret.totalPrice.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
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
                  valueStyle: invoice.debt > 0
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppPalette.danger,
                        )
                      : null,
                ),
                InfoTile(
                  label: 'Supplier Total Debt',
                  value: moneyNegative(invoice.supplierTotalDebt),
                  valueStyle: invoice.supplierTotalDebt > 0
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppPalette.danger,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}