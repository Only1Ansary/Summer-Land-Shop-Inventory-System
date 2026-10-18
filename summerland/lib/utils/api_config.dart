import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the backend lives.
///
/// On desktop, `localhost` is the same machine so the dev server is used
/// directly. On a phone/tablet `localhost` means *the device itself*, so the
/// backend must be reached over the LAN using the PC's IP address - which is
/// configurable here because DHCP can change it.
class ApiConfig {
  ApiConfig._();

  static const String _key = 'api.baseUrl';

  /// Dev-server URL used when running on this machine.
  static const String desktopBaseUrl = 'https://localhost:7251';

  /// Base URL used on phones/tablets, reached over the local network.
  static const String lanBaseUrl = 'http://192.168.100.137:5070';

  static String _baseUrl = defaultBaseUrl;

  /// The URL every [ApiService] is built with, e.g. `http://192.168.100.137:5070`.
  static String get baseUrl => _baseUrl;

  /// Platform-appropriate default so the app works without any configuration.
  static String get defaultBaseUrl {
    if (kIsWeb) return desktopBaseUrl;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return lanBaseUrl;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return desktopBaseUrl;
    }
  }

  /// Applies any saved URL. Call once at startup before the first request.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    _baseUrl = _normalize(saved ?? defaultBaseUrl);
  }

  /// Persists a new URL and applies it immediately.
  static Future<void> setBaseUrl(String value) async {
    _baseUrl = _normalize(value);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_key, _baseUrl);
  }

  /// Strips trailing slashes so endpoint concatenation (`$baseUrl/api/x`)
  /// never produces `//`.
  static String _normalize(String value) {
    var result = value.trim();

    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }

    return result;
  }

  @visibleForTesting
  static void resetForTest([String? value]) {
    _baseUrl = value ?? defaultBaseUrl;
  }
}
