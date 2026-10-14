import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a star pins a module into the Pinned section', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Pinned'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);

    // The first star belongs to the first module (Products).
    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });

  testWidgets('only four modules can be pinned', (tester) async {
    SharedPreferences.setMockInitialValues({
      'home.pinnedModules': ['products', 'inventory', 'sales', 'sale-invoices'],
    });

    await pumpHome(tester);

    expect(find.text('Pinned'), findsOneWidget);

    // Try to pin a fifth module.
    final fifth = find.byIcon(Icons.star_border_rounded).first;
    await tester.ensureVisible(fifth);
    await tester.pumpAndSettle();
    await tester.tap(fifth);
    await tester.pumpAndSettle();

    expect(
      find.text('You can pin up to 4 modules. Unpin one first.'),
      findsOneWidget,
    );
  });

  testWidgets('pinned modules survive a rebuild', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsOneWidget);

    // Rebuild from scratch; the mock store keeps the saved ids.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsOneWidget);
  });
}
