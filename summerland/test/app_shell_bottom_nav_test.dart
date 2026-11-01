import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/services/bottom_nav_service.dart';
import 'package:summerland/ui/app_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BottomNavService.instance.resetForTest();
  });

  Future<void> pump(WidgetTester tester, {required String destinationId}) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          title: 'Test',
          destinationId: destinationId,
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the chosen destinations in order', (tester) async {
    await BottomNavService.instance.save(['home', 'sales', 'settings']);

    await pump(tester, destinationId: 'home');

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => (destination.label))
        .toList();

    expect(labels, ['Home', 'Sales', 'Settings']);
  });

  testWidgets('highlights the active destination', (tester) async {
    await BottomNavService.instance.save(['home', 'products', 'settings']);

    await pump(tester, destinationId: 'products');

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('a report screen highlights the reports shortcut', (tester) async {
    await BottomNavService.instance.save(['home', 'reports', 'settings']);

    await pump(tester, destinationId: 'report-sales');

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('a screen absent from the bar falls back to Home', (tester) async {
    await BottomNavService.instance.save(['home', 'products']);

    await pump(tester, destinationId: 'settings');

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });
}
