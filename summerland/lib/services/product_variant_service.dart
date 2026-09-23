import '../models/product_variant.dart';
import 'api_service.dart';

class ProductVariantService {
  final ApiService _apiService;

  ProductVariantService(this._apiService);

  Future<List<ProductVariant>> getVariants() async {
    final data = await _apiService.get(
      '/api/ProductVariants',
    );

    return (data as List)
        .map(
          (json) => ProductVariant.fromJson(json),
    )
        .toList();
  }

  Future<ProductVariant> getVariant(int id) async {
    final data = await _apiService.get(
      '/api/ProductVariants/$id',
    );

    return ProductVariant.fromJson(data);
  }

  Future<ProductVariant> createVariant({
    required int productId,
    int? sizeId,
    int? colourId,
    required int barcodeType,
    String? barcode,
    required double price,
    required int lowStockThreshold,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'sizeId': sizeId,
      'colourId': colourId,
      'barcodeType': barcodeType,
      'price': price,
      'lowStockThreshold': lowStockThreshold,
    };

    // Manufacturer barcode فقط يحتاج قيمة
    if (barcodeType == 2) {
      body['barcode'] = barcode;
    }

    final data = await _apiService.post(
      '/api/ProductVariants',
      body,
    );

    return ProductVariant.fromJson(data);
  }

  Future<void> updateVariant({
    required int id,
    int? sizeId,
    int? colourId,
    String? barcode,
    required double price,
    required int lowStockThreshold,
  }) async {
    await _apiService.put(
      '/api/ProductVariants/$id',
      {
        'sizeId': sizeId,
        'colourId': colourId,
        'barcode': barcode,
        'price': price,
        'lowStockThreshold': lowStockThreshold,
      },
    );
  }

  Future<void> deleteVariant(int id) async {
    await _apiService.delete(
      '/api/ProductVariants/$id',
    );
  }
}