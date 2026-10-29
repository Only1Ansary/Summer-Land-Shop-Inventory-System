import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/models/colour.dart';
import 'package:summerland/models/product.dart';
import 'package:summerland/models/product_variant.dart';
import 'package:summerland/models/size_model.dart';
import 'package:summerland/screens/products/split_variant_screen.dart';
import 'package:summerland/services/api_service.dart';

Product _product() => Product(
  id: 1,
  name: 'T-Shirt',
  modelNumber: 'TS-001',
  categoryId: 1,
  categoryName: 'Clothing',
  barcode: '100',
  purchasePrice: 50,
  profitMargin: 20,
  sellingPrice: 60,
);

ProductVariant _defaultVariant({int quantity = 10}) => ProductVariant(
  id: 7,
  productId: 1,
  modelNumber: 'TS-001',
  productName: 'T-Shirt',
  barcodeType: 1,
  barcode: 'SHOP-00000007',
  price: 60,
  lowStockThreshold: 2,
  totalQuantity: quantity,
  isLowStock: false,
);

void main() {
  Map<String, dynamic>? splitBody;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    splitBody = null;

    ApiService.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/api/ProductVariants/split')) {
        splitBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode(const <Object?>[]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.endsWith('/api/Sizes') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({'id': 99, 'name': body['name']}),
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
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: SplitVariantScreen(
          product: _product(),
          sourceVariant: _defaultVariant(),
          sizes: [
            SizeModel(id: 1, name: 'S'),
            SizeModel(id: 2, name: 'M'),
          ],
          colours: [Colour(id: 1, name: 'Red')],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the source stock and a starting assignment', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Default variant stock'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
    expect(find.text('10 unit(s) left to assign.'), findsOneWidget);
    // Split is disabled until all stock is assigned.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Split Variant'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('even spread balances the remaining stock', (tester) async {
    await pumpScreen(tester);

    // Distribute 10 across 4 splits: 3,3,2,2.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Add split'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Even'));
    await tester.pumpAndSettle();

    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('All 10 unit(s) assigned.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Split Variant'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('sends the split payload to the backend', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Even'));
    await tester.pumpAndSettle();

    // Choose a size for the single row.
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('S').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Split Variant'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(splitBody, isNotNull);
    expect(splitBody!['sourceVariantId'], 7);

    final splits = splitBody!['splits'] as List;

    expect(splits.length, 1);
    expect((splits.first as Map)['sizeId'], 1);
    expect((splits.first as Map)['quantity'], 10);
  });

  testWidgets('a new size can be created and used for a split', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Even'));
    await tester.pumpAndSettle();

    // Create a brand-new size inline.
    await tester.tap(find.byTooltip('Add size'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'XXL',
    );
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    // The new size is created (id 99) and selected on the row.
    expect(find.text('XXL'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Split Variant'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(splitBody, isNotNull);

    final splits = splitBody!['splits'] as List;

    expect((splits.first as Map)['sizeId'], 99);
  });
}
