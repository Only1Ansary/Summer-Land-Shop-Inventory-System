import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/stock/create_stock_transfer_screen.dart';
import 'package:summerland/services/api_service.dart';

const _locations = [
  {'id': 1, 'name': 'Store'},
  {'id': 2, 'name': 'Warehouse'},
];

const _variants = [
  {
    'id': 11,
    'productId': 1,
    'modelNumber': 'TS-001',
    'productName': 'T-Shirt',
    'sizeId': 1,
    'sizeName': 'S',
    'colourId': 1,
    'colourName': 'Red',
    'barcodeType': 1,
    'barcode': '1001',
    'price': 60.0,
    'lowStockThreshold': 2,
    'totalQuantity': 10,
    'isLowStock': false,
  },
  {
    'id': 12,
    'productId': 1,
    'modelNumber': 'TS-001',
    'productName': 'T-Shirt',
    'sizeId': 2,
    'sizeName': 'M',
    'colourId': 1,
    'colourName': 'Red',
    'barcodeType': 1,
    'barcode': '1002',
    'price': 60.0,
    'lowStockThreshold': 2,
    'totalQuantity': 8,
    'isLowStock': false,
  },
];

void main() {
  Map<String, dynamic>? submitted;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    submitted = null;

    ApiService.clientOverride = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/api/StockTransfers') && request.method == 'POST') {
        submitted = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'id': 5,
            'fromLocationId': 1,
            'fromLocationName': 'Store',
            'toLocationId': 2,
            'toLocationName': 'Warehouse',
            'totalQuantity': 5,
            'createdAt': '2024-01-01T00:00:00.000',
            'items': <Object?>[],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/api/Inventory/variant/')) {
        final variantId = int.parse(path.split('/').last);

        return http.Response(
          jsonEncode([
            {
              'id': variantId,
              'productVariantId': variantId,
              'locationId': 1,
              'locationName': 'Store',
              'quantity': variantId == 11 ? 6 : 4,
            },
            {
              'id': variantId + 100,
              'productVariantId': variantId,
              'locationId': 2,
              'locationName': 'Warehouse',
              'quantity': 1,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/api/Locations')) {
        return http.Response(
          jsonEncode(_locations),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/api/ProductVariants')) {
        return http.Response(
          jsonEncode(_variants),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: CreateStockTransferScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickLocations(WidgetTester tester) async {
    await tester.tap(find.text('From Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Store').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('To Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warehouse').last);
    await tester.pumpAndSettle();
  }

  testWidgets('cannot submit before any variant is added', (tester) async {
    await pumpScreen(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Transfer Stock'),
    );

    expect(button.onPressed, isNull);
    expect(find.text('No variants added yet'), findsOneWidget);
  });

  testWidgets('adds multiple variants and submits them in one transfer', (
    tester,
  ) async {
    await pumpScreen(tester);

    await pickLocations(tester);

    // Add the first variant.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search Product'),
      'TS-001',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to transfer').first);
    await tester.pumpAndSettle();

    // Quantity dialog appears; accept the default of 1.
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '3',
    );
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    // The variant row shows how much of it sits at each chosen location.
    expect(find.text('From: Store (6)'), findsOneWidget);
    expect(find.text('To: Warehouse (1)'), findsOneWidget);

    // Add the second variant.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search Product'),
      'TS-001',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to transfer').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    expect(find.text('2 variant(s) · 5 unit(s)'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Transfer 2 variant(s)'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(submitted, isNotNull);
    expect(submitted!['fromLocationId'], 1);
    expect(submitted!['toLocationId'], 2);

    final items = submitted!['items'] as List;

    expect(items.length, 2);
    expect((items[0] as Map)['productVariantId'], 11);
    expect((items[0] as Map)['quantity'], 3);
    expect((items[1] as Map)['productVariantId'], 12);
    expect((items[1] as Map)['quantity'], 2);
  });
}
