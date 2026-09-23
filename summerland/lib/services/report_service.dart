import '../models/reports/sales_report.dart';
import '../models/reports/inventory_report.dart';
import '../models/reports/low_stock_report.dart';
import '../models/reports/stock_movement_report.dart';
import '../models/reports/best_selling_report.dart';
import 'api_service.dart';

class ReportService {
  final ApiService _apiService;

  ReportService(this._apiService);

  String _date(DateTime date) {
    return date.toIso8601String();
  }

  Future<SalesReport> getSalesReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String>[];

    if (from != null) {
      query.add('from=${Uri.encodeComponent(_date(from))}');
    }

    if (to != null) {
      query.add('to=${Uri.encodeComponent(_date(to))}');
    }

    final endpoint = query.isEmpty
        ? '/api/Reports/sales'
        : '/api/Reports/sales?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return SalesReport.fromJson(data);
  }

  Future<InventoryReport> getInventoryReport() async {
    final data = await _apiService.get('/api/Reports/inventory');

    return InventoryReport.fromJson(data);
  }

  Future<LowStockReport> getLowStockReport() async {
    final data = await _apiService.get('/api/Reports/low-stock');

    return LowStockReport.fromJson(data);
  }

  Future<StockMovementReport> getStockMovementReport({
    DateTime? from,
    DateTime? to,
    int? locationId,
    int? productVariantId,
  }) async {
    final query = <String>[];

    if (from != null) {
      query.add('from=${Uri.encodeComponent(_date(from))}');
    }

    if (to != null) {
      query.add('to=${Uri.encodeComponent(_date(to))}');
    }

    if (locationId != null) {
      query.add('locationId=$locationId');
    }

    if (productVariantId != null) {
      query.add('productVariantId=$productVariantId');
    }

    final endpoint = query.isEmpty
        ? '/api/Reports/stock-movements'
        : '/api/Reports/stock-movements?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return StockMovementReport.fromJson(data);
  }

  Future<BestSellingReport> getBestSellingReport({
    DateTime? from,
    DateTime? to,
    int? locationId,
  }) async {
    final query = <String>[];

    if (from != null) {
      query.add('from=${Uri.encodeComponent(_date(from))}');
    }

    if (to != null) {
      query.add('to=${Uri.encodeComponent(_date(to))}');
    }

    if (locationId != null) {
      query.add('locationId=$locationId');
    }

    final endpoint = query.isEmpty
        ? '/api/Reports/best-selling'
        : '/api/Reports/best-selling?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return BestSellingReport.fromJson(data);
  }
}