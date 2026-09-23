import '../models/category.dart';
import 'api_service.dart';

class CategoryService {
  final ApiService _apiService;

  CategoryService(this._apiService);

  Future<List<Category>> getCategories() async {
    final data = await _apiService.get('/api/Categories');

    return (data as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  Future<Category> createCategory(String name) async {
    final data = await _apiService.post(
      '/api/Categories',
      {
        'name': name,
      },
    );

    return Category.fromJson(data);
  }

  Future<Category> updateCategory(
      int id,
      String name,
      ) async {
    final data = await _apiService.put(
      '/api/Categories/$id',
      {
        'name': name,
      },
    );

    return Category.fromJson(data);
  }
}