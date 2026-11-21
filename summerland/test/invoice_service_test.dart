import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/invoice.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/invoice_service.dart';

// No widget tests in this file: the Flutter test binding blocks real HTTP,
// so the API payloads are checked against a local listener instead
// (same approach as employee_service_test.dart).
void main() {
  test('creating an invoice sends the employee along with the sale', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;
    Map<String, dynamic>? captured;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;
      captured = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 12,
            'createdAt': '2026-10-13T12:00:00Z',
            'locationId': 3,
            'locationName': 'Main store',
            'employeeId': 7,
            'employeeName': 'Mona',
            'customerId': 4,
            'customerPhone': '0123456789',
            'customerName': 'Mona',
            'customerTotalPaid': 250.0,
            'customerTotalDebt': 750.0,
            'paymentMethod': 1,
            'paidAmount': 250.0,
            'remainingAmount': 750.0,
            'payments': [
              {
                'id': 8,
                'customerId': 4,
                'amount': 250.0,
                'method': 1,
                'paidAt': '2026-10-13T12:00:00Z',
              },
            ],
            'totalAmount': 1000.0,
            'discountAmount': 0.0,
            'discountPercent': null,
            'items': [],
          }),
        );

      await request.response.close();
    });

    final service = InvoiceService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final invoice = await service.createInvoice(
      locationId: 3,
      employeeId: 7,
      customerPhone: '0123456789',
      customerName: 'Mona',
      paidAmount: 250,
      paymentMethod: 1,
      items: [
        {'productVariantId': 1, 'quantity': 1, 'stockLocationId': 3},
      ],
    );

    expect(method, 'POST');
    expect(path, '/api/SaleInvoices');
    expect(captured!.containsKey('employeeId'), isTrue);
    expect(captured!['employeeId'], 7);
    expect(captured!['locationId'], 3);
    expect(captured!['customerPhone'], '0123456789');
    expect(captured!['customerName'], 'Mona');
    expect(captured!['paidAmount'], 250);
    expect(captured!['paymentMethod'], 1);
    expect(invoice.employeeId, 7);
    expect(invoice.employeeName, 'Mona');
    expect(invoice.totalAmount, 1000.0);
    expect(invoice.customerId, 4);
    expect(invoice.customerPhone, '0123456789');
    expect(invoice.customerDisplayName, 'Mona');
    expect(invoice.customerTotalPaid, 250);
    expect(invoice.customerTotalDebt, 750);
    expect(invoice.paymentMethod, 1);
    expect(invoice.paidAmount, 250);
    expect(invoice.remainingAmount, 750);
    expect(invoice.isFullyPaid, isFalse);
    expect(invoice.payments.single.method, 1);
    expect(invoice.payments.single.amount, 250);

    await listener.close(force: true);
  });

  test('an invoice from before employees were tracked parses as none', () {
    final invoice = Invoice.fromJson({
      'id': 9,
      'createdAt': '2026-09-01T09:00:00Z',
      'locationId': 1,
      'locationName': 'Main store',
      'totalAmount': 240.0,
      'discountAmount': 0.0,
      'discountPercent': null,
      'items': [],
    });

    expect(invoice.employeeId, isNull);
    expect(invoice.employeeName, isNull);

    // Customer/payment fields are additive: older sales still parse.
    expect(invoice.customerId, isNull);
    expect(invoice.customerPhone, isNull);
    expect(invoice.customerDisplayName, isNull);
    expect(invoice.paidAmount, 0);
    expect(invoice.remainingAmount, 240);
    expect(invoice.isFullyPaid, isFalse);
    expect(invoice.payments, isEmpty);
  });

  test('recording a later payment posts the amount and method', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;
    Map<String, dynamic>? captured;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;
      captured = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 12,
            'createdAt': '2026-10-13T12:00:00Z',
            'locationId': 3,
            'locationName': 'Main store',
            'customerId': 4,
            'customerPhone': '0123456789',
            'customerName': 'Mona',
            'customerTotalPaid': 400.0,
            'customerTotalDebt': 600.0,
            // Bought on credit: later payments carry their own method.
            'paymentMethod': null,
            'paidAmount': 400.0,
            'remainingAmount': 600.0,
            'payments': [
              {
                'id': 9,
                'customerId': 4,
                'amount': 150.0,
                'method': 2,
                'paidAt': '2026-10-14T09:00:00Z',
              },
            ],
            'totalAmount': 1000.0,
            'discountAmount': 0.0,
            'discountPercent': null,
            'items': [],
          }),
        );

      await request.response.close();
    });

    final service = InvoiceService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final invoice = await service.payInvoice(
      invoiceId: 12,
      amount: 150,
      method: 2,
    );

    expect(method, 'POST');
    expect(path, '/api/SaleInvoices/12/payments');
    expect(captured!['amount'], 150);
    expect(captured!['method'], 2);
    expect(invoice.paidAmount, 400);
    expect(invoice.remainingAmount, 600);
    expect(invoice.paymentMethod, isNull);
    expect(invoice.payments.single.method, 2);

    await listener.close(force: true);
  });
}
