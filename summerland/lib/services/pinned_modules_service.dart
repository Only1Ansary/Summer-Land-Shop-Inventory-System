import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the list of module ids the user pinned to the Home
/// screen. The ids are stored in order so the pinned section keeps the
/// order the user added them in.
class PinnedModulesService {
  static const String _key = 'home.pinnedModules';

  /// The most modules Home will show as pinned.
  static const int maxPinned = 4;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> save(List<String> destinationIds) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_key, destinationIds);
  }
}
