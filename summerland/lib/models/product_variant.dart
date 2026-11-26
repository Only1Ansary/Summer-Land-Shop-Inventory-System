class ProductVariant {
  final int id;
  final int productId;
  final String modelNumber;
  final String productName;

  final int? sizeId;
  final String? sizeName;

  final int? colourId;
  final String? colourName;

  final int barcodeType;
  final String barcode;

  final double purchasePrice;
  final double sellingPrice;
  final int lowStockThreshold;

  final int totalQuantity;
  final bool isLowStock;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.modelNumber,
    required this.productName,
    this.sizeId,
    this.sizeName,
    this.colourId,
    this.colourName,
    required this.barcodeType,
    required this.barcode,
    this.purchasePrice = 0,
    required this.sellingPrice,
    required this.lowStockThreshold,
    required this.totalQuantity,
    required this.isLowStock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      productId: json['productId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeId: json['sizeId'],
      sizeName: json['sizeName'],
      colourId: json['colourId'],
      colourName: json['colourName'],
      barcodeType: json['barcodeType'],
      barcode: json['barcode'],
      purchasePrice: _toDouble(json['purchasePrice']),
      // Cached/offline records may still use the old "price" key.
      sellingPrice: _toDouble(json['sellingPrice'] ?? json['price']),
      lowStockThreshold: json['lowStockThreshold'] ?? 0,
      totalQuantity: json['totalQuantity'] ?? 0,
      isLowStock: json['isLowStock'] ?? false,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return 0;
  }
}
