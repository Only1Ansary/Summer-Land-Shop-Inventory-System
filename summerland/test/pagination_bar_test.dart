import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/ui/app_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('shows the visible range and page count', (tester) async {
    await pump(
      tester,
      PaginationBar(
        page: 0,
        pageSize: 10,
        totalItems: 23,
        onPageChanged: (_) {},
      ),
    );

    expect(find.text('Showing 1-10 of 23'), findsOneWidget);
    expect(find.text('Page 1 of 3'), findsOneWidget);
  });

  testWidgets('previous is disabled on the first page', (tester) async {
    await pump(
      tester,
      PaginationBar(
        page: 0,
        pageSize: 10,
        totalItems: 23,
        onPageChanged: (_) {},
      ),
    );

    final previous = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );

    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);
  });

  testWidgets('next is disabled on the last page', (tester) async {
    await pump(
      tester,
      PaginationBar(
        page: 2,
        pageSize: 10,
        totalItems: 23,
        onPageChanged: (_) {},
      ),
    );

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );

    expect(next.onPressed, isNull);
  });

  testWidgets('tapping next reports the next page', (tester) async {
    int? requested;

    await pump(
      tester,
      PaginationBar(
        page: 1,
        pageSize: 10,
        totalItems: 23,
        onPageChanged: (page) => requested = page,
      ),
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    await tester.pump();

    expect(requested, 2);
  });

  testWidgets('renders nothing when there are no items', (tester) async {
    await pump(
      tester,
      PaginationBar(
        page: 0,
        pageSize: 10,
        totalItems: 0,
        onPageChanged: (_) {},
      ),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('Showing'), findsNothing);
  });
}
