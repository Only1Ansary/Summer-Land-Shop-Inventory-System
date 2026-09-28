import '../models/supplier.dart';
import 'api_service.dart';

class SupplierService {
  static const String _base = '/api/Supplier';

  final ApiService _apiService;

  SupplierService(this._apiService);

  Future<List<Supplier>> getSuppliers() async {
    final data = await _apiService.get(_base);

    return (data as List)
        .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier(String name) async {
    final data = await _apiService.post(
      _base,
      {
        'supplierName': name,
      },
    );

    return Supplier.fromJson(data as Map<String, dynamic>);
  }

  Future<Supplier> updateSupplier(
    int id, {
    required String supplierName,
    required double debt,
  }) async {
    final data = await _apiService.put(
      '$_base/$id',
      {
        'supplierName': supplierName,
        'debt': debt,
      },
    );

    return Supplier.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSupplier(int id) async {
    await _apiService.delete('$_base/$id');
  }

  Future<void> payDebt({
    required int supplierId,
    required double amount,
  }) async {
    await _apiService.post(
      '$_base/$supplierId/pay',
      {'amount': amount},
    );
  }
}