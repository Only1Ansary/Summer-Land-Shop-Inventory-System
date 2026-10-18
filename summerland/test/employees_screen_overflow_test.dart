import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/employees/employees_screen.dart';
import 'package:summerland/services/api_service.dart';

const _employees = [
  {
    'id': 1,
    'name': 'Ahmed Mohamed Abdelrahman Hassan',
    'salary': 4000,
    'target': 20000,
    'bonus': 250,
    'bonusType': 0,
    'achievedTarget': false,
    'totalSales': 12000,
    'paidThisMonth': 1500,
    'leftToPay': 2750,
  },
  {
    'id': 2,
    'name': 'Mona Adel Hussien',
    'salary': 5000,
    'target': 15000,
    'bonus': 10,
    'bonusType': 1,
    'achievedTarget': true,
    'totalSales': 22000,
    'paidThisMonth': 4000,
    'leftToPay': 1200,
  },
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        jsonEncode(_employees),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  testWidgets('employee cards fit a 360x690 phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EmployeesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Mona Adel Hussien'), findsOneWidget);

    final overflow = tester.takeException();
    expect(
      overflow,
      isNull,
      reason: 'Employees screen overflowed on a phone: $overflow',
    );
  });

  testWidgets('employee cards fit a narrow 360x560 phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EmployeesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ahmed Mohamed Abdelrahman Hassan'), findsOneWidget);

    final overflow = tester.takeException();
    expect(
      overflow,
      isNull,
      reason: 'Employees screen overflowed on a phone: $overflow',
    );
  });

  testWidgets('wider widths keep the header on one line without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final size in const [Size(600, 900), Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MaterialApp(home: EmployeesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Mona Adel Hussien'), findsOneWidget);

      final overflow = tester.takeException();
      expect(
        overflow,
        isNull,
        reason: 'Employees screen overflowed at $size: $overflow',
      );
    }
  });
}
