import '../models/stock_transfer.dart';
import 'api_service.dart';

class StockTransferService {
  final ApiService _apiService;

  StockTransferService(this._apiService);

  Future<StockTransfer> createTransfer({
    required int productVariantId,
    required int fromLocationId,
    required int toLocationId,
    required int quantity,
  }) async {
    final data = await _apiService.post('/api/StockTransfers', {
      'productVariantId': productVariantId,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
      'quantity': quantity,
    });

    return StockTransfer.fromJson(data);
  }

  Future<StockTransfer> getTransfer(int id) async {
    final data = await _apiService.get('/api/StockTransfers/$id');

    return StockTransfer.fromJson(data);
  }

  Future<List<StockTransfer>> getTransfers({
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
        ? '/api/StockTransfers'
        : '/api/StockTransfers?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return (data as List).map((json) => StockTransfer.fromJson(json)).toList();
  }
}
