import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/services/bottom_nav_service.dart';
import 'package:summerland/ui/app_destinations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BottomNavService.instance.resetForTest();
  });

  test('load uses the default bar when nothing is saved', () async {
    await BottomNavService.instance.load();

    expect(
      BottomNavService.instance.ids.value,
      AppDestinations.defaultBottomNavIds,
    );
  });

  test('load reads and sanitizes the saved bar', () async {
    SharedPreferences.setMockInitialValues({
      'settings.bottomNavIds': ['home', 'settings', 'unknown', 'settings'],
    });

    await BottomNavService.instance.load();

    expect(BottomNavService.instance.ids.value, ['home', 'settings']);
  });

  test('save persists the bar and notifies listeners', () async {
    BottomNavService.instance.resetForTest();

    var notified = 0;
    BottomNavService.instance.ids.addListener(() => notified++);

    await BottomNavService.instance.save(['home', 'products', 'settings']);

    expect(BottomNavService.instance.ids.value, ['home', 'products', 'settings']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('settings.bottomNavIds'), [
      'home',
      'products',
      'settings',
    ]);
    expect(notified, 1);
  });

  test('sanitize forces Home first and drops unknowns and duplicates', () {
    expect(
      BottomNavService.sanitize([
        'products',
        'home',
        'products',
        'does-not-exist',
        'settings',
      ]),
      ['home', 'products', 'settings'],
    );
  });

  test('sanitize caps the bar at the maximum size', () {
    final result = BottomNavService.sanitize([
      'home',
      'products',
      'categories',
      'locations',
      'transfers',
      'returns',
    ]);

    expect(result.length, BottomNavService.maxDestinations);
    expect(result.first, 'home');
  });

  test('sanitize falls back to the defaults when nothing is usable', () {
    expect(
      BottomNavService.sanitize(['does-not-exist']),
      AppDestinations.defaultBottomNavIds,
    );
  });
}
