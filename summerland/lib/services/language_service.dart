import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the app's English / Arabic language choice.
///
/// Mirrors [ThemeService]: a single shared [ValueNotifier] lets the root
/// [MaterialApp] rebuild the moment the language changes, so no state
/// management package is needed.
class LanguageService {
  LanguageService._();

  static final LanguageService instance = LanguageService._();

  static const String _key = 'settings.language';

  /// Languages the app ships with, in the order they are offered.
  static const List<AppLanguage> languages = AppLanguage.values;

  /// The current language choice; defaults to English.
  final ValueNotifier<AppLanguage> language = ValueNotifier(
    AppLanguage.english,
  );

  /// The [Locale] for the current choice.
  Locale get locale => language.value.locale;

  /// Reads the stored choice and applies it. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    language.value = _decode(prefs.getString(_key));
  }

  Future<void> setLanguage(AppLanguage value) async {
    language.value = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_key, _encode(value));
  }

  static AppLanguage _decode(String? value) {
    switch (value) {
      case 'ar':
        return AppLanguage.arabic;
      default:
        return AppLanguage.english;
    }
  }

  static String _encode(AppLanguage value) {
    switch (value) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.arabic:
        return 'ar';
    }
  }
}

/// The languages the app supports.
enum AppLanguage {
  english(Locale('en'), 'English', 'English'),
  arabic(Locale('ar'), 'العربية', 'Arabic');

  const AppLanguage(this.locale, this.nativeName, this.englishName);

  final Locale locale;

  /// The language's name written in the language itself.
  final String nativeName;

  /// The language's name in English (used for accessibility labels).
  final String englishName;
}
