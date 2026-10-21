import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/ui/app_widgets.dart';

void main() {
  // A short screen so the long list must scroll and recycle its children.
  Future<void> pumpReport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const CollapsibleSection(
                title: 'Revenue',
                initiallyExpanded: false,
                child: SizedBox(height: 200, child: Text('revenue-body')),
              ),
              const SizedBox(height: 400),
              const CollapsibleSection(
                title: 'Sales by Category',
                initiallyExpanded: false,
                child: SizedBox(height: 200, child: Text('category-body')),
              ),
              const SizedBox(height: 400),
              const SizedBox(height: 200),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an expanded section stays open after scrolling away', (
    tester,
  ) async {
    await pumpReport(tester);

    final scrollable = find.byType(Scrollable);

    // Open the first section.
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.text('revenue-body'), findsOneWidget);

    // Scroll it well out of view, then back.
    await tester.drag(scrollable, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, 900));
    await tester.pumpAndSettle();

    // It must still be open, not reset to initiallyExpanded (false).
    expect(find.text('revenue-body'), findsOneWidget);
  });

  testWidgets('a collapsed section stays collapsed after scrolling away', (
    tester,
  ) async {
    await pumpReport(tester);

    final scrollable = find.byType(Scrollable);

    // Open then close the first section.
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.text('revenue-body'), findsNothing);

    await tester.drag(scrollable, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(find.text('revenue-body'), findsNothing);
  });
}
