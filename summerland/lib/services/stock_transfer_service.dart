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

  Future<List<StockTransfer>> getTransfers() async {
    final data = await _apiService.get('/api/StockTransfers');

    return (data as List)
        .map((json) => StockTransfer.fromJson(json))
        .toList();
  }
}