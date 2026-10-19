import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/cache_store.dart';
import 'package:summerland/services/connectivity_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheStore.instance.load();
    await CacheStore.instance.clear();
    ApiService.servingCachedData.value = false;
    ConnectivityService.instance.resetForTest();
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ApiService.servingCachedData.value = false;
    ConnectivityService.instance.resetForTest();
  });

  test('a successful GET is cached and served back', () async {
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        jsonEncode([
          {'id': 1, 'name': 'Navy'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(baseUrl: 'http://test.local');
    final first = await api.get('/api/Colours');

    expect(first, isA<List<dynamic>>());
    expect(CacheStore.instance.has('/api/Colours'), isTrue);
    expect(ApiService.servingCachedData.value, isFalse);
  });

  test('a failing GET falls back to the cached copy', () async {
    var failing = false;

    ApiService.clientOverride = MockClient((request) async {
      if (failing) {
        throw http.ClientException('offline');
      }

      return http.Response(
        jsonEncode([
          {'id': 1, 'name': 'Navy'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(baseUrl: 'http://test.local');
    await api.get('/api/Colours');

    failing = true;
    final offline = await api.get('/api/Colours');

    expect(offline, isA<List<dynamic>>());
    expect(offline, hasLength(1));
    expect(ApiService.servingCachedData.value, isTrue);
  });

  test('a failing GET with no cache still throws', () async {
    ApiService.clientOverride = MockClient((request) async {
      throw http.ClientException('offline');
    });

    final api = ApiService(baseUrl: 'http://test.local');

    await expectLater(api.get('/api/Colours'), throwsA(isA<ApiException>()));

    // The failure flips the app offline so the next read is instant.
    expect(ConnectivityService.instance.online.value, isFalse);
  });

  test('going offline is picked up without another doomed request', () async {
    var calls = 0;

    ApiService.clientOverride = MockClient((request) async {
      calls++;
      throw http.ClientException('offline');
    });

    final api = ApiService(baseUrl: 'http://test.local');

    // First online request fails and marks the app offline.
    await expectLater(api.get('/api/Colours'), throwsA(isA<ApiException>()));
    expect(calls, 1);

    // Seed a cached copy as if the endpoint had loaded before.
    await CacheStore.instance.write('/api/Colours', [
      {'id': 1, 'name': 'Navy'},
    ]);

    final cached = await api.get('/api/Colours');

    expect(cached, hasLength(1));
    expect(calls, 1, reason: 'offline reads skip the network entirely');
    expect(ApiService.servingCachedData.value, isTrue);
  });

  test('a date-ranged GET offline falls back to the unfiltered copy', () async {
    ApiService.clientOverride = MockClient((request) async {
      throw http.ClientException('offline');
    });

    // Only the plain endpoint was warmed, as the prefetch does.
    await CacheStore.instance.write('/api/SaleInvoices', [
      {'id': 7},
    ]);
    ConnectivityService.instance.markOffline();

    final api = ApiService(baseUrl: 'http://test.local');
    final data = await api.get(
      '/api/SaleInvoices?from=2026-01-01&to=2026-01-02',
    );

    expect(data, hasLength(1));
    expect(ApiService.servingCachedData.value, isTrue);
  });

  test('a server error is never masked by the cache', () async {
    var status = 200;

    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        status == 200 ? jsonEncode([]) : jsonEncode({'detail': 'nope'}),
        status,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(baseUrl: 'http://test.local');
    await api.get('/api/Colours');

    status = 400;

    await expectLater(api.get('/api/Colours'), throwsA(isA<ApiException>()));
  });

  test('the cache survives a restart by reloading from storage', () async {
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        jsonEncode({'value': 42}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(baseUrl: 'http://test.local');
    await api.get('/api/Reports/sales');

    // A fresh session: memory is discarded, disk is reloaded.
    await CacheStore.instance.load();

    expect(CacheStore.instance.read('/api/Reports/sales'), {'value': 42});
  });
}
