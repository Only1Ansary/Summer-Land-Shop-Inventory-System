class StockTransferItem {
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final int quantity;

  StockTransferItem({
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.quantity,
  });

  factory StockTransferItem.fromJson(Map<String, dynamic> json) {
    return StockTransferItem(
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'] ?? '',
      productName: json['productName'] ?? '',
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      quantity: json['quantity'] ?? 0,
    );
  }

  String get displayName {
    final parts = <String>[
      productName,
      if (sizeName != null) sizeName!,
      if (colourName != null) colourName!,
    ];

    return parts.join(' - ');
  }
}

class StockTransfer {
  final int id;
  final int fromLocationId;
  final String fromLocationName;
  final int toLocationId;
  final String toLocationName;
  final int totalQuantity;
  final DateTime createdAt;
  final List<StockTransferItem> items;

  StockTransfer({
    required this.id,
    required this.fromLocationId,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationName,
    required this.totalQuantity,
    required this.createdAt,
    required this.items,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'],
      fromLocationId: json['fromLocationId'],
      fromLocationName: json['fromLocationName'],
      toLocationId: json['toLocationId'],
      toLocationName: json['toLocationName'],
      totalQuantity: json['totalQuantity'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      items: ((json['items'] as List?) ?? const [])
          .map((item) => StockTransferItem.fromJson(item))
          .toList(),
    );
  }
}
