import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last good response for every GET endpoint.
///
/// Responses live in memory so repeat reads (and offline fallbacks) are
/// instant, and are mirrored into [SharedPreferences] so the last data the
/// shop saw survives an app restart while the server is unreachable.
///
/// Values are stored as the *decoded* JSON so readers get exactly what the
/// network layer would have returned.
class CacheStore {
  CacheStore._();

  static final CacheStore instance = CacheStore._();

  static const String _prefix = 'cache.get.';

  final Map<String, dynamic> _memory = {};
  final Map<String, DateTime> _stamps = {};

  SharedPreferences? _prefs;
  bool _loaded = false;

  /// True once [load] has run. Until then reads only see memory.
  bool get isLoaded => _loaded;

  /// Reads every cached endpoint from disk into memory. Call once at start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) continue;

        final raw = prefs.getString(key);
        if (raw == null) continue;

        final endpoint = key.substring(_prefix.length);

        try {
          _memory[endpoint] = jsonDecode(raw);
        } catch (_) {
          // A corrupt entry is dropped rather than breaking startup.
          await prefs.remove(key);
        }
      }

      _loaded = true;
    } catch (_) {
      // Without storage the cache still works in memory for this session.
      _loaded = true;
    }
  }

  /// The cached body for [endpoint], or null when nothing was stored.
  dynamic read(String endpoint) => _memory[endpoint];

  /// When [endpoint] was last written, or null when absent.
  DateTime? storedAt(String endpoint) => _stamps[endpoint];

  /// Whether anything is cached for [endpoint].
  bool has(String endpoint) => _memory.containsKey(endpoint);

  /// Saves the latest response for [endpoint].
  Future<void> write(String endpoint, dynamic value) async {
    _memory[endpoint] = value;
    _stamps[endpoint] = DateTime.now();

    final prefs = _prefs;
    if (prefs == null) return;

    try {
      await prefs.setString('$_prefix$endpoint', jsonEncode(value));
    } catch (_) {
      // Persisting is best-effort; the in-memory copy is still served.
    }
  }

  /// Drops every cached response. Used by tests.
  @visibleForTesting
  Future<void> clear() async {
    _memory.clear();
    _stamps.clear();

    final prefs = _prefs;
    if (prefs == null) return;

    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));

    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }
}
