import 'dart:async';

import '../ui/app_widgets.dart';
import 'api_service.dart';
import 'cache_store.dart';
import 'connectivity_service.dart';

/// Warms the cache with every endpoint the app can show, so the shop has
/// data for screens nobody has opened yet the moment the server goes away.
///
/// Screens only fetch what they need, which leaves gaps: open the app, lose
/// the server, and untouched pages have nothing cached. This service pulls
/// every list, report, and detail record the app needs as soon as the app
/// connects to the backend server and again each time the server reconnects.
class PrefetchService {
  PrefetchService._();

  static final PrefetchService instance = PrefetchService._();

  final ApiService _apiService = ApiService();

  bool _running = false;
  bool _listening = false;

  /// Forces a cache warm-up even if one is currently running.
  /// Useful after clearing the cache so all data is reloaded when online.
  Future<void> forceWarmUp() async {
    _running = false;
    await warmUp();
  }

  /// Loads every cached endpoint in the background. Safe to call often;
  /// overlapping runs are collapsed into one.
  Future<void> warmUp() async {
    // Only attempt warm-up if we are online.
    if (!ConnectivityService.instance.online.value) return;
    if (_running) return;

    _running = true;

    try {
      // Requests run one after another so a slow link is not saturated and
      // the server is not hit with a burst on reconnect.
      for (final endpoint in _endpoints()) {
        if (!ConnectivityService.instance.online.value) break;
        try {
          await _apiService.get(endpoint);
        } catch (_) {
          // If connection dropped during warm-up, abort early.
          if (!ConnectivityService.instance.online.value) break;
        }
      }

      // Preload sub-data (employee history & payments, supplier payments)
      await _warmSubData();
    } finally {
      _running = false;
    }
  }

  Future<void> _warmSubData() async {
    if (!ConnectivityService.instance.online.value) return;

    // Sub-data for employees: history and payments
    final dynamic employees = CacheStore.instance.read('/api/Employees');
    if (employees is List) {
      for (final emp in employees) {
        if (!ConnectivityService.instance.online.value) break;
        if (emp is Map && emp['id'] != null) {
          final id = emp['id'];
          try {
            await _apiService.get('/api/Employees/$id/history');
            await _apiService.get('/api/Employees/$id/payments');
          } catch (_) {
            if (!ConnectivityService.instance.online.value) break;
          }
        }
      }
    }

    // Sub-data for suppliers: payments
    final dynamic suppliers = CacheStore.instance.read('/api/Supplier');
    if (suppliers is List) {
      for (final sup in suppliers) {
        if (!ConnectivityService.instance.online.value) break;
        if (sup is Map && sup['id'] != null) {
          final id = sup['id'];
          try {
            await _apiService.get('/api/Supplier/$id/payments');
          } catch (_) {
            if (!ConnectivityService.instance.online.value) break;
          }
        }
      }
    }
  }

  /// Starts the warm-up now and again whenever the server reconnects.
  ///
  /// The reconnect listener keeps the cache current all session, so a phone
  /// that leaves and rejoins the shop wifi always has fresh data ready.
  void start() {
    if (ConnectivityService.instance.online.value) {
      warmUp();
    }

    if (_listening) return;

    _listening = true;
    ConnectivityService.instance.reconnected.addListener(_handleReconnect);
    ConnectivityService.instance.online.addListener(_onConnectivityChange);
  }

  void _handleReconnect() {
    forceWarmUp();
  }

  void _onConnectivityChange() {
    if (ConnectivityService.instance.online.value) {
      // When connectivity is restored, force a warm-up even if one was running
      forceWarmUp();
    }
  }

  /// The exact URLs the screens request.
  ///
  /// Includes both default date-filtered queries and unfiltered endpoints so
  /// screens open offline without requiring the user to have visited them.
  List<String> _endpoints() {
    final from = defaultFilterFromDate();
    final to = defaultFilterToDate();
    final range =
        'from=${Uri.encodeComponent(from.toIso8601String())}'
        '&to=${Uri.encodeComponent(to.toIso8601String())}';

    final now = DateTime.now();
    final employeeReportRange = 'year=${now.year}&month=${now.month}';

    // Also cache common alternative ranges for reports (some screens may use
    // slightly different defaults or users may have opened with different ranges)
    final ranges = <String>[
      range,
      'from=${Uri.encodeComponent(now.subtract(const Duration(days: 7)).toIso8601String())}&to=${Uri.encodeComponent(to.toIso8601String())}',
      'from=${Uri.encodeComponent(DateTime(now.year, now.month, 1).toIso8601String())}&to=${Uri.encodeComponent(to.toIso8601String())}',
      'from=${Uri.encodeComponent(DateTime(now.year, 1, 1).toIso8601String())}&to=${Uri.encodeComponent(to.toIso8601String())}',
    ];

    final endpoints = <String>[
      // Catalog and stock lookups.
      '/api/Products',
      '/api/ProductVariants',
      '/api/Categories',
      '/api/Colours',
      '/api/Sizes',
      '/api/Locations',
      '/api/Supplier',
      '/api/Employees',

      // Transaction lists (both date-ranged and unfiltered).
      '/api/SaleInvoices',
      '/api/PurchaseInvoices',
      '/api/StockTransfers',
      '/api/Returns',

      // Reports.
      '/api/Reports/inventory',
      '/api/Reports/low-stock',
    ];

    // Add date-ranged variants for reports that commonly use date filters
    for (final r in ranges) {
      endpoints.add('/api/SaleInvoices?$r');
      endpoints.add('/api/PurchaseInvoices?$r');
      endpoints.add('/api/StockTransfers?$r');
      endpoints.add('/api/Reports/sales?$r');
      endpoints.add('/api/Reports/stock-movements?$r');
      endpoints.add('/api/Reports/best-selling?$r');
    }
    endpoints.add('/api/Reports/sales');
    endpoints.add('/api/Reports/stock-movements');
    endpoints.add('/api/Reports/best-selling');

    endpoints.add('/api/Reports/employees?$employeeReportRange');
    endpoints.add('/api/Reports/employees');

    return endpoints;
  }
}
