class InventoryReport {
  final int totalVariants;
  final int totalQuantity;
  final double totalInventoryValue;
  final int lowStockVariants;
  final List<InventoryReportItem> items;

  InventoryReport({
    required this.totalVariants,
    required this.totalQuantity,
    required this.totalInventoryValue,
    required this.lowStockVariants,
    required this.items,
  });

  factory InventoryReport.fromJson(Map<String, dynamic> json) {
    return InventoryReport(
      totalVariants: json['totalVariants'],
      totalQuantity: json['totalQuantity'],
      totalInventoryValue:
      (json['totalInventoryValue'] as num).toDouble(),
      lowStockVariants: json['lowStockVariants'],
      items: (json['items'] as List)
          .map((item) => InventoryReportItem.fromJson(item))
          .toList(),
    );
  }
}

class InventoryReportItem {
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final String barcode;
  final double price;
  final int lowStockThreshold;
  final int totalQuantity;
  final double inventoryValue;
  final bool isLowStock;
  final List<InventoryLocation> locations;

  InventoryReportItem({
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.barcode,
    required this.price,
    required this.lowStockThreshold,
    required this.totalQuantity,
    required this.inventoryValue,
    required this.isLowStock,
    required this.locations,
  });

  factory InventoryReportItem.fromJson(Map<String, dynamic> json) {
    return InventoryReportItem(
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      barcode: json['barcode'],
      price: (json['price'] as num).toDouble(),
      lowStockThreshold: json['lowStockThreshold'],
      totalQuantity: json['totalQuantity'],
      inventoryValue: (json['inventoryValue'] as num).toDouble(),
      isLowStock: json['isLowStock'],
      locations: (json['locations'] as List)
          .map((item) => InventoryLocation.fromJson(item))
          .toList(),
    );
  }
}

class InventoryLocation {
  final int locationId;
  final String locationName;
  final int quantity;

  InventoryLocation({
    required this.locationId,
    required this.locationName,
    required this.quantity,
  });

  factory InventoryLocation.fromJson(Map<String, dynamic> json) {
    return InventoryLocation(
      locationId: json['locationId'],
      locationName: json['locationName'],
      quantity: json['quantity'],
    );
  }
}