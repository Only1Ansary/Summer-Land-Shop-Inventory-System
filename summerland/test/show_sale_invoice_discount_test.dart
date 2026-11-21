import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/customer_payment.dart';
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

    expect(
      find.text('120.00 EGP'),
      findsWidgets,
      reason: 'The unit price before the discount must show.',
    );
    expect(
      find.text('108.00 EGP'),
      findsWidgets,
      reason: 'The unit price after the discount must show.',
    );
    expect(
      find.text('-12.00 EGP (10%)'),
      findsWidgets,
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
    // "Discount" is both the items-table header and the totals-card row.
    expect(find.text('Discount'), findsWidgets);
    expect(find.text('-50.00 EGP'), findsOneWidget);
    // The headline and the totals card both repeat the amount.
    expect(find.text('Total Amount'), findsWidgets);
    expect(find.text('166.00 EGP'), findsWidgets);
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
    // The items table still has a Discount column header.
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('240.00 EGP'), findsWidgets);
  });

  testWidgets('the employee who made the sale is shown', (
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
            employeeId: 7,
            employeeName: 'Mona',
            totalAmount: base.totalAmount,
            discountAmount: base.discountAmount,
            items: base.items,
          ),
        ),
      ),
    );

    expect(find.text('Mona'), findsOneWidget);
  });

  testWidgets('an invoice with no employee shows None', (
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
            items: base.items,
          ),
        ),
      ),
    );

    expect(find.text('None'), findsWidgets);
  });

  testWidgets('later payments show their own method in the details', (
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
            items: base.items,
            customerId: 4,
            customerPhone: '0123456789',
            customerName: 'Mona',
            customerTotalPaid: 100,
            customerTotalDebt: 66,
            paidAmount: 100,
            remainingAmount: 66,
            payments: [
              CustomerPayment(
                id: 9,
                customerId: 4,
                amount: 100,
                method: 2,
                paidAt: DateTime.utc(2026, 10, 14, 9),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Customer & Payment'), findsOneWidget);
    expect(find.text('Mona'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('InstaPay'), findsNWidgets(2));
    expect(find.text('100.00 EGP'), findsWidgets);
    expect(find.text('Record payment'), findsWidgets);
  });
}
