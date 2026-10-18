import 'package:shared_preferences/shared_preferences.dart';

/// Loads and stores the Home screen shortcuts.
///
/// Keeps both the pinned destination ids and the limit the user set for how
/// many modules Home may show as pinned.
class PinnedModulesService {
  static const String _key = 'home.pinnedModules';
  static const String _maxKey = 'home.maxPinned';

  /// Limit used until the user picks their own.
  static const int defaultMaxPinned = 4;

  /// The smallest limit the user is allowed to set.
  static const int minPinned = 1;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> save(List<String> destinationIds) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_key, destinationIds);
  }

  /// The user's chosen pin limit, falling back to [defaultMaxPinned].
  Future<int> loadMaxPinned() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_maxKey);

    if (value == null || value < minPinned) return defaultMaxPinned;

    return value;
  }

  Future<void> saveMaxPinned(int value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_maxKey, value < minPinned ? minPinned : value);
  }
}
