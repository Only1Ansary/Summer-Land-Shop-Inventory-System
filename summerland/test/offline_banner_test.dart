import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/services/connectivity_service.dart';
import 'package:summerland/ui/app_widgets.dart';

void main() {
  tearDown(() => ConnectivityService.instance.resetForTest());

  testWidgets('the banner is hidden while online', (tester) async {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.instance.online.value = true;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineBanner())),
    );

    expect(find.textContaining('No connection'), findsNothing);
  });

  testWidgets('the banner appears when the server is unreachable', (
    tester,
  ) async {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.instance.online.value = false;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineBanner())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing the last loaded data'), findsOneWidget);
  });

  testWidgets('the banner disappears when the server comes back', (
    tester,
  ) async {
    ConnectivityService.instance.resetForTest();
    ConnectivityService.instance.online.value = false;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineBanner())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing the last loaded data'), findsOneWidget);

    ConnectivityService.instance.online.value = true;
    await tester.pumpAndSettle();

    expect(find.textContaining('No connection'), findsNothing);
  });
}
