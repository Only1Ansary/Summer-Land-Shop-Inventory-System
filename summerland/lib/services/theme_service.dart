import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the app's light / dark / system choice.
///
/// A single shared [ValueNotifier] lets the root [MaterialApp] rebuild the
/// moment the choice changes, so no state management package is needed.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _key = 'settings.themeMode';

  /// The current theme choice; defaults to following the system.
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// Reads the stored choice and applies it. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    mode.value = _decode(prefs.getString(_key));
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_key, _encode(value));
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
