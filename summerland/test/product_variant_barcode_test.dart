import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/models/colour.dart';
import 'package:summerland/models/product.dart';
import 'package:summerland/models/product_variant.dart';
import 'package:summerland/models/size_model.dart';
import 'package:summerland/screens/products/product_variant_form_screen.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/connectivity_service.dart';
import 'package:summerland/ui/app_widgets.dart';

void main() {
  const duplicateMessage =
      'This barcode is already used by another product or variant.';

  final requests = <http.Request>[];
  bool available = false;
  bool failAvailability = false;

  setUp(() {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.instance.online.value = true;

    requests.clear();
    available = false;
    failAvailability = false;

    ApiService.clientOverride = MockClient((request) async {
      requests.add(request);

      if (request.url.path == '/api/Products/barcode-available' &&
          failAvailability) {
        throw const SocketException('offline');
      }

      if (request.url.path == '/api/Products/barcode-available') {
        return http.Response(
          jsonEncode(available),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/Locations' ||
          request.url.path.startsWith('/api/Inventory/variant/')) {
        return http.Response(
          jsonEncode(<dynamic>[]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/ProductVariants' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'id': 20,
            'productId': 5,
            'modelNumber': '100',
            'productName': 'Test product',
            'barcodeType': 2,
            'barcode': '12345678',
            'price': 100,
            'lowStockThreshold': 2,
            'totalQuantity': 0,
            'isLowStock': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ConnectivityService.instance.resetForTest();
  });

  Product _product() => Product(
    id: 5,
    modelNumber: '100',
    barcode: '1000',
    purchasePrice: 100,
    profitMargin: 20,
    sellingPrice: 120,
    name: 'Test product',
    categoryId: 1,
    categoryName: 'Shirts',
  );

  ProductVariant _variant() => ProductVariant(
    id: 12,
    productId: 5,
    modelNumber: '100',
    productName: 'Test product',
    barcodeType: 2,
    barcode: '5555',
    sellingPrice: 120,
    lowStockThreshold: 2,
    totalQuantity: 4,
    isLowStock: false,
  );

  Future<Future<Object?>> _openForm(
    WidgetTester tester, {
    ProductVariant? variant,
  }) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.shrink(),
      ),
    );

    final popped = navigatorKey.currentState!.push<Object?>(
      MaterialPageRoute(
        builder: (_) => ProductVariantFormScreen(
          product: _product(),
          sizes: const <SizeModel>[],
          colours: const <Colour>[],
          variant: variant,
        ),
      ),
    );

    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> _chooseManualBarcode(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('barcode-type-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual').last);
    await tester.pumpAndSettle();
  }

  Future<void> _tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
  }

  testWidgets('duplicate manual barcode keeps the new-variant form open', (
    tester,
  ) async {
    await _openForm(tester);
    await _chooseManualBarcode(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Manual Barcode'),
      '12345678',
    );
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(find.text(duplicateMessage), findsOneWidget);
    expect(find.text('Add Variant'), findsWidgets);
    expect(tester.takeException(), isNull);

    final availabilityCheck = requests.singleWhere(
      (request) => request.url.path == '/api/Products/barcode-available',
    );
    expect(availabilityCheck.url.queryParameters['barcode'], '12345678');
    expect(
      availabilityCheck.url.queryParameters['excludeVariantId'],
      isNull,
    );
    expect(
      requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/ProductVariants',
      ),
      isEmpty,
      reason: 'A duplicate barcode must not be scheduled for the undo window.',
    );
  });

  testWidgets('editing a variant excludes only its own barcode from the check', (
    tester,
  ) async {
    await _openForm(tester, variant: _variant());
    await _tapSave(tester);

    expect(find.text(duplicateMessage), findsOneWidget);
    expect(find.text('Save'), findsWidgets);
    expect(tester.takeException(), isNull);

    final availabilityCheck = requests.singleWhere(
      (request) => request.url.path == '/api/Products/barcode-available',
    );
    expect(availabilityCheck.url.queryParameters['barcode'], '5555');
    expect(availabilityCheck.url.queryParameters['excludeVariantId'], '12');
    expect(availabilityCheck.url.queryParameters['excludeId'], isNull);
    expect(
      requests.where((request) => request.method == 'PUT'),
      isEmpty,
      reason: 'A duplicate barcode must not reach the update endpoint.',
    );
  });

  testWidgets('an unavailable barcode check blocks save with an inline error', (
    tester,
  ) async {
    failAvailability = true;

    await _openForm(tester);
    await _chooseManualBarcode(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Manual Barcode'),
      '12345678',
    );
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(find.text('Add Variant'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.errorText != null &&
            widget.decoration.errorText!.isNotEmpty,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(
      requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/ProductVariants',
      ),
      isEmpty,
    );
  });

  testWidgets('an available manual barcode still returns a deferred create', (
    tester,
  ) async {
    available = true;

    final popped = await _openForm(tester);
    await _chooseManualBarcode(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Manual Barcode'),
      '12345678',
    );
    await tester.pumpAndSettle();
    await _tapSave(tester);

    final result = await popped.timeout(const Duration(seconds: 1));
    expect(result, isA<DeferredCrud>());
    expect(tester.takeException(), isNull);

    final availabilityCheck = requests.singleWhere(
      (request) => request.url.path == '/api/Products/barcode-available',
    );
    expect(availabilityCheck.url.queryParameters['barcode'], '12345678');
    expect(
      requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/ProductVariants',
      ),
      isEmpty,
      reason: 'The create must stay deferred until the undo window ends.',
    );
  });
}
