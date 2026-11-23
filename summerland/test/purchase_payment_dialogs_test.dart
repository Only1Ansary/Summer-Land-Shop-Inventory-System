import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/models/purchase_invoice.dart';
import 'package:summerland/screens/purchases/show_purchase_invoice_screen.dart';
import 'package:summerland/screens/purchases/show_suppliers_screen.dart';
import 'package:summerland/services/api_service.dart';

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = <http.Request>[];
    ApiService.clientOverride = MockClient((request) async {
      requests.add(request);

      if (request.url.path == '/api/Supplier' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 3,
              'supplierName': 'Acme',
              'debt': 600,
              'purchaseInvoices': [],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> chooseMethod(
    WidgetTester tester,
    Key dropdownKey,
    String label,
  ) async {
    await tester.tap(find.byKey(dropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> payRequest(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    final request = requests.singleWhere(
      (r) => r.url.path.endsWith('/pay') && r.method == 'POST',
    );

    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  testWidgets('supplier debt payment dialog sends the chosen method', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ShowSuppliersScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pay debt'));
    await tester.pumpAndSettle();

    expect(
      find.text('Applied to the oldest unpaid invoices first.'),
      findsOneWidget,
    );

    await chooseMethod(
      tester,
      const ValueKey('supplier-payment-method'),
      'Visa',
    );

    final body = await payRequest(tester);
    expect(body['method'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('per-invoice purchase payment dialog sends the chosen method', (
    tester,
  ) async {
    final invoice = PurchaseInvoice(
      id: 7,
      supplierId: 3,
      supplierName: 'Acme',
      date: DateTime.utc(2026, 11, 23),
      createdAt: DateTime.utc(2026, 11, 23),
      totalCost: 1000,
      totalPaid: 400,
      debt: 600,
      supplierTotalDebt: 600,
      paymentMethod: 0,
      items: const [],
      returns: const [],
    );

    await tester.pumpWidget(
      MaterialApp(home: ShowPurchaseInvoiceScreen(invoice: invoice)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);

    await tester.tap(find.byTooltip('Pay Debt'));
    await tester.pumpAndSettle();

    await chooseMethod(
      tester,
      const ValueKey('purchase-payment-method'),
      'VCash',
    );

    final body = await payRequest(tester);
    expect(body['method'], 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplier payment dialog cancels with the keyboard open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    try {
      await tester.pumpWidget(const MaterialApp(home: ShowSuppliersScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pay debt'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('invoice payment dialog cancels with the keyboard open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final invoice = PurchaseInvoice(
      id: 7,
      supplierId: 3,
      supplierName: 'Acme',
      date: DateTime.utc(2026, 11, 23),
      createdAt: DateTime.utc(2026, 11, 23),
      totalCost: 1000,
      totalPaid: 400,
      debt: 600,
      supplierTotalDebt: 600,
      paymentMethod: 0,
      items: const [],
      returns: const [],
    );

    try {
      await tester.pumpWidget(
        MaterialApp(home: ShowPurchaseInvoiceScreen(invoice: invoice)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pay Debt'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
