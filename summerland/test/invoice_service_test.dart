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
      items: [
        {'productVariantId': 1, 'quantity': 1, 'stockLocationId': 3},
      ],
    );

    expect(method, 'POST');
    expect(path, '/api/SaleInvoices');
    expect(captured!.containsKey('employeeId'), isTrue);
    expect(captured!['employeeId'], 7);
    expect(captured!['locationId'], 3);
    expect(invoice.employeeId, 7);
    expect(invoice.employeeName, 'Mona');
    expect(invoice.totalAmount, 1000.0);

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
  });
}
