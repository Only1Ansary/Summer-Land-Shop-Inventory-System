import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/screens/invoices/create_invoice_screen.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/physical_scanner_service.dart';

const _locations = [
  {'id': 1, 'name': 'Main Branch'},
];

const _variants = [
  {
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
    'totalQuantity': 10,
    'isLowStock': false,
  },
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

const _inventory = [
  {
    'id': 1,
    'productVariantId': 1,
    'locationId': 1,
    'locationName': 'Main Branch',
    'quantity': 10,
  },
];

/// Answers the endpoints the create-invoice screen loads.
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

const _digitKeys = <String, LogicalKeyboardKey>{
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

/// Types [barcode] the way a physical scanner does: quickly, then Enter.
Future<void> _physicalScan(WidgetTester tester, String barcode) async {
  for (final character in barcode.split('')) {
    await tester.sendKeyDownEvent(_digitKeys[character]!, character: character);
  }

  await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PhysicalScannerService.instance.resetForTest();
    ApiService.clientOverride = _fakeBackend();
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CreateInvoiceScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('new sale offers a camera action and shows scanner status', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Scan barcode'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.text('No physical scanner detected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the camera action where the camera is unavailable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    try {
      await pumpScreen(tester);

      expect(find.byTooltip('Scan barcode'), findsNothing);
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
      expect(find.text('No physical scanner detected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('focuses the search field when opened', (tester) async {
    await pumpScreen(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.autofocus, isTrue);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
      reason: 'typing should go straight into the search field',
    );
  });

  testWidgets('a physical scan opens the add-item dialog', (tester) async {
    await pumpScreen(tester);

    await _physicalScan(tester, '6201100117017');

    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Summerland Cotton T-Shirt'), findsWidgets);
    expect(find.text('Physical scanner connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown physical scan shows it and reports no match', (
    tester,
  ) async {
    await pumpScreen(tester);

    await _physicalScan(tester, '9999999999999');

    expect(find.text('No product matches this barcode.'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, '9999999999999');
    expect(tester.takeException(), isNull);
  });
}
