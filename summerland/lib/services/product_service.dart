import '../models/product.dart';
import 'api_service.dart';

class ProductService {
  final ApiService _apiService;

  ProductService(this._apiService);

  Future<List<Product>> getProducts() async {
    final data = await _apiService.get(
      '/api/Products',
    );

    return (data as List)
        .map(
          (json) => Product.fromJson(json),
    )
        .toList();
  }

  Future<Product> getProduct(int id) async {
    final data = await _apiService.get(
      '/api/Products/$id',
    );

    return Product.fromJson(data);
  }

  Future<Product> createProduct({
    required String modelNumber,
    required String name,
    required int categoryId,
  }) async {
    final data = await _apiService.post(
      '/api/Products',
      {
        'modelNumber': modelNumber,
        'name': name,
        'categoryId': categoryId,
      },
    );

    return Product.fromJson(data);
  }

  Future<void> updateProduct({
    required int id,
    required String modelNumber,
    required String name,
    required int categoryId,
  }) async {
    await _apiService.put(
      '/api/Products/$id',
      {
        'modelNumber': modelNumber,
        'name': name,
        'categoryId': categoryId,
      },
    );
  }

  Future<void> deleteProduct(int id) async {
    await _apiService.delete(
      '/api/Products/$id',
    );
  }

  Future<List<Product>> searchProducts({
    String? query,
    int? categoryId,
    int? sizeId,
    int? colourId,
  }) async {
    final queryParameters = <String, String>{};

    if (query != null && query.trim().isNotEmpty) {
      queryParameters['query'] = query.trim();
    }

    if (categoryId != null) {
      queryParameters['categoryId'] =
          categoryId.toString();
    }

    if (sizeId != null) {
      queryParameters['sizeId'] =
          sizeId.toString();
    }

    if (colourId != null) {
      queryParameters['colourId'] =
          colourId.toString();
    }

    final uri = Uri(
      path: '/api/Products/search',
      queryParameters: queryParameters,
    );

    final data = await _apiService.get(
      uri.toString(),
    );

    return (data as List)
        .map(
          (json) => Product.fromJson(json),
    )
        .toList();
  }
}