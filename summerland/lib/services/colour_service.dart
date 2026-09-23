import '../models/colour.dart';
import 'api_service.dart';

class ColourService {
  final ApiService _apiService;

  ColourService(this._apiService);

  Future<List<Colour>> getColours() async {
    final data = await _apiService.get('/api/Colours');

    return (data as List)
        .map((json) => Colour.fromJson(json))
        .toList();
  }

  Future<Colour> createColour(String name) async {
    final data = await _apiService.post(
      '/api/Colours',
      {
        'name': name,
      },
    );

    return Colour.fromJson(data);
  }

  Future<Colour> updateColour(
      int id,
      String name,
      ) async {
    final data = await _apiService.put(
      '/api/Colours/$id',
      {
        'name': name,
      },
    );

    return Colour.fromJson(data);
  }
}