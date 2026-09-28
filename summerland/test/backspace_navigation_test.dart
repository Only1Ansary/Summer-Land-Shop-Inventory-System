import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/main.dart';

Widget _app(GlobalKey<NavigatorState> navigatorKey) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(
                      child: TextField(
                        decoration: InputDecoration(hintText: 'Type here'),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    ),
    builder: (context, child) => BackspaceBackShortcuts(
      navigatorKey: navigatorKey,
      child: child!,
    ),
  );
}

Future<void> _pressBackspace(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Backspace pops back to the previous screen',
      (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(_app(navigatorKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await _pressBackspace(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Go'), findsOneWidget);
  });

  testWidgets('Backspace while editing text does not navigate',
      (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(_app(navigatorKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // Focus the text field and type something.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.text('abc'), findsOneWidget);

    // Backspace while editing must delete a character AND not pop the route.
    await _pressBackspace(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Go'), findsNothing);
    expect(find.text('abc'), findsNothing);
    expect(find.text('ab'), findsOneWidget);

    // Once focus leaves the text field, Backspace navigates back.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await _pressBackspace(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Go'), findsOneWidget);
  });

  testWidgets('Backspace at the root does not exit',
      (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(_app(navigatorKey));
    await tester.pumpAndSettle();

    await _pressBackspace(tester);

    expect(find.text('Go'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}