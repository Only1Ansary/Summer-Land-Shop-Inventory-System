import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/screens/invoices/create_invoice_screen.dart';
import 'package:summerland/services/api_service.dart';

const MethodChannel _notificationChannel = MethodChannel(
  'summerland/low_stock_notifications',
);

const _locations = [
  {'id': 1, 'name': 'Main Branch'},
];

const _employees = [
  {
    'id': 1,
    'name': 'Ahmed Mohamed',
    'salary': 4000,
    'target': 20000,
    'bonus': 500,
    'bonusType': 0,
    'achievedTarget': false,
    'totalSales': 0,
  },
];

const _variant = {
  'id': 1,
  'productId': 1,
  'modelNumber': 'MOD-2024-00117',
  'productName': 'Summerland Cotton T-Shirt',
  'sizeId': 1,
  'sizeName': 'L',
  'colourId': 1,
  'colourName': 'Navy Blue',
  'barcodeType': 0,
  'barcode': '6201100117017',
  'price': 100.0,
  'lowStockThreshold': 2,
  'totalQuantity': 10,
  'isLowStock': false,
};

Map<String, dynamic>? _capturedInvoice;

http.Client _fakeBackend() {
  return MockClient((request) async {
    final path = request.url.path;

    Object body;

    if (request.method == 'POST' && path == '/api/SaleInvoices') {
      _capturedInvoice = jsonDecode(request.body) as Map<String, dynamic>;
      body = {
        'id': 55,
        'createdAt': '2026-11-01T10:00:00',
        'locationId': 1,
        'locationName': 'Main Branch',
        'employeeId': 1,
        'employeeName': 'Ahmed Mohamed',
        'totalAmount': _capturedInvoice!['paidAmount'],
        'discountAmount': 0.0,
        'items': <Object>[],
      };
    } else if (path == '/api/Locations') {
      body = _locations;
    } else if (path == '/api/ProductVariants') {
      body = [_variant];
    } else if (path == '/api/Employees') {
      body = _employees;
    } else if (path.startsWith('/api/Inventory/variant/')) {
      body = [
        {
          'id': 1,
          'productVariantId': 1,
          'locationId': 1,
          'locationName': 'Main Branch',
          'quantity': 10,
        },
      ];
    } else {
      body = <Object>[];
    }

    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

Future<void> _openCartWithOneItem(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: CreateInvoiceScreen()));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'MOD-2024');
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Summerland Cotton T-Shirt').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<int>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Main Branch (').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Items: 1'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('cashier-location-null')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Main Branch').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('invoice-employee-null')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ahmed Mohamed').last);
  await tester.pumpAndSettle();
}

FilledButton _createButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create Invoice'),
    );

Future<void> _createInvoice(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create Invoice'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _capturedInvoice = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, (call) async => null);
    ApiService.clientOverride = _fakeBackend();
  });

  tearDown(() {
    ApiService.clientOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, null);
  });

  testWidgets('allows a fully paid sale without a phone', (tester) async {
    await _openCartWithOneItem(tester);

    await tester.enterText(
      find.byKey(const Key('invoice-paid-amount')),
      '100',
    );
    await tester.pumpAndSettle();

    expect(_createButton(tester).enabled, isTrue);
    expect(
      find.text(
        'Enter the customer phone number for an unpaid or partially paid invoice.',
      ),
      findsNothing,
    );

    await _createInvoice(tester);

    expect(_capturedInvoice, isNotNull);
    expect(_capturedInvoice!['customerPhone'], '');
    expect(_capturedInvoice!['paidAmount'], 100.0);
  });

  testWidgets('requires a phone for a partial or zero payment', (
    tester,
  ) async {
    await _openCartWithOneItem(tester);
    await tester.enterText(find.byKey(const Key('invoice-paid-amount')), '40');
    await tester.pumpAndSettle();

    expect(_createButton(tester).enabled, isFalse);
    expect(
      find.text(
        'Enter the customer phone number for an unpaid or partially paid invoice.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('invoice-paid-amount')), '0');
    await tester.pumpAndSettle();
    expect(_createButton(tester).enabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('invoice-customer-phone')),
      '0123456789',
    );
    await tester.pumpAndSettle();
    expect(_createButton(tester).enabled, isTrue);

    await _createInvoice(tester);

    expect(_capturedInvoice, isNotNull);
    expect(_capturedInvoice!['customerPhone'], '0123456789');
    expect(_capturedInvoice!['paidAmount'], 0.0);
  });

  testWidgets('rejects an invalid phone even when fully paid', (
    tester,
  ) async {
    await _openCartWithOneItem(tester);
    await tester.enterText(find.byKey(const Key('invoice-paid-amount')), '100');
    await tester.enterText(
      find.byKey(const Key('invoice-customer-phone')),
      'abc',
    );
    await tester.pumpAndSettle();

    expect(_createButton(tester).enabled, isFalse);
    expect(find.text('Enter at least 3 digits.'), findsWidgets);
  });
}
