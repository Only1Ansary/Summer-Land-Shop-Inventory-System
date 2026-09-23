class StockMovementReport {
  final DateTime from;
  final DateTime to;
  final int movementCount;
  final List<StockMovementReportItem> items;

  StockMovementReport({
    required this.from,
    required this.to,
    required this.movementCount,
    required this.items,
  });

  factory StockMovementReport.fromJson(Map<String, dynamic> json) {
    return StockMovementReport(
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
      movementCount: json['movementCount'],
      items: (json['items'] as List)
          .map((item) => StockMovementReportItem.fromJson(item))
          .toList(),
    );
  }
}

class StockMovementReportItem {
  final int id;
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final int locationId;
  final String locationName;
  final int quantityChange;
  final String reason;
  final DateTime createdAt;

  StockMovementReportItem({
    required this.id,
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.locationId,
    required this.locationName,
    required this.quantityChange,
    required this.reason,
    required this.createdAt,
  });

  factory StockMovementReportItem.fromJson(
      Map<String, dynamic> json,
      ) {
    return StockMovementReportItem(
      id: json['id'],
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      locationId: json['locationId'],
      locationName: json['locationName'],
      quantityChange: json['quantityChange'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}