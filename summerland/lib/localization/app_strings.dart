import 'package:flutter/material.dart';

import 'app_strings_ar.dart';

/// Localization for the app's own strings.
///
/// The app is small and has no ARB/codegen setup, so this keeps every
/// translation in plain Dart maps instead. The English text *is* the key:
/// [translate] looks the key up in the Arabic dictionary and returns the
/// English original when there is no translation, so untranslated strings
/// still render sensibly.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';

  /// The delegate that installs [AppStrings] into the widget tree.
  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('en'));
  }

  /// Translates [key], substituting positional `{0}`, `{1}` … placeholders
  /// with [args].
  String translate(String key, [List<Object?> args = const []]) {
    String text = key;

    if (isArabic) {
      text = appStringsAr[key] ?? key;
    }

    for (var i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', '${args[i]}');
    }

    return text;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'ar';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

/// Ergonomic access to [AppStrings] from a [BuildContext].
extension AppLocalization on BuildContext {
  AppStrings get strings => AppStrings.of(this);

  /// Shorthand for `strings.translate(text, args)`.
  String tr(String text, [List<Object?> args = const []]) =>
      AppStrings.of(this).translate(text, args);
}
