import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/product_variant.dart';
import 'package:summerland/services/low_stock_notification_service.dart';

const MethodChannel _channel = MethodChannel(
  'summerland/low_stock_notifications',
);

ProductVariant _variant({
  required int id,
  required bool isLowStock,
  int quantity = 10,
  int threshold = 2,
  String name = 'Cotton T-Shirt',
}) {
  return ProductVariant(
    id: id,
    productId: 1,
    modelNumber: 'MOD-$id',
    productName: name,
    sizeId: null,
    sizeName: null,
    colourId: null,
    colourName: null,
    barcodeType: 0,
    barcode: '62011001170$id',
    price: 100,
    lowStockThreshold: threshold,
    totalQuantity: quantity,
    isLowStock: isLowStock,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('newlyLowStockVariants', () {
    test('finds a sold variant that has just dropped into low stock', () {
      final before = _variant(id: 1, isLowStock: false, quantity: 5);
      final after = _variant(id: 1, isLowStock: true, quantity: 1);

      final becameLow = newlyLowStockVariants(
        before: [before],
        after: [after],
        soldVariantIds: {1},
      );

      expect(becameLow.map((variant) => variant.id), [1]);
    });

    test('ignores a variant that was already low before the sale', () {
      final before = _variant(id: 1, isLowStock: true, quantity: 2);
      final after = _variant(id: 1, isLowStock: true, quantity: 1);

      expect(
        newlyLowStockVariants(
          before: [before],
          after: [after],
          soldVariantIds: {1},
        ),
        isEmpty,
      );
    });

    test('ignores a variant that is still above its threshold', () {
      final before = _variant(id: 1, isLowStock: false, quantity: 10);
      final after = _variant(id: 1, isLowStock: false, quantity: 4);

      expect(
        newlyLowStockVariants(
          before: [before],
          after: [after],
          soldVariantIds: {1},
        ),
        isEmpty,
      );
    });

    test('ignores variants that were not part of the sale', () {
      final before = _variant(id: 2, isLowStock: false, quantity: 5);
      final after = _variant(id: 2, isLowStock: true, quantity: 1);

      expect(
        newlyLowStockVariants(
          before: [before],
          after: [after],
          soldVariantIds: {1},
        ),
        isEmpty,
      );
    });

    test('ignores variants the sale screen had never seen', () {
      final after = _variant(id: 3, isLowStock: true, quantity: 0);

      expect(
        newlyLowStockVariants(
          before: const [],
          after: [after],
          soldVariantIds: {3},
        ),
        isEmpty,
      );
    });
  });

  group('LowStockNotificationService', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('creates the Android notification channel on initialize', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        await LowStockNotificationService().initialize();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(calls.map((call) => call.method), ['initialize']);
    });

    test('sends the variant details to the platform channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        await LowStockNotificationService().showLowStock(
          variant: _variant(id: 7, isLowStock: true, quantity: 1),
          title: 'Low stock alert',
          body: 'Cotton T-Shirt (MOD-7) is low on stock: 1 left.',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(calls, hasLength(1));
      expect(calls.single.method, 'showLowStock');
      expect(calls.single.arguments, {
        'id': 7,
        'title': 'Low stock alert',
        'body': 'Cotton T-Shirt (MOD-7) is low on stock: 1 left.',
      });
    });

    test('remembers only the variants that are currently low', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        await LowStockNotificationService().rememberLowStock([
          _variant(id: 2, isLowStock: false),
          _variant(id: 3, isLowStock: true),
          _variant(id: 4, isLowStock: true),
        ]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(calls, hasLength(1));
      expect(calls.single.method, 'rememberLowStock');
      expect(calls.single.arguments, {
        'ids': [3, 4],
      });
    });

    test('asks for an early background check', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        await LowStockNotificationService().scheduleBackgroundCheck();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(calls.map((call) => call.method), ['scheduleCheck']);
    });

    test('does nothing on platforms without Android notifications', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      try {
        final service = LowStockNotificationService();
        await service.initialize();
        await service.showLowStock(
          variant: _variant(id: 7, isLowStock: true),
          title: 'Low stock alert',
          body: 'Low',
        );
        await service.rememberLowStock([_variant(id: 7, isLowStock: true)]);
        await service.scheduleBackgroundCheck();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(calls, isEmpty);
    });
  });
}
