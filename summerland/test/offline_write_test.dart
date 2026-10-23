import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/connectivity_service.dart';

void main() {
  var calls = 0;

  setUp(() {
    calls = 0;
    ConnectivityService.instance.resetForTest();
    // The write guard asks the connectivity service to re-probe when it
    // refuses a change; answer that probe locally so no real socket is used.
    ConnectivityService.clientOverride = MockClient((request) async {
      throw http.ClientException('offline');
    });
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ConnectivityService.clientOverride = null;
    ConnectivityService.instance.resetForTest();
  });

  ApiService onlineApi() {
    ApiService.clientOverride = MockClient((request) async {
      calls++;

      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    return ApiService(baseUrl: 'http://test.local');
  }

  test(
    'a POST is refused while offline without touching the network',
    () async {
      final api = onlineApi();
      ConnectivityService.instance.markOffline();

      await expectLater(
        api.post('/api/Categories', {'name': 'Tops'}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('You are offline'),
          ),
        ),
      );

      expect(calls, 0, reason: 'blocked writes never reach the network');
    },
  );

  test('a PUT is refused while offline', () async {
    final api = onlineApi();
    ConnectivityService.instance.markOffline();

    await expectLater(
      api.put('/api/Categories/1', {'name': 'Tops'}),
      throwsA(isA<ApiException>()),
    );

    expect(calls, 0);
  });

  test('a DELETE is refused while offline', () async {
    final api = onlineApi();
    ConnectivityService.instance.markOffline();

    await expectLater(
      api.delete('/api/Categories/1'),
      throwsA(isA<ApiException>()),
    );

    expect(calls, 0);
  });

  test('writes still go through while online', () async {
    final api = onlineApi();

    final result = await api.post('/api/Categories', {'name': 'Tops'});

    expect(result, {'ok': true});
    expect(calls, 1);
  });

  test('a failed write marks the app offline for the next attempt', () async {
    ApiService.clientOverride = MockClient((request) async {
      throw http.ClientException('offline');
    });

    final api = ApiService(baseUrl: 'http://test.local');

    await expectLater(
      api.post('/api/Categories', {'name': 'Tops'}),
      throwsA(isA<ApiException>()),
    );

    expect(ConnectivityService.instance.online.value, isFalse);
  });
}
