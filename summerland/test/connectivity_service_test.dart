import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/services/connectivity_service.dart';

void main() {
  tearDown(() {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.clientOverride = null;
  });

  test('a reachable server leaves the app online', () async {
    ConnectivityService.clientOverride = MockClient((request) async {
      return http.Response('[]', 200);
    });

    final service = ConnectivityService.instance;
    service.resetForTest();

    await service.checkNow();

    expect(service.online.value, isTrue);
  });

  test('an unreachable server flips the app offline', () async {
    ConnectivityService.clientOverride = MockClient((request) async {
      throw http.ClientException('offline');
    });

    final service = ConnectivityService.instance;
    service.resetForTest();

    await service.checkNow();

    expect(service.online.value, isFalse);
  });

  test('coming back online fires the reconnect signal once', () async {
    var reachable = false;

    ConnectivityService.clientOverride = MockClient((request) async {
      if (!reachable) throw http.ClientException('offline');

      return http.Response('[]', 200);
    });

    final service = ConnectivityService.instance;
    service.resetForTest();

    var pulses = 0;
    service.reconnected.addListener(() => pulses++);

    await service.checkNow();
    expect(service.online.value, isFalse);
    expect(pulses, 0);

    reachable = true;
    await service.checkNow();

    expect(service.online.value, isTrue);
    expect(pulses, 1);

    // Staying online does not keep firing.
    await service.checkNow();
    expect(pulses, 1);
  });
}
