import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/screens/invoices/create_invoice_screen.dart';
import 'package:summerland/services/api_service.dart';

const _locations = [
  {'id': 1, 'name': 'Main Branch'},
  {'id': 2, 'name': 'Warehouse'},
];

const _variants = [
  {
    'id': 1,
    'productId': 1,
    'modelNumber': 'MOD-2024-00117',
    'productName': 'Summerland Cotton T-Shirt Navy Blue Large',
    'sizeId': 1,
    'sizeName': 'L',
    'colourId': 1,
    'colourName': 'Navy Blue',
    'barcodeType': 0,
    'barcode': '6201100117017',
    'price': 1234.5,
    'lowStockThreshold': 2,
    'totalQuantity': 10,
    'isLowStock': false,
  },
  {
    'id': 2,
    'productId': 2,
    'modelNumber': 'MOD-2024-00118',
    'productName': 'Summerland Casual Shirt White Medium',
    'sizeId': 2,
    'sizeName': 'M',
    'colourId': 2,
    'colourName': 'White',
    'barcodeType': 0,
    'barcode': '6201100118016',
    'price': 49999.99,
    'lowStockThreshold': 2,
    'totalQuantity': 5,
    'isLowStock': false,
  },
];

const _employees = [
  {
    'id': 1,
    'name': 'Ahmed Mohamed Abdelrahman',
    'salary': 4000,
    'target': 20000,
    'bonus': 500,
    'bonusType': 0,
    'achievedTarget': false,
    'totalSales': 0,
  },
];

const _inventory = [
  {
    'id': 1,
    'productVariantId': 1,
    'locationId': 1,
    'locationName': 'Main Branch',
    'quantity': 10,
  },
  {
    'id': 2,
    'productVariantId': 1,
    'locationId': 2,
    'locationName': 'Warehouse',
    'quantity': 4,
  },
];

/// Answers the handful of endpoints the create-invoice screen loads.
http.Client _fakeBackend() {
  return MockClient((request) async {
    final String path = request.url.path;

    Object body;

    if (path == '/api/Locations') {
      body = _locations;
    } else if (path == '/api/ProductVariants') {
      body = _variants;
    } else if (path == '/api/Employees') {
      body = _employees;
    } else if (path.startsWith('/api/Inventory/variant/')) {
      body = _inventory;
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

void main() {
  setUp(() {
    ApiService.clientOverride = _fakeBackend();
  });

  tearDown(() {
    ApiService.clientOverride = null;
  });

  testWidgets('cart panel fits a 360x690 phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _buildCart(tester);

    _expectNoOverflow(tester, '360x690');
  });

  testWidgets('cart panel fits a short 360x560 phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _buildCart(tester);

    _expectNoOverflow(tester, '360x560');
  });
}

/// Builds a one-item cart and opens the expanded invoice panel, leaving the
/// screen in the state where the overflows used to appear.
Future<void> _buildCart(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: CreateInvoiceScreen()));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'MOD-2024');
  await tester.pumpAndSettle();

  await tester.tap(find.text('Summerland Cotton T-Shirt Navy Blue Large'));
  await tester.pumpAndSettle();

  // Pick a stock location in the add-item dialog, then add to the cart.
  await tester.tap(find.byType(DropdownButtonFormField<int>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Main Branch (10)').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();

  expect(find.text('Items: 1'), findsOneWidget);

  // Expand the cart panel - this is where the overflow shows up.
  await tester.tap(find.text('Items: 1'));
  await tester.pumpAndSettle();

  // Fill in the required location/employee so the create button is live.
  final dropdowns = find.byType(DropdownButtonFormField<int>);
  expect(dropdowns, findsNWidgets(2));

  await tester.tap(dropdowns.at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Main Branch').last);
  await tester.pumpAndSettle();

  await tester.tap(dropdowns.at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ahmed Mohamed Abdelrahman').last);
  await tester.pumpAndSettle();

  expect(find.text('Create Invoice'), findsOneWidget);
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create Invoice'),
        )
        .onPressed,
    isNotNull,
  );
}

void _expectNoOverflow(WidgetTester tester, String size) {
  final overflow = tester.takeException();
  expect(
    overflow,
    isNull,
    reason: 'Layout overflowed on a $size screen: $overflow',
  );
}
