import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/cache_store.dart';
import 'package:summerland/services/connectivity_service.dart';
import 'package:summerland/services/prefetch_service.dart';

void main() {
  final requested = <String>[];

  setUp(() async {
    requested.clear();
    SharedPreferences.setMockInitialValues({});
    await CacheStore.instance.load();
    await CacheStore.instance.clear();
    ConnectivityService.instance.resetForTest();

    ApiService.clientOverride = MockClient((request) async {
      requested.add(
        request.url.path +
            (request.url.hasQuery ? '?${request.url.query}' : ''),
      );

      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ConnectivityService.instance.resetForTest();
  });

  test('warm-up loads every list and report endpoint', () async {
    await PrefetchService.instance.warmUp();

    expect(requested, contains('/api/Products'));
    expect(requested, contains('/api/ProductVariants'));
    expect(requested, contains('/api/Categories'));
    expect(requested, contains('/api/Colours'));
    expect(requested, contains('/api/Sizes'));
    expect(requested, contains('/api/Locations'));
    expect(requested, contains('/api/Supplier'));
    expect(requested, contains('/api/Employees'));

    expect(requested, contains('/api/Reports/inventory'));
    expect(requested, contains('/api/Reports/low-stock'));

    expect(
      requested.any((r) => r.startsWith('/api/SaleInvoices?from=')),
      isTrue,
    );
    expect(
      requested.any((r) => r.startsWith('/api/PurchaseInvoices?from=')),
      isTrue,
    );
    expect(
      requested.any((r) => r.startsWith('/api/StockTransfers?from=')),
      isTrue,
    );
    expect(requested, contains('/api/Returns'));
    expect(
      requested.any((r) => r.startsWith('/api/Reports/sales?from=')),
      isTrue,
    );

    // Every prefetched endpoint landed in the cache.
    expect(CacheStore.instance.has('/api/Products'), isTrue);
    expect(CacheStore.instance.has('/api/Employees'), isTrue);
    expect(CacheStore.instance.has('/api/Reports/inventory'), isTrue);
  });

  test('reconnecting warms the cache again', () async {
    PrefetchService.instance.start();

    // Wait for the startup warm-up to finish.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final afterStartup = requested.length;
    expect(afterStartup, greaterThan(0));

    // Pretend the server dropped and came back. Coming back restores the
    // online flag, and the cache is cleared to prove the warm-up refetches.
    await CacheStore.instance.clear();
    ConnectivityService.instance.online.value = true;
    ConnectivityService.instance.pulseReconnectForTest();

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(requested.length, greaterThan(afterStartup));
    expect(CacheStore.instance.has('/api/Products'), isTrue);
  });
}
