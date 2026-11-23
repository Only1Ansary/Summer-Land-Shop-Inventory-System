import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/invoice.dart';
import 'package:summerland/screens/invoices/show_sale_invoice_screen.dart';

Invoice _unpaidInvoice() => Invoice(
  id: 1,
  createdAt: DateTime.utc(2026, 11, 23),
  locationId: 1,
  locationName: 'Main store',
  totalAmount: 100,
  paidAmount: 20,
  items: const [],
  customerId: 7,
  customerName: 'Test customer',
  paymentMethod: 0,
);

void main() {
  testWidgets('recording payment dialog opens and cancels without overflow on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final view = tester.view;
    view.physicalSize = const Size(320, 400);
    view.devicePixelRatio = 1.0;

    try {
      // A small viewport mimics the reduced space Android leaves when the
      // keyboard is up. The dialog must scroll instead of overflowing.
      await tester.pumpWidget(
        MaterialApp(home: ShowSaleInvoiceScreen(invoice: _unpaidInvoice())),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Record payment'), findsOneWidget);

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Payment amount'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      view.physicalSize = const Size(800, 600);
      view.devicePixelRatio = 1.0;
    }
  });
}
