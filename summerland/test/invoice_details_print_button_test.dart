import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/invoice.dart';
import 'package:summerland/models/purchase_invoice.dart';
import 'package:summerland/screens/invoices/show_sale_invoice_screen.dart';
import 'package:summerland/screens/purchases/show_purchase_invoice_screen.dart';

Invoice _saleInvoice() => Invoice(
  id: 1,
  createdAt: DateTime.utc(2026, 11, 23),
  locationId: 1,
  locationName: 'Main store',
  totalAmount: 100,
  paidAmount: 100,
  items: const [],
);

PurchaseInvoice _purchaseInvoice() => PurchaseInvoice(
  id: 2,
  supplierId: 3,
  supplierName: 'Acme',
  date: DateTime.utc(2026, 11, 23),
  createdAt: DateTime.utc(2026, 11, 23),
  totalCost: 100,
  totalPaid: 100,
  debt: 0,
  supplierTotalDebt: 0,
  items: const [],
  returns: const [],
);

void main() {
  Future<void> atPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pumpDetail(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  for (final entry in {
    'sale': (WidgetTester tester) =>
        pumpDetail(tester, ShowSaleInvoiceScreen(invoice: _saleInvoice())),
    'purchase': (WidgetTester tester) =>
        pumpDetail(tester, ShowPurchaseInvoiceScreen(invoice: _purchaseInvoice())),
  }.entries) {
    testWidgets('${entry.key} details hide print on Android', (tester) async {
      await atPlatform(TargetPlatform.android, () async {
        await entry.value(tester);

        expect(find.byTooltip('Print'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('${entry.key} details show print on desktop', (tester) async {
      await atPlatform(TargetPlatform.windows, () async {
        await entry.value(tester);

        expect(find.byTooltip('Print'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
