import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/settings/bottom_navigation_settings_screen.dart';
import 'package:summerland/screens/settings/settings_screen.dart';
import 'package:summerland/services/bottom_nav_service.dart';

Future<void> pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  await tester.pumpAndSettle();
}

Future<void> pumpCustomizer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(home: BottomNavigationSettingsScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BottomNavService.instance.resetForTest();
  });

  testWidgets('Settings shows the bottom bar tile', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Bottom navigation bar'), findsOneWidget);
    expect(find.text('Customize'), findsOneWidget);
  });

  testWidgets('opening the customizer shows the Home lock', (tester) async {
    await pumpCustomizer(tester);

    expect(find.text('Always shown'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Add a shortcut'), findsOneWidget);
  });

  testWidgets('adding a shortcut persists and updates the bar', (tester) async {
    await BottomNavService.instance.save(['home', 'products']);
    await pumpCustomizer(tester);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(BottomNavService.instance.ids.value, contains('categories'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('settings.bottomNavIds'), contains('categories'));
  });

  testWidgets('the last extra cannot be removed', (tester) async {
    // Bar has Home + one extra (products).
    await BottomNavService.instance.save(['home', 'products']);
    await pumpCustomizer(tester);

    // Remove button for products is disabled.
    final removeButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove_circle_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(removeButton.onPressed, isNull);
  });

  testWidgets('adding is disabled once the bar is full', (tester) async {
    await BottomNavService.instance.save([
      'home',
      'products',
      'categories',
      'locations',
      'transfers',
    ]);
    await pumpCustomizer(tester);

    // Available items are present but their tiles are disabled.
    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Returns'));
    expect(tile.enabled, isFalse);
  });
}
