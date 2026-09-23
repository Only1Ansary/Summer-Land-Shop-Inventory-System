class LowStockReport {
  final int count;
  final List<LowStockItem> items;

  LowStockReport({
    required this.count,
    required this.items,
  });

  factory LowStockReport.fromJson(Map<String, dynamic> json) {
    return LowStockReport(
      count: json['count'],
      items: (json['items'] as List)
          .map((item) => LowStockItem.fromJson(item))
          .toList(),
    );
  }
}

class LowStockItem {
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final String barcode;
  final double price;
  final int lowStockThreshold;
  final int totalQuantity;
  final List<LowStockLocation> locations;

  LowStockItem({
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.barcode,
    required this.price,
    required this.lowStockThreshold,
    required this.totalQuantity,
    required this.locations,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    return LowStockItem(
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      barcode: json['barcode'],
      price: (json['price'] as num).toDouble(),
      lowStockThreshold: json['lowStockThreshold'],
      totalQuantity: json['totalQuantity'],
      locations: (json['locations'] as List)
          .map((item) => LowStockLocation.fromJson(item))
          .toList(),
    );
  }
}

class LowStockLocation {
  final int locationId;
  final String locationName;
  final int quantity;

  LowStockLocation({
    required this.locationId,
    required this.locationName,
    required this.quantity,
  });

  factory LowStockLocation.fromJson(Map<String, dynamic> json) {
    return LowStockLocation(
      locationId: json['locationId'],
      locationName: json['locationName'],
      quantity: json['quantity'],
    );
  }
}