import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/ui/app_shell.dart';
import 'package:summerland/ui/shop_logo.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    AppShell.resetNavScrollForTest();

    // A phone-sized viewport uses the drawer layout.
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          title: 'Home',
          destinationId: 'home',
          body: const SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('the header stays pinned while the nav list scrolls', (
    tester,
  ) async {
    await pumpShell(tester);

    // Open the drawer.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byType(ShopLogo), findsOneWidget);
    expect(find.text('Search pages…'), findsOneWidget);

    final logoTop = tester.getTopLeft(find.byType(ShopLogo)).dy;
    final searchTop = tester.getTopLeft(find.text('Search pages…')).dy;

    // Scroll the nav list well past the header.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The header must not move with the list.
    expect(tester.getTopLeft(find.byType(ShopLogo)).dy, logoTop);
    expect(tester.getTopLeft(find.text('Search pages…')).dy, searchTop);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a group header collapses and expands its tiles', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // "Categories" lives in the Catalog group and starts visible. It is not
    // in the bottom nav, so it is unique to the drawer.
    expect(find.text('Categories'), findsOneWidget);

    // Tapping the group header hides its tiles.
    await tester.tap(find.text('CATALOG'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsNothing);
    expect(tester.takeException(), isNull);

    // Tapping again brings them back.
    await tester.tap(find.text('CATALOG'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('searching opens every matching group', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Collapse the Catalog group first.
    await tester.tap(find.text('CATALOG'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsNothing);

    // Searching reveals matches even inside collapsed groups.
    await tester.enterText(find.byType(TextField), 'categories');
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('Home and Settings are standalone tiles with no section', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // No "OVERVIEW" or "SYSTEM" section headers anywhere.
    expect(find.text('OVERVIEW'), findsNothing);
    expect(find.text('SYSTEM'), findsNothing);

    // Home shows at the top without a header; Settings at the bottom.
    expect(find.text('Home'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Settings'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a collapsed group stays collapsed after scrolling away', (
    tester,
  ) async {
    AppShell.resetNavScrollForTest();

    // A short viewport forces the nav list to scroll and recycle children.
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          title: 'Home',
          destinationId: 'home',
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );

    // Collapse the Catalog group.
    await tester.tap(find.text('CATALOG'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsNothing);

    // Scroll down so Catalog leaves the viewport, then back up.
    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, 600));
    await tester.pumpAndSettle();

    // It must not have re-expanded itself.
    expect(find.text('Categories'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the drawer keeps its scroll position when reopened', (
    tester,
  ) async {
    AppShell.resetNavScrollForTest();

    // A short viewport forces the nav list to scroll.
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          title: 'Home',
          destinationId: 'home',
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );

    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();

    final double scrolled = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    // Close and reopen the drawer.
    await tester.tapAt(const Offset(390, 250));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final scrollableAgain = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final double restored = tester
        .state<ScrollableState>(scrollableAgain)
        .position
        .pixels;

    expect(restored, closeTo(scrolled, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a collapsed group stays collapsed after navigating away', (
    tester,
  ) async {
    AppShell.resetNavScrollForTest();

    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget shell(String destinationId) => MaterialApp(
      home: AppShell(
        title: 'Home',
        destinationId: destinationId,
        body: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(shell('home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Collapse the Catalog group.
    await tester.tap(find.text('CATALOG'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsNothing);

    // Navigating rebuilds the whole shell (AppDestinations.open replaces the
    // route). Simulate that by pumping a shell for another destination.
    await tester.pumpWidget(shell('products'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Drawer is open (its search field is showing) and the Catalog group is
    // still collapsed.
    expect(find.text('Search pages…'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
    expect(find.text('Categories'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
