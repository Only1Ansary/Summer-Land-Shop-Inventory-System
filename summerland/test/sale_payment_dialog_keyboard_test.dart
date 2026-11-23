import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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

Future<TestFlutterView> _openDialog(WidgetTester tester) async {
  final view = tester.view;
  view.physicalSize = const Size(320, 480);
  view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(home: ShowSaleInvoiceScreen(invoice: _unpaidInvoice())),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Record payment'));
  await tester.pumpAndSettle();

  expect(find.byType(AlertDialog), findsOneWidget);
  return view;
}

void main() {
  Future<void> inAndroidView(
    WidgetTester tester,
    Future<void> Function(TestFlutterView view) body,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final view = await _openDialog(tester);
      await body(view);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
      tester.view.resetDevicePixelRatio();
    }
  }

  testWidgets('cancel with the keyboard open does not overflow', (tester) async {
    await inAndroidView(tester, (view) async {
      // A tall on-screen keyboard leaves very little room for the dialog.
      view.viewInsets = FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('back with the keyboard open does not overflow', (tester) async {
    await inAndroidView(tester, (view) async {
      view.viewInsets = FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
