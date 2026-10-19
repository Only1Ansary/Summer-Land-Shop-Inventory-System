import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/api_config.dart';

/// Watches whether the backend is reachable and broadcasts the transitions.
///
/// Wifi alone is not enough: the phone may be on the LAN while the shop PC
/// is off, so this pings the server itself. [online] is the single source of
/// truth screens read; [reconnected] fires once each time the server comes
/// back after being away, which screens use to refresh themselves.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const Duration _interval = Duration(seconds: 5);

  /// Whether the backend answered the last check.
  final ValueNotifier<bool> online = ValueNotifier(true);

  /// Emits once whenever the server becomes reachable again.
  final ChangeNotifier reconnected = _PulseNotifier();

  Timer? _timer;
  bool _checking = false;

  /// Starts polling. Safe to call once at startup; repeat calls are ignored.
  void start() {
    if (_timer != null) return;

    _timer = Timer.periodic(_interval, (_) => checkNow());

    // The very first verdict comes from an immediate probe.
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Flags the app offline right away, e.g. when a request just failed.
  ///
  /// The next read then takes the cache fast-path instead of waiting for
  /// another request to time out, and the next poll flips it back once the
  /// server answers again.
  void markOffline() {
    online.value = false;
  }

  /// Probes the server right away, e.g. after a failed write or on resume.
  Future<void> checkNow() async {
    if (_checking) return;

    _checking = true;

    try {
      final reachable = await _ping();
      final wasOnline = online.value;

      online.value = reachable;

      if (reachable && !wasOnline) {
        (reconnected as _PulseNotifier).pulse();
      }
    } finally {
      _checking = false;
    }
  }

  /// A cheap request that proves the server is up. Any HTTP answer - even a
  /// 404 - means the server is reachable; only transport faults mean down.
  Future<bool> _ping() async {
    final override = _clientOverride;
    final client = override ?? http.Client();

    try {
      // Redirects and status codes do not matter, so a HEAD to the base URL
      // is enough and avoids downloading a body.
      await client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/Locations'))
          .timeout(const Duration(seconds: 4));

      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    } finally {
      if (override == null) client.close();
    }
  }

  /// Lets tests answer the connectivity probe without a real network.
  static http.Client? _clientOverride;

  @visibleForTesting
  static set clientOverride(http.Client? value) => _clientOverride = value;

  @visibleForTesting
  static http.Client? get clientOverride => _clientOverride;

  /// Resets to the online default so tests start from a known state.
  @visibleForTesting
  void resetForTest() {
    stop();
    _checking = false;
    online.value = true;
  }

  /// Fires the reconnect signal without a real network, for tests.
  @visibleForTesting
  void pulseReconnectForTest() {
    (reconnected as _PulseNotifier).pulse();
  }
}

/// A [ChangeNotifier] that notifies manually, used for one-shot pulses.
class _PulseNotifier extends ChangeNotifier {
  void pulse() => notifyListeners();
}
