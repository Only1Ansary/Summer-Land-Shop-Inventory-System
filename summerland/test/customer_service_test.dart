import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/customer.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/customer_service.dart';

void main() {
  test('phone lookup URL-encodes the number and parses customer balances',
      () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? query;

    listener.listen((request) async {
      query = request.uri.query;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 4,
            'phoneNumber': '0123456789',
            'name': 'Mona',
            'totalPaid': 250.0,
            'totalDebt': 750.0,
            'invoiceCount': 2,
            'createdAt': '2026-10-01T10:00:00Z',
          }),
        );

      await request.response.close();
    });

    final service = CustomerService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final customer = await service.lookupByPhone('012 345 6789');

    expect(query, 'phone=012%20345%206789');
    expect(customer, isNotNull);
    expect(customer!.id, 4);
    expect(customer.phoneNumber, '0123456789');
    expect(customer.name, 'Mona');
    expect(customer.displayName, 'Mona');
    expect(customer.totalPaid, 250);
    expect(customer.totalDebt, 750);
    expect(customer.invoiceCount, 2);

    await listener.close(force: true);
  });

  test('a customer without a name is labelled by their phone number', () {
    final customer = Customer.fromJson({
      'id': 5,
      'phoneNumber': '0100000000',
      'name': null,
      'totalPaid': 0,
      'totalDebt': 120,
    });

    expect(customer.name, isNull);
    expect(customer.displayName, '0100000000');
    expect(customer.totalDebt, 120);
  });

  test('a new phone number has no customer yet', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    listener.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('null');

      await request.response.close();
    });

    final service = CustomerService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    expect(await service.lookupByPhone('0100000000'), isNull);

    await listener.close(force: true);
  });

  test('partial search uses the search query and parses results', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? path;
    String? query;

    listener.listen((request) async {
      path = request.uri.path;
      query = request.uri.query;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': 4,
              'phoneNumber': '0123456789',
              'name': 'Mona',
              'totalPaid': 250.0,
              'totalDebt': 750.0,
              'invoiceCount': 2,
            },
          ]),
        );

      await request.response.close();
    });

    final service = CustomerService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final results = await service.searchCustomers('Mon a');

    expect(path, '/api/Customers');
    expect(query, 'search=Mon%20a');
    expect(results.single.displayName, 'Mona');
    expect(results.single.totalDebt, 750);

    await listener.close(force: true);
  });

  test('details parse invoices, balances and per-invoice payments', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? path;

    listener.listen((request) async {
      path = request.uri.path;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 4,
            'phoneNumber': '0123456789',
            'name': 'Mona',
            'totalPaid': 230.0,
            'totalDebt': 70.0,
            'invoiceCount': 2,
            'unpaidInvoiceCount': 1,
            'createdAt': '2026-10-01T10:00:00Z',
            'invoices': [
              {
                'id': 11,
                'createdAt': '2026-10-02T10:00:00Z',
                'locationName': 'Main Branch',
                'totalAmount': 200.0,
                'paidAmount': 200.0,
                'remainingAmount': 0.0,
              },
              {
                'id': 12,
                'createdAt': '2026-10-13T10:00:00Z',
                'locationName': 'Main Branch',
                'totalAmount': 100.0,
                'paidAmount': 30.0,
                'remainingAmount': 70.0,
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
          }),
        );

      await request.response.close();
    });

    final service = CustomerService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final details = await service.getCustomerDetails(4);

    expect(path, '/api/Customers/4/details');
    expect(details.displayName, 'Mona');
    expect(details.invoiceCount, 2);
    expect(details.unpaidInvoiceCount, 1);
    expect(details.totalDebt, 70);
    expect(details.invoices.first.isFullyPaid, isTrue);
    expect(details.invoices.last.isFullyPaid, isFalse);
    expect(details.payments.single.saleInvoiceId, 12);
    expect(details.payments.single.method, 2);

    await listener.close(force: true);
  });

  test('a generic payment posts only the amount and method', () async {
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
            'id': 4,
            'phoneNumber': '0123456789',
            'name': 'Mona',
            'totalPaid': 280.0,
            'totalDebt': 20.0,
            'invoiceCount': 2,
            'unpaidInvoiceCount': 1,
            'invoices': [],
            'payments': [],
          }),
        );

      await request.response.close();
    });

    final service = CustomerService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final updated = await service.payCustomer(
      customerId: 4,
      amount: 50,
      method: 2,
    );

    expect(method, 'POST');
    expect(path, '/api/Customers/4/payments');
    expect(captured!['amount'], 50);
    expect(captured!['method'], 2);
    expect(updated.totalPaid, 280);
    expect(updated.totalDebt, 20);

    await listener.close(force: true);
  });
}
