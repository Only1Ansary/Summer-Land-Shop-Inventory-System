import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/main.dart';

void main() {
  testWidgets('App builds with navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SummerlandApp());

    await tester.pump();

    // The persistent navigation shell is present.
    expect(find.byType(AppBar), findsWidgets);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'Mobile layout should show the bottom navigation bar.',
    );

    // The home screen title is rendered.
    expect(find.text('Home'), findsWidgets);
  });
}