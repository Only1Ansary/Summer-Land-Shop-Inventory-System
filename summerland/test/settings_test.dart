import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/main.dart';
import 'package:summerland/screens/settings/settings_screen.dart';
import 'package:summerland/services/language_service.dart';
import 'package:summerland/services/shop_profile_service.dart';
import 'package:summerland/services/theme_service.dart';
import 'package:summerland/ui/home_modules.dart';

/// Pumps the Settings screen on a tall surface so the whole list is laid out.
Future<void> pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rejects a pin limit above the module count', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpSettings(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '${homeModules.length + 1}');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Home has only ${homeModules.length} modules.'),
      findsOneWidget,
    );
  });

  testWidgets('saves a valid pin limit', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpSettings(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Currently 6 of ${homeModules.length}'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('home.maxPinned'), 6);
  });

  testWidgets('theme can be switched to dark and persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ThemeService.instance.mode.value = ThemeMode.system;

    await pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(ThemeService.instance.mode.value, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.themeMode'), 'dark');
  });

  testWidgets('shop name can be renamed and persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ShopProfileService.instance.profile.value = ShopProfile.defaults;

    await pumpSettings(tester);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sunrise Boutique');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ShopProfileService.instance.profile.value.name, 'Sunrise Boutique');
    expect(find.text('Sunrise Boutique'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shop.name'), 'Sunrise Boutique');
  });

  testWidgets('app root applies the selected theme mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ThemeService.instance.mode.value = ThemeMode.dark;

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SummerlandApp());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme, isNotNull);
  });

  testWidgets('language can be switched to Arabic and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    LanguageService.instance.language.value = AppLanguage.english;

    await pumpSettings(tester);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(LanguageService.instance.language.value, AppLanguage.arabic);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.language'), 'ar');
  });

  testWidgets('app root applies the selected locale and delegates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    LanguageService.instance.language.value = AppLanguage.arabic;

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SummerlandApp());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));
    expect(app.supportedLocales, contains(const Locale('ar')));
    expect(app.localizationsDelegates, isNotNull);

    LanguageService.instance.language.value = AppLanguage.english;
  });

  test('shop logo is persisted and reloaded', () async {
    SharedPreferences.setMockInitialValues({});

    await ShopProfileService.instance.setLogo(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
    );
    expect(ShopProfileService.instance.profile.value.hasLogo, isTrue);

    ShopProfileService.instance.profile.value = ShopProfile.defaults;
    await ShopProfileService.instance.load();
    expect(ShopProfileService.instance.profile.value.logo, <int>[1, 2, 3, 4]);

    await ShopProfileService.instance.setLogo(null);
    await ShopProfileService.instance.load();
    expect(ShopProfileService.instance.profile.value.hasLogo, isFalse);
  });
}
