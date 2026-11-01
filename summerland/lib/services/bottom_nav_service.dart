import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/app_destinations.dart';

/// Persists and broadcasts the shortcuts shown in the phone bottom bar.
///
/// Home is always the first shortcut so the bar can always take the cashier
/// back to the main screen. The remaining slots are chosen by the user in
/// Settings and may be reordered.
class BottomNavService {
  BottomNavService._();

  static final BottomNavService instance = BottomNavService._();

  static const String _key = 'settings.bottomNavIds';

  /// The destination that can never be removed from the bar.
  static const String homeId = 'home';

  /// Material's maximum for a navigation bar, and the size of the default bar.
  static const int maxDestinations = 5;

  /// Home plus at least one shortcut keeps the bar useful and satisfies
  /// [NavigationBar]'s requirement for two destinations.
  static const int minDestinations = 2;

  /// The current bar, Home first. The shell listens so a change made in
  /// Settings updates the bar immediately.
  final ValueNotifier<List<String>> ids = ValueNotifier(
    List<String>.unmodifiable(AppDestinations.defaultBottomNavIds),
  );

  /// Reads the saved bar and applies it. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);

    ids.value = List<String>.unmodifiable(
      sanitize(saved ?? AppDestinations.defaultBottomNavIds),
    );
  }

  Future<void> save(Iterable<String> value) async {
    final List<String> clean = sanitize(value);

    ids.value = List<String>.unmodifiable(clean);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_key, clean);
  }

  /// Keeps only known destinations, drops duplicates, forces Home first, caps
  /// the list at [maxDestinations], and falls back to the defaults when
  /// nothing usable was stored.
  static List<String> sanitize(Iterable<String> value) {
    final Set<String> known = {
      for (final item in AppDestinations.items) item.id,
    };
    final List<String> extras = [];

    for (final String id in value) {
      if (id == homeId || !known.contains(id) || extras.contains(id)) continue;

      extras.add(id);

      if (extras.length == maxDestinations - 1) break;
    }

    if (extras.isEmpty) {
      extras.addAll(
        AppDestinations.defaultBottomNavIds
            .where((id) => id != homeId)
            .take(maxDestinations - 1),
      );
    }

    return <String>[homeId, ...extras];
  }

  /// Restores the default bar. Intended for tests so state does not leak
  /// between cases.
  @visibleForTesting
  void resetForTest() {
    ids.value = List<String>.unmodifiable(AppDestinations.defaultBottomNavIds);
  }
}
