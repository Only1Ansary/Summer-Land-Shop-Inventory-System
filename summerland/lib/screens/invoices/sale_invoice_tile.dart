import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          context.tr('Invoice #{0}', [invoice.id]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          context.tr('{0} · {1} · {2} · {3} item{4}', [
            _formatDate(invoice.createdAt),
            invoice.locationName,
            invoice.employeeName ?? context.tr('None'),
            invoice.items.length,
            invoice.items.length == 1 ? '' : 's',
          ]),
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
