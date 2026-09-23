import '../models/size_model.dart';
import 'api_service.dart';

class SizeService {
  final ApiService _apiService;

  SizeService(this._apiService);

  Future<List<SizeModel>> getSizes() async {
    final data = await _apiService.get('/api/Sizes');

    return (data as List)
        .map((json) => SizeModel.fromJson(json))
        .toList();
  }

  Future<SizeModel> createSize(String name) async {
    final data = await _apiService.post(
      '/api/Sizes',
      {
        'name': name,
      },
    );

    return SizeModel.fromJson(data);
  }

  Future<SizeModel> updateSize(
      int id,
      String name,
      ) async {
    final data = await _apiService.put(
      '/api/Sizes/$id',
      {
        'name': name,
      },
    );

    return SizeModel.fromJson(data);
  }
}