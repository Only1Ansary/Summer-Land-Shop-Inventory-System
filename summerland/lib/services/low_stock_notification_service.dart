import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../models/product_variant.dart';

/// Returns the variants that dropped into low stock because of [soldVariantIds].
///
/// A variant only counts when it is part of the sale, was not low on stock
/// before the sale, and is low on stock afterwards. Keeping this pure makes the
/// "only on the crossing" rule easy to test.
List<ProductVariant> newlyLowStockVariants({
  required Iterable<ProductVariant> before,
  required Iterable<ProductVariant> after,
  required Set<int> soldVariantIds,
}) {
  final beforeById = {for (final variant in before) variant.id: variant};
  final becameLow = <ProductVariant>[];

  for (final current in after) {
    if (!soldVariantIds.contains(current.id)) continue;

    final previous = beforeById[current.id];

    if (previous == null) continue;
    if (previous.isLowStock || !current.isLowStock) continue;

    becameLow.add(current);
  }

  return becameLow;
}

/// Shows Android notifications when a sale pushes a product into low stock.
///
/// Backed by a small platform channel handled in `MainActivity`; other
/// platforms (Windows, web, iOS) simply ignore the calls, so screens can use it
/// unconditionally. Every platform failure is swallowed: a missing permission
/// or notification service must never break the sale itself.
class LowStockNotificationService {
  LowStockNotificationService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('summerland/low_stock_notifications');

  /// The app-wide instance used by the sale screen.
  static final LowStockNotificationService instance =
      LowStockNotificationService();

  final MethodChannel _channel;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Creates the notification channel and asks for the Android 13+ runtime
  /// permission. Does nothing on platforms without Android notifications.
  Future<void> initialize() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod<void>('initialize');
    } catch (error) {
      debugPrint('Could not initialise low stock notifications: $error');
    }
  }

  /// Shows one notification for [variant]. Repeated alerts for the same variant
  /// replace the previous one instead of piling up.
  Future<void> showLowStock({
    required ProductVariant variant,
    required String title,
    required String body,
  }) async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod<void>('showLowStock', {
        'id': variant.id,
        'title': title,
        'body': body,
      });
    } catch (error) {
      debugPrint('Could not show low stock notification: $error');
    }
  }

  /// Records which variants are currently low on stock.
  ///
  /// The background checker keeps its own copy of this set so it does not raise
  /// the same alert again minutes after the app already showed it. A variant
  /// that recovers leaves the set and can alert again the next time it drops.
  Future<void> rememberLowStock(Iterable<ProductVariant> variants) async {
    if (!isSupported) return;

    final ids = variants
        .where((variant) => variant.isLowStock)
        .map((variant) => variant.id)
        .toList();

    try {
      await _channel.invokeMethod<void>('rememberLowStock', {'ids': ids});
    } catch (error) {
      debugPrint('Could not store the low stock baseline: $error');
    }
  }

  /// Asks Android for an early background check, so a sale still produces an
  /// alert if the app is closed right after it is committed.
  Future<void> scheduleBackgroundCheck() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod<void>('scheduleCheck');
    } catch (error) {
      debugPrint('Could not schedule the low stock check: $error');
    }
  }
}
