import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:summerland/models/supplier.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/purchase_invoice_service.dart';
import 'package:summerland/services/supplier_service.dart';

Map<String, dynamic> _invoiceResponse({int method = 0}) => {
  'id': 7,
  'supplierId': 3,
  'supplierName': 'Acme',
  'date': '2026-11-23T10:00:00.000Z',
  'createdAt': '2026-11-23T10:00:01.000Z',
  'totalCost': 1000,
  'totalPaid': 400,
  'paymentMethod': method,
  'invoiceDebt': 600,
  'supplierTotalDebt': 600,
  'items': [],
  'fees': [],
  'returns': [],
};

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = <http.Request>[];
    ApiService.clientOverride = MockClient((request) async {
      requests.add(request);

      if (request.url.path == '/api/PurchaseInvoices' &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse(_invoiceResponse(method: body['paymentMethod']));
      }

      return _jsonResponse(<String, dynamic>{});
    });
  });

  tearDown(() => ApiService.clientOverride = null);

  test('creating a purchase invoice sends and parses the payment method',
      () async {
    final service = PurchaseInvoiceService(ApiService());

    final invoice = await service.createPurchaseInvoice(
      supplierName: 'Acme',
      date: DateTime.utc(2026, 11, 23),
      totalPaid: 400,
      paymentMethod: 1,
      discount: 0,
      items: const [],
    );

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['paymentMethod'], 1);
    expect(invoice.paymentMethod, 1);
  });

  test('per-invoice purchase payment sends the chosen method', () async {
    final service = PurchaseInvoiceService(ApiService());

    await service.payDebt(invoiceId: 7, amount: 250, method: 2);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.url.path, '/api/PurchaseInvoices/7/pay');
    expect(body['amount'], 250);
    expect(body['method'], 2);
  });

  test('supplier debt payment sends the chosen method', () async {
    final service = SupplierService(ApiService());

    await service.payDebt(supplierId: 3, amount: 500, method: 3);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.url.path, '/api/Supplier/3/pay');
    expect(body['amount'], 500);
    expect(body['method'], 3);
  });

  test('supplier responses parse invoice and payment methods', () {
    final supplier = Supplier.fromJson({
      'id': 3,
      'supplierName': 'Acme',
      'debt': 100,
      'purchaseInvoices': [
        {
          'id': 7,
          'totalCost': 1000,
          'totalPaid': 400,
          'debt': 600,
          'paymentMethod': 1,
        },
      ],
    });

    final payment = SupplierPayment.fromJson({
      'id': 9,
      'amount': 250,
      'paidAt': '2026-11-23T10:00:00Z',
      'purchaseInvoiceId': 7,
      'method': 2,
    });

    expect(supplier.purchaseInvoices.single.paymentMethod, 1);
    expect(payment.method, 2);
  });
}
