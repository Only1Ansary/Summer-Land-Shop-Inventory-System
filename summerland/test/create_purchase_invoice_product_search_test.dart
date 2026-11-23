import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/purchases/create_purchase_invoice_screen.dart';
import 'package:summerland/services/api_service.dart';

const _categories = [
  {'id': 1, 'name': 'Shirts'},
  {'id': 2, 'name': 'Shoes'},
];

const _products = [
  {
    'id': 7,
    'modelNumber': 'MOD-2024-001',
    'barcode': '6201100117017',
    'purchasePrice': 100,
    'profitMargin': 25,
    'sellingPrice': 125,
    'name': 'Summerland Cotton T-Shirt',
    'categoryId': 1,
    'categoryName': 'Shirts',
  },
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clientOverride = MockClient((request) async {
      final path = request.url.path;

      Object body;

      if (path == '/api/Products') {
        body = _products;
      } else {
        body = _categories;
      }

      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: CreatePurchaseInvoiceScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openItemDialog(WidgetTester tester) async {
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
  }

  testWidgets('suggests existing products while typing the name', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openItemDialog(tester);

    // Nothing is suggested before the user types.
    expect(find.text('Matching products'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Product Name'),
      'cotton',
    );
    await tester.pumpAndSettle();

    expect(find.text('Matching products'), findsOneWidget);
    expect(find.text('Summerland Cotton T-Shirt'), findsOneWidget);
  });

  testWidgets('selecting a suggestion autofills the item form', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Product Name'),
      'cotton',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summerland Cotton T-Shirt'));
    await tester.pumpAndSettle();

    // The suggestion list closes once a product is chosen.
    expect(find.text('Matching products'), findsNothing);

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Product Name'))
          .controller
          ?.text,
      'Summerland Cotton T-Shirt',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Model Number'))
          .controller
          ?.text,
      'MOD-2024-001',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Barcode'))
          .controller
          ?.text,
      '6201100117017',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Purchase Price'))
          .controller
          ?.text,
      '100.00',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Profit Margin'))
          .controller
          ?.text,
      '25.00',
    );
  });

  testWidgets('does not suggest products for an unknown name', (tester) async {
    await pumpScreen(tester);
    await openItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Product Name'),
      'brand new thing',
    );
    await tester.pumpAndSettle();

    expect(find.text('Matching products'), findsNothing);
  });

  testWidgets('assigns a barcode for a new product instead of asking for one', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openItemDialog(tester);

    final barcodeField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Barcode'),
    );

    expect(barcodeField.readOnly, isTrue);

    final barcode = barcodeField.controller?.text ?? '';
    expect(barcode, matches(r'^\d{8}$'));
    expect(barcode, isNot(_products.first['barcode']));
    expect(
      find.text('The internal barcode will be generated automatically.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps the existing product barcode editable when picked', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openItemDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Product Name'),
      'cotton',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summerland Cotton T-Shirt'));
    await tester.pumpAndSettle();

    final barcodeField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Barcode'),
    );

    expect(barcodeField.readOnly, isFalse);
    expect(barcodeField.controller?.text, '6201100117017');
  });
}
