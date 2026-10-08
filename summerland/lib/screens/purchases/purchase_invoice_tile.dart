import 'package:flutter/material.dart';

import '../../models/purchase_invoice.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class PurchaseInvoiceTile extends StatelessWidget {
  const PurchaseInvoiceTile({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  final PurchaseInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          invoice.supplierName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${_formatDate(invoice.date)} · '
                    '${invoice.items.length} '
                    'item${invoice.items.length == 1 ? '' : 's'} · ',
              ),
              TextSpan(
                text: money(invoice.totalCost),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        trailing: Text(
          moneyNegative(invoice.debt),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: amountColor(context, -invoice.debt),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return '${date.day}/${date.month}/${date.year}';
  }
}
