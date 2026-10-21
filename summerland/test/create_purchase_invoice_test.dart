import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summerland/screens/purchases/create_purchase_invoice_screen.dart';
import 'package:summerland/services/api_service.dart';

const _categories = [
  {'id': 1, 'name': 'Shirts'},
  {'id': 2, 'name': 'Shoes'},
];

void main() {
  Map<String, dynamic>? created;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    created = null;
    ApiService.clientOverride = MockClient((request) async {
      final path = request.url.path;

      // Invoice reads/writes: round-trip a minimal fees-only invoice.
      if (path.contains('/api/PurchaseInvoices')) {
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;

          final fees = (body['fees'] as List?) ?? const <Object?>[];
          final totalPaid = (body['totalPaid'] as num?)?.toDouble() ?? 0;

          // Mirror the backend for a fees-only invoice: paid fees are cost,
          // unpaid fees are debt.
          final paidFees = fees
              .where((fee) => (fee as Map)['isPaid'] == true)
              .fold<double>(
                0,
                (sum, fee) => sum + ((fee as Map)['amount'] as num).toDouble(),
              );
          final unpaidFees = fees
              .where((fee) => (fee as Map)['isPaid'] != true)
              .fold<double>(
                0,
                (sum, fee) => sum + ((fee as Map)['amount'] as num).toDouble(),
              );

          created = {
            'id': 1,
            'supplierName': body['supplierName'] ?? 'Acme',
            'date': body['date'] ?? '2024-01-01T00:00:00.000',
            'createdAt': '2024-01-01T00:00:00.000',
            'totalCost': paidFees,
            'totalPaid': totalPaid + paidFees,
            'debt': unpaidFees,
            'items': <Object?>[],
            'fees': fees,
            'returns': <Object?>[],
          };

          return http.Response(
            jsonEncode(created),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // GET by id: replay the created invoice.
        return http.Response(
          jsonEncode(created ?? const <String, dynamic>{}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode(_categories),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: CreatePurchaseInvoiceScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addFee(
    WidgetTester tester,
    String description,
    String amount, {
    bool paid = false,
  }) async {
    await tester.tap(find.text('Add Fee'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), description);
    await tester.enterText(fields.at(1), amount);

    if (paid) {
      await tester.tap(find.text('Already paid'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an invoice with no items and no fees', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Supplier Name'),
      'Acme',
    );
    await tester.pumpAndSettle();

    // Totals bar (and its Create button) is hidden while the invoice is empty.
    expect(find.text('Create Purchase Invoice'), findsNothing);
  });

  testWidgets('an unpaid fee becomes supplier debt', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Supplier Name'),
      'Acme',
    );
    await tester.pumpAndSettle();

    // No items are owed to the supplier, so nothing can be paid.
    await tester.enterText(find.widgetWithText(TextField, 'Total Paid'), '0');
    await tester.pumpAndSettle();

    await addFee(tester, 'Shipping', '150');

    // No items, but a fee makes the invoice valid and shows the create button.
    expect(find.text('Items: 0'), findsOneWidget);
    expect(find.text('Fees unpaid: 1'), findsOneWidget);

    final createButton = find.widgetWithText(
      FilledButton,
      'Create Purchase Invoice',
    );
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Reached the show screen for the created invoice.
    expect(find.textContaining('Purchase Invoice #'), findsWidgets);
    // Unpaid fee: owed to the supplier, shown as debt only.
    expect(find.text('Debt'), findsOneWidget);
    expect(find.text('-150.00 EGP'), findsOneWidget);
  });

  testWidgets('a paid fee is added to the total cost, not debt', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Supplier Name'),
      'Acme',
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Total Paid'), '0');
    await tester.pumpAndSettle();

    await addFee(tester, 'Shipping', '150', paid: true);

    expect(find.text('Items: 0'), findsOneWidget);
    expect(find.text('Fees paid: 1'), findsOneWidget);

    final createButton = find.widgetWithText(
      FilledButton,
      'Create Purchase Invoice',
    );
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Purchase Invoice #'), findsWidgets);
    // Paid fee: counted in the total cost, and nothing is owed.
    expect(find.text('-150.00 EGP'), findsNothing);
  });
}
