import '../models/location.dart';
import 'api_service.dart';

class LocationService {
  final ApiService _apiService;

  LocationService(this._apiService);

  Future<List<Location>> getLocations() async {
    final data =
    await _apiService.get('/api/Locations');

    return (data as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  Future<Location> createLocation(String name) async {
    final data = await _apiService.post(
      '/api/Locations',
      {
        'name': name,
      },
    );

    return Location.fromJson(data);
  }

  Future<Location> updateLocation(
      int id,
      String name,
      ) async {
    final data = await _apiService.put(
      '/api/Locations/$id',
      {
        'name': name,
      },
    );

    return Location.fromJson(data);
  }
}