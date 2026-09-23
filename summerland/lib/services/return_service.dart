import '../models/return_model.dart';
import 'api_service.dart';

class ReturnService {
  final ApiService _apiService;

  ReturnService(this._apiService);

  Future<ReturnModel> createReturn({
    required int invoiceId,
    required int productVariantId,
    required int quantity,
    required int stockLocationId,
    required String reason,
  }) async {
    final data = await _apiService.post('/api/Returns', {
      'invoiceId': invoiceId,
      'productVariantId': productVariantId,
      'quantity': quantity,
      'stockLocationId': stockLocationId,
      'reason': reason,
    });

    return ReturnModel.fromJson(data);
  }

  Future<ReturnModel> getReturn(int id) async {
    final data = await _apiService.get('/api/Returns/$id');

    return ReturnModel.fromJson(data);
  }

  Future<List<ReturnModel>> getReturns() async {
    final data = await _apiService.get('/api/Returns');

    return (data as List).map((json) => ReturnModel.fromJson(json)).toList();
  }
}
