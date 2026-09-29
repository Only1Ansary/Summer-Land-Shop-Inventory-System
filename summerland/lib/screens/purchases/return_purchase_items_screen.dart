import 'package:flutter/material.dart';

import '../../models/purchase_invoice.dart';
import '../../models/purchase_invoice_item.dart';
import '../../services/api_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class ReturnPurchaseItemsScreen extends StatefulWidget {
  const ReturnPurchaseItemsScreen({super.key, required this.invoice});

  final PurchaseInvoice invoice;

  @override
  State<ReturnPurchaseItemsScreen> createState() =>
      _ReturnPurchaseItemsScreenState();
}

class _ReturnPurchaseItemsScreenState
    extends State<ReturnPurchaseItemsScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService =
      PurchaseInvoiceService(ApiService());

  final Map<int, int> _quantities = {};
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  PurchaseInvoice get _invoice => widget.invoice;

  int _returnQuantityFor(PurchaseInvoiceItem item) {
    return _quantities[item.productId] ?? 0;
  }

  void _setQuantity(PurchaseInvoiceItem item, int value) {
    setState(() {
      _quantities[item.productId] = value.clamp(0, item.quantity);
    });
  }

  int get _returnedCount {
    return _quantities.values.fold(0, (total, qty) => total + qty);
  }

  double get _returnedValue {
    var total = 0.0;

    for (final item in _invoice.items) {
      final qty = _returnQuantityFor(item);

      if (qty > 0) {
        total += item.unitPurchasePrice * qty;
      }
    }

    return total;
  }

  void _changeQuantity(PurchaseInvoiceItem item, int delta) {
    _setQuantity(item, _returnQuantityFor(item) + delta);
  }

  Future<void> _submit() async {
    if (_returnedCount <= 0) {
      _showError('Choose at least one item to return.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final items = _invoice.items
          .where((item) => _returnQuantityFor(item) > 0)
          .map((item) {
            return {
              'productId': item.productId,
              'quantity': _returnQuantityFor(item),
            };
          })
          .toList();

      await _purchaseInvoiceService.createPurchaseReturn(
        invoiceId: _invoice.id,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        items: items,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Items'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Return / Credit',
                          subtitle:
                              'Value is applied to unpaid debt first, '
                              'then to the invoice total cost.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Return Reason',
                            prefixIcon: Icon(Icons.notes_outlined),
                            helperText: 'Optional, e.g. damaged goods.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._invoice.items.map((item) {
                  final qty = _returnQuantityFor(item);
                  final displayName = item.productName ??
                      'Product #${item.productId}';
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
                                  'Purchased: ',
                            ),
                            TextSpan(
                              text: '${item.quantity}',
                            ),
                            const TextSpan(text: ' × '),
                            TextSpan(
                              text:
                                  money(item.unitPurchasePrice),
                              style: TextStyle(
                                color: amountColor(
                                  context,
                                  item.unitPurchasePrice,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      isThreeLine: model != null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Return one',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty <= 0
                                ? null
                                : () => _changeQuantity(item, -1),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: qty > 0
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Return one more',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: qty >= item.quantity
                                ? null
                                : () => _changeQuantity(item, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_returnedCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Returning: $_returnedCount',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Credit: ${money(_returnedValue)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: amountColor(context, _returnedValue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_return_outlined),
                      label: const Text('Create Return'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}