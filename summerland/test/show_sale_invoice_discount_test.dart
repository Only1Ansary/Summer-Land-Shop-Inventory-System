import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/invoice.dart';
import 'package:summerland/models/invoice_item.dart';
import 'package:summerland/screens/invoices/show_sale_invoice_screen.dart';

void main() {
  Invoice discountedInvoice() {
    return Invoice(
      id: 14,
      createdAt: DateTime.utc(2026, 10, 8, 12),
      locationId: 1,
      locationName: 'Main store',
      // 240 gross - 24 item discount - 50 invoice discount.
      totalAmount: 166,
      discountAmount: 50,
      items: [
        InvoiceItem(
          productVariantId: 5,
          modelNumber: '100',
          productName: 'T-Shirt',
          quantity: 2,
          unitPrice: 120,
          totalPrice: 216,
          totalBeforeDiscount: 240,
          unitPriceAfterDiscount: 108,
          discountAmount: 12,
          discountPercent: 10,
        ),
      ],
    );
  }

  testWidgets('shows the price before and after the item discount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShowSaleInvoiceScreen(invoice: discountedInvoice())),
    );

    final subtitle = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.textSpan != null);

    expect(
      subtitle.any(
        (text) =>
            text.textSpan!.toPlainText().contains('120.00 EGP → 108.00 EGP'),
      ),
      isTrue,
      reason: 'The unit price before and after the discount must both show.',
    );

    expect(
      subtitle.any(
        (text) =>
            text.textSpan!.toPlainText().contains('-12.00 EGP/unit (10%)'),
      ),
      isTrue,
      reason: 'The per-unit discount must show.',
    );
  });

  testWidgets('totals add up: subtotal, item discounts, invoice discount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShowSaleInvoiceScreen(invoice: discountedInvoice())),
    );

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('240.00 EGP'), findsWidgets);
    expect(find.text('Item discounts'), findsOneWidget);
    expect(find.text('-24.00 EGP'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('-50.00 EGP'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.text('166.00 EGP'), findsOneWidget);
  });

  testWidgets('an invoice discount entered as a percent shows the percent', (
    WidgetTester tester,
  ) async {
    final base = discountedInvoice();

    await tester.pumpWidget(
      MaterialApp(
        home: ShowSaleInvoiceScreen(
          invoice: Invoice(
            id: base.id,
            createdAt: base.createdAt,
            locationId: base.locationId,
            locationName: base.locationName,
            totalAmount: base.totalAmount,
            discountAmount: base.discountAmount,
            discountPercent: 10,
            items: base.items,
          ),
        ),
      ),
    );

    expect(find.text('-50.00 EGP (10%)'), findsOneWidget);
  });

  testWidgets('an invoice without discounts shows no discount rows', (
    WidgetTester tester,
  ) async {
    final invoice = Invoice(
      id: 15,
      createdAt: DateTime.utc(2026, 10, 8, 12),
      locationId: 1,
      locationName: 'Main store',
      totalAmount: 240,
      items: [
        InvoiceItem(
          productVariantId: 5,
          modelNumber: '100',
          productName: 'T-Shirt',
          quantity: 2,
          unitPrice: 120,
          totalPrice: 240,
          totalBeforeDiscount: 240,
          unitPriceAfterDiscount: 120,
          discountAmount: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ShowSaleInvoiceScreen(invoice: invoice)),
    );

    expect(find.text('Item discounts'), findsNothing);
    expect(find.text('Discount'), findsNothing);
    expect(find.text('240.00 EGP'), findsWidgets);
  });
}
