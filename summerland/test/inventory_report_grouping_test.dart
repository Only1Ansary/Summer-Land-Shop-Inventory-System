import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/reports/inventory_report_screen.dart';
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
    {
      'productVariantId': 4,
      'modelNumber': 'HAT-004',
      'productName': 'Sun Hat',
      'sizeName': 'M',
      'colourName': 'Beige',
      'barcode': '4444444444444',
      'price': 75.0,
      'lowStockThreshold': 2,
      'totalQuantity': 0,
      'inventoryValue': 0.0,
      'isLowStock': true,
      'locations': [
        {'locationId': 1, 'locationName': 'Main Branch', 'quantity': 0},
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

  testWidgets('inventory report lists products with summed quantities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: InventoryReportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsWidgets);
    expect(find.text('2'), findsWidgets, reason: 'two distinct products');

    expect(find.text('Cotton T-Shirt'), findsOneWidget);
    expect(find.text('Slim Jeans'), findsOneWidget);

    expect(find.text('TEE-001 • Qty: 13'), findsOneWidget);
    expect(find.text('JEA-009 • Qty: 8'), findsOneWidget);

    expect(
      find.text('Sun Hat'),
      findsNothing,
      reason: 'products with no stock are hidden',
    );

    expect(find.text('Navy'), findsNothing, reason: 'no variant colour row');
    expect(find.text('S'), findsNothing, reason: 'no variant size row');
    expect(find.text('Barcode'), findsNothing, reason: 'no variant details');
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding a product merges stock across its variants', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: InventoryReportScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cotton T-Shirt'));
    await tester.pumpAndSettle();

    expect(find.text('Main Branch'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);

    final mainTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Main Branch'),
        matching: find.byType(ListTile),
      ),
    );
    expect((mainTile.trailing! as Text).data, '8', reason: '3 + 5 merged');

    final warehouseTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Warehouse'),
        matching: find.byType(ListTile),
      ),
    );
    expect((warehouseTile.trailing! as Text).data, '5', reason: '2 + 3 merged');

    expect(tester.takeException(), isNull);
  });
}
