import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/reports/best_selling_report_screen.dart';
import 'package:summerland/services/api_service.dart';

void main() {
  print('START');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clientOverride = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/Categories') {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }
      if (path == '/api/Reports/best-selling') {
        return http.Response(jsonEncode({
          'from': '2026-01-01T00:00:00.000',
          'to': '2026-01-02T00:00:00.000',
          'items': [
            {
              'productId': 1,
              'modelNumber': 'MODEL',
              'productName': 'Product',
              'totalQuantitySold': 10,
              'totalSales': 12345.67,
            }
          ],
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('not found', 404);
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  testWidgets('best selling 360x560', (tester) async {
    print('BODY START');
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: BestSellingReportScreen()));
    await tester.pumpAndSettle();
    print('BODY END');
    final ex = tester.takeException();
    print('EX TYPE: ${ex.runtimeType}');
    if (ex is FlutterError) {
      for (final d in ex.diagnostics) {
        print('DIAG: $d');
      }
    }
    print('STACK: ${ex is Error ? ex.stackTrace : 'none'}');
    print('EX: $ex');
  });
}
