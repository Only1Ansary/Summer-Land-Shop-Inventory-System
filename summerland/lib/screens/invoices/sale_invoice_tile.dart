import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class SaleInvoiceTile extends StatelessWidget {
  const SaleInvoiceTile({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  final Invoice invoice;
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
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          'Invoice #${invoice.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatDate(invoice.createdAt)} · '
          '${invoice.locationName} · '
          '${invoice.items.length} '
          'item${invoice.items.length == 1 ? '' : 's'}',
        ),
        trailing: Text(
          money(invoice.totalAmount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: amountColor(context, invoice.totalAmount),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}