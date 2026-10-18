import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/reports/sales_report_screen.dart';
import 'package:summerland/services/api_service.dart';

const _salesReport = <String, Object?>{
  'from': '2026-10-18T00:00:00',
  'to': '2026-10-19T00:00:00',
  'invoiceCount': 4,
  'itemsSold': 9,
  'grossSales': 1000.0,
  'itemsReturned': 1,
  'returnsAmount': 50.0,
  'netSales': 950.0,
  'purchaseInvoiceCount': 2,
  'purchaseTotalCost': 400.0,
  'purchaseTotalPaid': 300.0,
  'purchaseDebt': 100.0,
  'employeePaymentCount': 1,
  'employeePaymentTotal': 200.0,
  'supplierCount': 3,
  'supplierDebtTotal': 75.0,
  'profit': 550.0,
  'categorySales': [
    {'categoryName': 'T-Shirts', 'quantitySold': 5, 'amount': 600.0},
    {'categoryName': 'Jeans', 'quantitySold': 4, 'amount': 350.0},
  ],
};

const _sectionTitles = [
  'Revenue',
  'Sales by Category',
  'Sales Activity',
  'Purchases & Cost',
  'Staff Payments',
  'Debts & Suppliers',
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clientOverride = MockClient((request) async {
      return http.Response(
        jsonEncode(_salesReport),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpReport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SalesReportScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('every section starts expanded with its stats visible', (
    tester,
  ) async {
    await pumpReport(tester);

    for (final title in _sectionTitles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    expect(find.text('Gross Sales'), findsOneWidget);
    expect(find.text('T-Shirts'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Purchase Invoices'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Suppliers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a header collapses only that section', (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    expect(find.text('Revenue'), findsOneWidget, reason: 'header stays');
    expect(find.text('Gross Sales'), findsNothing);
    expect(find.text('Net Revenue'), findsNothing);
    expect(find.text('Purchase Invoices'), findsOneWidget);
    expect(find.text('T-Shirts'), findsOneWidget);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    expect(find.text('Gross Sales'), findsOneWidget);

    await tester.tap(find.text('Sales by Category'));
    await tester.pumpAndSettle();

    expect(find.text('Sales by Category'), findsOneWidget);
    expect(find.text('T-Shirts'), findsNothing);
    expect(find.text('Gross Sales'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a collapsed section still fits a phone screen', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SalesReportScreen()));
    await tester.pumpAndSettle();

    final header = find.text('Sales by Category');
    await tester.dragUntilVisible(
      header,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(header);
    await tester.pumpAndSettle();

    expect(find.text('T-Shirts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
