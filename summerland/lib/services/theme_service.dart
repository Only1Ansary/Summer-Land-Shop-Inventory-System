import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme_variant.dart';

/// Persists and broadcasts the app's light / dark / system choice and its
/// colour palette.
///
/// A single shared [ValueNotifier] per setting lets the root [MaterialApp]
/// rebuild the moment either choice changes, so no state management package
/// is needed.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _modeKey = 'settings.themeMode';
  static const String _variantKey = 'settings.themeVariant';

  /// The current brightness choice; defaults to following the system.
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// The current colour palette; defaults to the original app theme.
  final ValueNotifier<AppThemeVariant> variant = ValueNotifier(
    AppThemeVariant.classic,
  );

  /// Reads the stored choices and applies them. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    mode.value = _decode(prefs.getString(_modeKey));
    variant.value = _decodeVariant(prefs.getString(_variantKey));
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_modeKey, _encode(value));
  }

  Future<void> setVariant(AppThemeVariant value) async {
    variant.value = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_variantKey, _encodeVariant(value));
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

  static AppThemeVariant _decodeVariant(String? value) {
    switch (value) {
      case 'emerald':
        return AppThemeVariant.emeraldDepth;
      default:
        return AppThemeVariant.classic;
    }
  }

  static String _encodeVariant(AppThemeVariant value) {
    switch (value) {
      case AppThemeVariant.classic:
        return 'classic';
      case AppThemeVariant.emeraldDepth:
        return 'emerald';
    }
  }
}
