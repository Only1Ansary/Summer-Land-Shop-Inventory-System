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

  static const Set<String> _indexableCollections = {
    '/api/Products',
    '/api/ProductVariants',
    '/api/SaleInvoices',
    '/api/PurchaseInvoices',
    '/api/StockTransfers',
    '/api/Supplier',
    '/api/Employees',
    '/api/Returns',
  };

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

  /// The cached body for [endpoint], or a compatible cached fallback when
  /// offline, or null when nothing was stored.
  dynamic read(String endpoint) {
    // 1. Exact match in memory
    if (_memory.containsKey(endpoint)) {
      return _memory[endpoint];
    }

    // 2. Product search fallback: answer from cached /api/Products
    if (endpoint.startsWith('/api/Products/search')) {
      final cachedProducts = _memory['/api/Products'];
      if (cachedProducts is List) {
        return _filterProducts(endpoint, cachedProducts);
      }
    }

    // 3. Fallback for query-stripped endpoint (e.g. /api/SaleInvoices?from=... -> /api/SaleInvoices)
    final base = _withoutQuery(endpoint);
    if (base != endpoint && _memory.containsKey(base)) {
      return _memory[base];
    }

    // 4. Reverse query fallback: requested endpoint without query, but query-ranged copy exists
    // (e.g. /api/SaleInvoices requested, but /api/SaleInvoices?from=... is cached)
    if (base == endpoint) {
      for (final entry in _memory.entries) {
        if (entry.key.startsWith('$base?')) {
          return entry.value;
        }
      }
    }

    // 5. Single item lookup by ID from cached collection
    // (e.g. /api/SaleInvoices/10 looks in cached /api/SaleInvoices list)
    final idMatch = RegExp(r'^/api/([A-Za-z]+)/(\d+)$').firstMatch(endpoint);
    if (idMatch != null) {
      final collectionName = idMatch.group(1);
      final id = int.tryParse(idMatch.group(2)!);
      if (id != null && collectionName != null) {
        final collectionEndpoint = '/api/$collectionName';
        dynamic collectionData = _memory[collectionEndpoint];
        if (collectionData == null) {
          for (final entry in _memory.entries) {
            if (entry.key.startsWith('$collectionEndpoint?')) {
              collectionData = entry.value;
              break;
            }
          }
        }
        if (collectionData is List) {
          for (final item in collectionData) {
            if (item is Map &&
                (item['id'] == id || item['productVariantId'] == id)) {
              return item;
            }
          }
        }
      }
    }

    // 6. Reports fallback (e.g. /api/Reports/employees?year=... -> /api/Reports/employees)
    if (endpoint.startsWith('/api/Reports/employees')) {
      for (final entry in _memory.entries) {
        if (entry.key.startsWith('/api/Reports/employees')) {
          return entry.value;
        }
      }
    }

    // 7. Safe empty list fallback for known sub-collections when offline
    if (endpoint.contains('/history') || endpoint.contains('/payments')) {
      return const [];
    }

    return null;
  }

  /// Filters cached products for /api/Products/search queries.
  List<dynamic> _filterProducts(String endpoint, List<dynamic> products) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return products;

    final query = uri.queryParameters['query']?.trim().toLowerCase();
    final categoryIdStr = uri.queryParameters['categoryId'];
    final categoryId = categoryIdStr != null
        ? int.tryParse(categoryIdStr)
        : null;
    final sizeIdStr = uri.queryParameters['sizeId'];
    final sizeId = sizeIdStr != null ? int.tryParse(sizeIdStr) : null;
    final colourIdStr = uri.queryParameters['colourId'];
    final colourId = colourIdStr != null ? int.tryParse(colourIdStr) : null;

    return products.where((item) {
      if (item is! Map) return false;

      if (categoryId != null && item['categoryId'] != categoryId) {
        return false;
      }
      if (sizeId != null && item['sizeId'] != sizeId) {
        return false;
      }
      if (colourId != null && item['colourId'] != colourId) {
        return false;
      }

      if (query != null && query.isNotEmpty) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final model = (item['modelNumber'] ?? '').toString().toLowerCase();
        final barcode = (item['barcode'] ?? '').toString().toLowerCase();

        if (!name.contains(query) &&
            !model.contains(query) &&
            !barcode.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  static String _withoutQuery(String endpoint) {
    final index = endpoint.indexOf('?');
    return index < 0 ? endpoint : endpoint.substring(0, index);
  }

  /// When [endpoint] was last written, or null when absent.
  DateTime? storedAt(String endpoint) => _stamps[endpoint];

  /// Whether anything is cached for [endpoint].
  bool has(String endpoint) => _memory.containsKey(endpoint);

  /// Saves the latest response for [endpoint].
  Future<void> write(String endpoint, dynamic value) async {
    _memory[endpoint] = value;
    _stamps[endpoint] = DateTime.now();

    final prefs = _prefs;
    if (prefs != null) {
      try {
        await prefs.setString('$_prefix$endpoint', jsonEncode(value));
      } catch (_) {
        // Persisting is best-effort; the in-memory copy is still served.
      }
    }

    // Auto-index collection items by ID for instant individual lookups offline
    if (value is List) {
      final base = _withoutQuery(endpoint);
      if (_indexableCollections.contains(base)) {
        for (final item in value) {
          if (item is Map && item['id'] != null) {
            final itemEndpoint = '$base/${item['id']}';
            _memory[itemEndpoint] = item;
            _stamps[itemEndpoint] = DateTime.now();
            if (prefs != null) {
              try {
                await prefs.setString(
                  '$_prefix$itemEndpoint',
                  jsonEncode(item),
                );
              } catch (_) {}
            }
          }
        }
      }
    }
  }

  /// Number of cached entries currently held in memory.
  int get entryCount => _memory.length;

  /// Approximate size of cached data in bytes (JSON-encoded).
  int get sizeBytes {
    var total = 0;
    for (final entry in _memory.entries) {
      try {
        total += jsonEncode(entry.value).length;
      } catch (_) {
        // Skip entries that cannot be serialized.
      }
    }
    return total;
  }

  /// Formatted cache size for display (e.g. "1.2 MB", "345 KB").
  String get formattedSize {
    final bytes = sizeBytes;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  /// Clears all cached data (public API for settings).
  Future<void> clearAll() => clear();
}
