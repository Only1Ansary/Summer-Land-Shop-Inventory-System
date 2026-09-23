class StockTransfer {
  final int id;
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final int fromLocationId;
  final String fromLocationName;
  final int toLocationId;
  final String toLocationName;
  final int quantity;
  final DateTime createdAt;

  StockTransfer({
    required this.id,
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.fromLocationId,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationName,
    required this.quantity,
    required this.createdAt,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'],
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      fromLocationId: json['fromLocationId'],
      fromLocationName: json['fromLocationName'],
      toLocationId: json['toLocationId'],
      toLocationName: json['toLocationName'],
      quantity: json['quantity'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}