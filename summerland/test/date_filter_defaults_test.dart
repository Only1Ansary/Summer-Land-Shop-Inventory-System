import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/invoices/search_sale_invoices_screen.dart';
import 'package:summerland/screens/purchases/search_purchase_invoices_screen.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/cache_store.dart';
import 'package:summerland/services/connectivity_service.dart';
import 'package:summerland/ui/app_widgets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheStore.instance.load();
    await CacheStore.instance.clear();
    ConnectivityService.instance.resetForTest();
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    ApiService.clientOverride = null;
    ConnectivityService.instance.resetForTest();
  });

  DateTime _today() {
    final now = nowInAppTimeZone();

    return DateTime(now.year, now.month, now.day);
  }

  group('default date filters', () {
    test('from and to both default to today at midnight', () {
      final from = defaultFilterFromDate();
      final to = defaultFilterToDate();

      expect(from, _today());
      expect(to, _today());
      expect(from, to);
      expect(from.hour, 0);
      expect(to.hour, 0);

      final today = _today();
      final start = inAppTimeZone(filterFromUtc(from));
      final end = inAppTimeZone(filterToUtc(to));

      expect(DateTime(start.year, start.month, start.day), today);
      expect(start.hour, 0);
      expect(
        <int>[end.year, end.month, end.day, end.hour, end.minute, end.second],
        <int>[today.year, today.month, today.day, 23, 59, 59],
      );
    });
  });

  group('date filter hints', () {
    testWidgets('DateFilterBar always shows From and To above the dates',
        (tester) async {
      var fromTaps = 0;
      var toTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateFilterBar(
              fromLabel: '26/11/2026',
              toLabel: '26/11/2026',
              onFrom: () => fromTaps++,
              onTo: () => toTaps++,
            ),
          ),
        ),
      );

      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('26/11/2026'), findsNWidgets(2));

      final buttons = find.byType(OutlinedButton);
      expect(buttons, findsNWidgets(2));
      await tester.tap(buttons.at(0));
      await tester.tap(buttons.at(1));

      expect(fromTaps, 1);
      expect(toTaps, 1);
    });

    testWidgets('sale invoice search labels both date buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: SearchSaleInvoicesScreen()));
      await tester.pumpAndSettle();

      final today = _today();
      final label = '${today.day}/${today.month}/${today.year}';

      expect(find.text('From date'), findsOneWidget);
      expect(find.text('To date'), findsOneWidget);
      expect(find.text(label), findsNWidgets(2));
    });

    testWidgets('purchase invoice search labels both date buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: SearchPurchaseInvoicesScreen()),
      );
      await tester.pumpAndSettle();

      final today = _today();
      final label = '${today.day}/${today.month}/${today.year}';

      expect(find.text('From date'), findsOneWidget);
      expect(find.text('To date'), findsOneWidget);
      expect(find.text(label), findsNWidgets(2));
    });
  });
}
