import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/inventory/inventory_search_screen.dart';
import 'package:summerland/services/api_service.dart';

const _report = <String, Object?>{
  'totalVariants': 3,
  'totalQuantity': 21,
  'totalInventoryValue': 2100.0,
  'lowStockVariants': 0,
  'items': [
    {
      'productVariantId': 1,
      'modelNumber': 'TEE-001',
      'productName': 'Cotton T-Shirt',
      'sizeName': 'S',
      'colourName': 'Navy',
      'barcode': '1111111111111',
      'price': 100.0,
      'lowStockThreshold': 2,
      'totalQuantity': 5,
      'inventoryValue': 500.0,
      'isLowStock': false,
      'locations': [
        {'locationId': 1, 'locationName': 'Main Branch', 'quantity': 3},
        {'locationId': 2, 'locationName': 'Warehouse', 'quantity': 2},
      ],
    },
    {
      'productVariantId': 2,
      'modelNumber': 'TEE-001',
      'productName': 'Cotton T-Shirt',
      'sizeName': 'L',
      'colourName': 'Navy',
      'barcode': '2222222222222',
      'price': 100.0,
      'lowStockThreshold': 2,
      'totalQuantity': 8,
      'inventoryValue': 800.0,
      'isLowStock': false,
      'locations': [
        {'locationId': 1, 'locationName': 'Main Branch', 'quantity': 5},
        {'locationId': 2, 'locationName': 'Warehouse', 'quantity': 3},
      ],
    },
    {
      'productVariantId': 3,
      'modelNumber': 'JEA-009',
      'productName': 'Slim Jeans',
      'sizeName': '32',
      'colourName': 'Blue',
      'barcode': '3333333333333',
      'price': 200.0,
      'lowStockThreshold': 2,
      'totalQuantity': 8,
      'inventoryValue': 800.0,
      'isLowStock': false,
      'locations': [
        {'locationId': 1, 'locationName': 'Main Branch', 'quantity': 8},
      ],
    },
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        jsonEncode(_report),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: InventorySearchScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows nothing until the user searches', (tester) async {
    await pumpSearch(tester);

    expect(find.text('Inventory Search'), findsOneWidget);
    expect(find.text('Search for a product'), findsOneWidget);
    expect(find.text('Cotton T-Shirt'), findsNothing);
    expect(find.text('Slim Jeans'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching shows the product without the summary stats', (
    tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'tee');
    await tester.pumpAndSettle();

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.text('TEE-001 • Qty: 13'), findsOneWidget);

    // The product shows its price.
    expect(find.text('100.00 EGP'), findsOneWidget);

    expect(find.text('Total Quantity'), findsNothing, reason: 'no stats grid');
    expect(find.text('Inventory Value'), findsNothing);
    expect(find.text('Product Quantities'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search narrows the list by name and model', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'jeans');
    await tester.pumpAndSettle();

    expect(find.text('Slim Jeans'), findsOneWidget);
    expect(find.text('Cotton T-Shirt'), findsNothing);

    await tester.enterText(find.byType(TextField), 'TEE-001');
    await tester.pumpAndSettle();

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.text('Slim Jeans'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No products found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a product expands into per-location size breakdown', (
    tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'tee');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cotton T-Shirt'));
    await tester.pumpAndSettle();

    // Main Branch: S=3, L=5 (total 8) — the sizes stocked there are listed.
    expect(find.text('Main Branch'), findsOneWidget);
    expect(find.text('S: 3'), findsOneWidget);
    expect(find.text('L: 5'), findsOneWidget);

    final mainTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Main Branch'),
        matching: find.byType(ListTile),
      ),
    );
    expect((mainTile.trailing! as Text).data, '8', reason: '3 + 5 merged');

    // Warehouse: S=2, L=3 (total 5).
    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('S: 2'), findsOneWidget);
    expect(find.text('L: 3'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
