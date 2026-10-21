import '../models/product_variant.dart';
import 'api_service.dart';

class ProductVariantService {
  final ApiService _apiService;

  ProductVariantService(this._apiService);

  Future<List<ProductVariant>> getVariants() async {
    final data = await _apiService.get('/api/ProductVariants');

    return (data as List).map((json) => ProductVariant.fromJson(json)).toList();
  }

  Future<ProductVariant> getVariant(int id) async {
    final data = await _apiService.get('/api/ProductVariants/$id');

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

    final data = await _apiService.post('/api/ProductVariants', body);

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
    await _apiService.put('/api/ProductVariants/$id', {
      'sizeId': sizeId,
      'colourId': colourId,
      'barcode': barcode,
      'price': price,
      'lowStockThreshold': lowStockThreshold,
    });
  }

  Future<void> deleteVariant(int id) async {
    await _apiService.delete('/api/ProductVariants/$id');
  }

  /// Splits the stock of a default variant (no size, no colour) across new
  /// size/colour variants. [splits] maps each target combination to a quantity;
  /// the quantities must total the source variant's stock.
  Future<List<ProductVariant>> splitVariant({
    required int sourceVariantId,
    required List<Map<String, dynamic>> splits,
  }) async {
    final data = await _apiService.post('/api/ProductVariants/split', {
      'sourceVariantId': sourceVariantId,
      'splits': splits,
    });

    return (data as List).map((json) => ProductVariant.fromJson(json)).toList();
  }
}
