import '../models/inventory.dart';
import 'api_service.dart';

class InventoryService {
  final ApiService _apiService;

  InventoryService(this._apiService);

  Future<List<Inventory>> getVariantInventory(
      int variantId,
      ) async {
    final data = await _apiService.get(
      '/api/Inventory/variant/$variantId',
    );

    return (data as List)
        .map(
          (json) => Inventory.fromJson(json),
    )
        .toList();
  }

  Future<Inventory> addInventory({
    required int productVariantId,
    required int locationId,
    required int quantity,
  }) async {
    final data = await _apiService.post(
      '/api/Inventory',
      {
        'productVariantId': productVariantId,
        'locationId': locationId,
        'quantity': quantity,
      },
    );

    return Inventory.fromJson(data);
  }
}