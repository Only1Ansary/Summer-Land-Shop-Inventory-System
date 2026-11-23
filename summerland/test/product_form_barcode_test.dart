import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/models/category.dart';
import 'package:summerland/screens/products/product_form_screen.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/connectivity_service.dart';

void main() {
  const duplicateMessage =
      'This barcode is already used by another product or variant.';

  final requests = <http.Request>[];

  setUp(() {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.instance.online.value = true;

    requests.clear();
    ApiService.clientOverride = MockClient((request) async {
      requests.add(request);

      if (request.url.path == '/api/Products/barcode-available') {
        return http.Response(
          jsonEncode(false),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ConnectivityService.instance.resetForTest();
  });

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Model Number'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Barcode (optional)'),
      '12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Name'),
      'Test product',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Purchase Price'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Profit Margin (%)'),
      '20',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shirts').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a duplicate barcode is reported before the form closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductFormScreen(
          categories: [Category(id: 1, name: 'Shirts')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await fillForm(tester);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(duplicateMessage), findsOneWidget);
    expect(find.text('Add Product'), findsWidgets);
    expect(tester.takeException(), isNull);

    final availabilityCheck = requests.singleWhere(
      (request) => request.url.path == '/api/Products/barcode-available',
    );
    expect(availabilityCheck.url.queryParameters['barcode'], '12345678');
    expect(
      requests.where((request) => request.method == 'POST'),
      isEmpty,
      reason: 'A duplicate barcode must never reach the create endpoint.',
    );
  });
}
