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

Map<String, Object?> _variant({
  required int totalQuantity,
  required bool isLowStock,
}) {
  return {
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
    'price': 1234.5,
    'lowStockThreshold': 2,
    'totalQuantity': totalQuantity,
    'isLowStock': isLowStock,
  };
}

late bool _saleCreated;
late List<Map<String, Object?>> _variantsBefore;
late List<Map<String, Object?>> _variantsAfter;
late List<MethodCall> _notificationCalls;

http.Client _fakeBackend() {
  return MockClient((request) async {
    final String path = request.url.path;

    Object body;

    if (request.method == 'POST' && path == '/api/SaleInvoices') {
      _saleCreated = true;
      body = {
        'id': 55,
        'createdAt': '2026-11-01T10:00:00',
        'locationId': 1,
        'locationName': 'Main Branch',
        'employeeId': 1,
        'employeeName': 'Ahmed Mohamed',
        'totalAmount': 1234.5,
        'discountAmount': 0.0,
        'items': <Object>[],
      };
    } else if (path == '/api/Locations') {
      body = _locations;
    } else if (path == '/api/ProductVariants') {
      body = _saleCreated ? _variantsAfter : _variantsBefore;
    } else if (path == '/api/Employees') {
      body = _employees;
    } else if (path.startsWith('/api/Inventory/variant/')) {
      final stock = _variantsBefore.single['totalQuantity'];
      body = [
        {
          'id': 1,
          'productVariantId': 1,
          'locationId': 1,
          'locationName': 'Main Branch',
          'quantity': stock,
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

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: CreateInvoiceScreen()));
  await tester.pumpAndSettle();
}

/// Adds one unit to the cart and fills the cashier/employee fields.
Future<void> _buildOneItemCart(WidgetTester tester) async {
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

  expect(find.text('Items: 1'), findsOneWidget);

  await tester.tap(find.text('Items: 1'));
  await tester.pumpAndSettle();

  final dropdowns = find.byType(DropdownButtonFormField<int>);
  expect(dropdowns, findsNWidgets(2));

  await tester.tap(dropdowns.at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Main Branch').last);
  await tester.pumpAndSettle();

  await tester.tap(dropdowns.at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ahmed Mohamed').last);
  await tester.pumpAndSettle();
}

Future<void> _createInvoice(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create Invoice'));
  await tester.pump();

  // Let the undo window close and the invoice be committed.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _saleCreated = false;
    _variantsBefore = [_variant(totalQuantity: 3, isLowStock: false)];
    _variantsAfter = [_variant(totalQuantity: 2, isLowStock: true)];

    _notificationCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, (call) async {
          _notificationCalls.add(call);
          return null;
        });

    ApiService.clientOverride = _fakeBackend();
  });

  tearDown(() {
    ApiService.clientOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, null);
  });

  testWidgets('notifies when a sale pushes a product into low stock', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _buildOneItemCart(tester);
    await _createInvoice(tester);

    final alerts = _notificationCalls
        .where((call) => call.method == 'showLowStock')
        .toList();

    expect(alerts, hasLength(1));
    expect(alerts.single.arguments, {
      'id': 1,
      'title': 'Low stock alert',
      'body':
          'Summerland Cotton T-Shirt (MOD-2024-00117) is low on stock: '
          '2 left.',
    });

    // The background checker is asked to verify even if the app is closed,
    // and is told this variant is already known so it does not re-alert.
    expect(
      _notificationCalls.where((call) => call.method == 'scheduleCheck'),
      isNotEmpty,
    );
    expect(
      _notificationCalls
          .where((call) => call.method == 'rememberLowStock')
          .last
          .arguments,
      {
        'ids': [1],
      },
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the screen leaves the background baseline alone', (
    tester,
  ) async {
    await _pumpScreen(tester);

    // Loading the screen must not mark existing low stock as "already
    // notified", otherwise a sale made on another device while this one was
    // closed would never produce its background alert.
    expect(
      _notificationCalls.where((call) => call.method == 'rememberLowStock'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not notify while stock stays above the threshold', (
    tester,
  ) async {
    _variantsBefore = [_variant(totalQuantity: 10, isLowStock: false)];
    _variantsAfter = [_variant(totalQuantity: 9, isLowStock: false)];

    await _pumpScreen(tester);
    await _buildOneItemCart(tester);
    await _createInvoice(tester);

    expect(
      _notificationCalls.where((call) => call.method == 'showLowStock'),
      isEmpty,
    );

    // A check is still scheduled; it simply finds nothing new to report.
    expect(
      _notificationCalls.where((call) => call.method == 'scheduleCheck'),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
