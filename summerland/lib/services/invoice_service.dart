import '../models/invoice.dart';
import 'api_service.dart';

class InvoiceService {
  final ApiService _apiService;

  InvoiceService(this._apiService);

  Future<List<Invoice>> getInvoices({DateTime? from, DateTime? to}) async {
    final query = <String>[];

    if (from != null) {
      query.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    }

    if (to != null) {
      query.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    }

    final endpoint = query.isEmpty
        ? '/api/SaleInvoices'
        : '/api/SaleInvoices?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return (data as List).map((json) => Invoice.fromJson(json)).toList();
  }

  Future<Invoice> createInvoice({
    required int locationId,
    required int employeeId,
    required List<Map<String, dynamic>> items,
    required String customerPhone,
    String? customerName,
    double paidAmount = 0.0,
    int paymentMethod = 0,
    double discountAmount = 0.0,
    double discountPercent = 0.0,
  }) async {
    final data = await _apiService.post('/api/SaleInvoices', {
      'locationId': locationId,
      'employeeId': employeeId,
      'customerPhone': customerPhone.trim(),
      'customerName': customerName?.trim(),
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'items': items,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
    });

    return Invoice.fromJson(data);
  }

  Future<Invoice> getInvoice(int id) async {
    final data = await _apiService.get('/api/SaleInvoices/$id');

    return Invoice.fromJson(data);
  }

  /// Records a later payment against an existing invoice.
  Future<Invoice> payInvoice({
    required int invoiceId,
    required double amount,
    required int method,
  }) async {
    final data = await _apiService.post('/api/SaleInvoices/$invoiceId/payments', {
      'amount': amount,
      'method': method,
    });

    return Invoice.fromJson(data);
  }
}
