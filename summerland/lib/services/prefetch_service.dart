import 'dart:async';

import '../ui/app_widgets.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

/// Warms the cache with every endpoint the app can show, so the shop has
/// data for screens nobody has opened yet the moment the server goes away.
///
/// Screens only fetch what they need, which leaves gaps: open the app, lose
/// the server, and untouched pages have nothing cached. This service pulls
/// the default list/report URLs the same screens would request - the same
/// keys, so the cache hits - as soon as the app starts and again each time
/// the server reconnects.
class PrefetchService {
  PrefetchService._();

  static final PrefetchService instance = PrefetchService._();

  final ApiService _apiService = ApiService();

  bool _running = false;
  bool _listening = false;

  /// Loads every cached endpoint in the background. Safe to call often;
  /// overlapping runs are collapsed into one.
  Future<void> warmUp() async {
    if (_running) return;

    _running = true;

    try {
      // Requests run one after another so a slow link is not saturated and
      // the server is not hit with a burst on reconnect.
      for (final endpoint in _endpoints()) {
        try {
          await _apiService.get(endpoint);
        } catch (_) {
          // A single endpoint failing (deleted report, bad filter) must not
          // stop the rest from caching.
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Starts the warm-up now and again whenever the server reconnects.
  ///
  /// The reconnect listener keeps the cache current all session, so a phone
  /// that leaves and rejoins the shop wifi always has fresh data ready.
  void start() {
    warmUp();

    if (_listening) return;

    _listening = true;
    ConnectivityService.instance.reconnected.addListener(warmUp);
  }

  /// The exact URLs the screens request by default.
  ///
  /// Date-ranged lists use the same [defaultFilterFromDate] /
  /// [defaultFilterToDate] window as the screens, so the prefetched entry is
  /// the one a screen reads offline.
  List<String> _endpoints() {
    final from = defaultFilterFromDate();
    final to = defaultFilterToDate();
    final range =
        'from=${Uri.encodeComponent(from.toIso8601String())}'
        '&to=${Uri.encodeComponent(to.toIso8601String())}';

    return [
      // Catalog and stock lookups.
      '/api/Products',
      '/api/ProductVariants',
      '/api/Categories',
      '/api/Colours',
      '/api/Sizes',
      '/api/Locations',
      '/api/Supplier',

      // Transaction lists.
      '/api/SaleInvoices?$range',
      '/api/PurchaseInvoices?$range',
      '/api/StockTransfers?$range',
      '/api/Returns',

      // People.
      '/api/Employees',

      // Reports.
      '/api/Reports/sales?$range',
      '/api/Reports/inventory',
      '/api/Reports/low-stock',
      '/api/Reports/stock-movements?$range',
      '/api/Reports/best-selling?$range',
    ];
  }
}
