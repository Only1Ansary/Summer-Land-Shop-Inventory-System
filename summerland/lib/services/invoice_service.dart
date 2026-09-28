import '../models/invoice.dart';
import 'api_service.dart';

class InvoiceService {
  final ApiService _apiService;

  InvoiceService(this._apiService);

  Future<List<Invoice>> getInvoices() async {
    final data = await _apiService.get(
      '/api/SaleInvoices',
    );

    return (data as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }

  Future<Invoice> createInvoice({
    required int locationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _apiService.post(
      '/api/SaleInvoices',
      {
        'locationId': locationId,
        'items': items,
      },
    );

    return Invoice.fromJson(data);
  }

  Future<Invoice> getInvoice(int id) async {
    final data = await _apiService.get(
      '/api/SaleInvoices/$id',
    );

    return Invoice.fromJson(data);
  }
}