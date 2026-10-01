import '../models/purchase_invoice.dart';
import 'api_service.dart';

class PurchaseInvoiceService {
  final ApiService _apiService;

  PurchaseInvoiceService(this._apiService);

  Future<PurchaseInvoice> createPurchaseInvoice({
    required String supplierName,
    required DateTime date,
    required double totalPaid,
    required double discount,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> fees = const [],
  }) async {
    final data = await _apiService.post(
      '/api/PurchaseInvoices',
      {
        'supplierName': supplierName,
        'date': date.toIso8601String(),
        'totalPaid': totalPaid,
        'discount': discount,
        'items': items,
        'fees': fees,
      },
    );

    return PurchaseInvoice.fromJson(data);
  }

  Future<PurchaseInvoice> getPurchaseInvoice(int id) async {
    final data = await _apiService.get('/api/PurchaseInvoices/$id');

    return PurchaseInvoice.fromJson(data);
  }

  Future<List<PurchaseInvoice>> getPurchaseInvoices({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String>[];

    if (from != null) {
      query.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    }

    if (to != null) {
      query.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    }

    final endpoint = query.isEmpty
        ? '/api/PurchaseInvoices'
        : '/api/PurchaseInvoices?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return (data as List)
        .map((json) => PurchaseInvoice.fromJson(json))
        .toList();
  }

  Future<void> createPurchaseReturn({
    required int invoiceId,
    required String? reason,
    required List<Map<String, dynamic>> items,
  }) async {
    await _apiService.post(
      '/api/PurchaseReturns',
      {
        'purchaseInvoiceId': invoiceId,
        'reason': reason,
        'items': items,
      },
    );
  }

  Future<void> payDebt({
    required int invoiceId,
    required double amount,
  }) async {
    await _apiService.post(
      '/api/PurchaseInvoices/$invoiceId/pay',
      {'amount': amount},
    );
  }
}