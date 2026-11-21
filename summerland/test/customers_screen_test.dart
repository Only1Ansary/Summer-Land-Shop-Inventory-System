import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/customers/customers_screen.dart';
import 'package:summerland/services/api_service.dart';

Map<String, Object?> _customer() {
  return {
    'id': 4,
    'phoneNumber': '0123456789',
    'name': 'Mona',
    'totalPaid': 180.0,
    'totalDebt': 70.0,
    'invoiceCount': 2,
  };
}

Map<String, Object?> _details() {
  return {
    'id': 4,
    'phoneNumber': '0123456789',
    'name': 'Mona',
    'totalPaid': 180.0,
    'totalDebt': 70.0,
    'invoiceCount': 2,
    'unpaidInvoiceCount': 1,
    'createdAt': '2026-10-01T10:00:00Z',
    'invoices': [
      {
        'id': 12,
        'createdAt': '2026-10-13T10:00:00Z',
        'locationName': 'Main Branch',
        'totalAmount': 100.0,
        'paidAmount': 30.0,
        'remainingAmount': 70.0,
      },
      {
        'id': 11,
        'createdAt': '2026-10-02T10:00:00Z',
        'locationName': 'Main Branch',
        'totalAmount': 200.0,
        'paidAmount': 200.0,
        'remainingAmount': 0.0,
      },
    ],
    'payments': [
      {
        'id': 9,
        'customerId': 4,
        'saleInvoiceId': 12,
        'amount': 30.0,
        'method': 2,
        'paidAt': '2026-10-14T09:00:00Z',
      },
    ],
  };
}

Map<String, Object?> _paidDetails() {
  return {
    ..._details(),
    'totalPaid': 230.0,
    'totalDebt': 20.0,
    'invoices': [
      {
        'id': 12,
        'createdAt': '2026-10-13T10:00:00Z',
        'locationName': 'Main Branch',
        'totalAmount': 100.0,
        'paidAmount': 80.0,
        'remainingAmount': 20.0,
      },
      {
        'id': 11,
        'createdAt': '2026-10-02T10:00:00Z',
        'locationName': 'Main Branch',
        'totalAmount': 200.0,
        'paidAmount': 200.0,
        'remainingAmount': 0.0,
      },
    ],
    'payments': [
      ...(_details()['payments'] as List<Object?>),
      {
        'id': 10,
        'customerId': 4,
        'saleInvoiceId': 12,
        'amount': 50.0,
        'method': 0,
        'paidAt': '2026-10-15T09:00:00Z',
      },
    ],
  };
}

void main() {
  String? searchQuery;
  Map<String, dynamic>? capturedPayment;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    searchQuery = null;
    capturedPayment = null;

    ApiService.clientOverride = MockClient((request) async {
      final path = request.url.path;

      if (path == '/api/Customers' && request.method == 'GET') {
        searchQuery = request.url.queryParameters['search'];

        return http.Response(
          jsonEncode([_customer()]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path == '/api/Customers/4/details' && request.method == 'GET') {
        return http.Response(
          jsonEncode(_details()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path == '/api/Customers/4/payments' && request.method == 'POST') {
        capturedPayment = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode(_paidDetails()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('[]', 404);
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> searchAndOpen(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('customer-search')), 'Mona');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('customer-result-4')));
    await tester.pumpAndSettle();
  }

  testWidgets('search starts empty and a selected customer shows their account',
      (tester) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CustomersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Search for a customer'), findsOneWidget);
    expect(find.text('Mona'), findsNothing);
    expect(searchQuery, isNull);

    await searchAndOpen(tester);

    expect(searchQuery, 'Mona');
    expect(find.text('Total invoices'), findsOneWidget);
    expect(find.text('Unpaid invoices'), findsOneWidget);
    expect(find.text('Total debt'), findsWidgets);
    expect(find.text('70.00 EGP'), findsWidgets);

    expect(find.byKey(const ValueKey('customer-invoice-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-invoice-11')), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-payment-9')), findsOneWidget);
    expect(find.textContaining('InstaPay'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a generic payment posts the amount and method only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CustomersScreen()));
    await tester.pumpAndSettle();

    await searchAndOpen(tester);

    await tester.enterText(
      find.byKey(const Key('customer-payment-amount')),
      '50',
    );
    await tester.tap(find.byKey(const Key('customer-pay-button')));
    await tester.pumpAndSettle();

    expect(capturedPayment, isNotNull);
    expect(capturedPayment!['amount'], 50);
    expect(capturedPayment!['method'], 0);
    expect(capturedPayment!.containsKey('invoiceId'), isFalse);
    expect(find.text('20.00 EGP'), findsWidgets);
    expect(find.byKey(const ValueKey('customer-payment-10')), findsOneWidget);
    expect(find.text('50.00 EGP'), findsOneWidget);
  });
}
