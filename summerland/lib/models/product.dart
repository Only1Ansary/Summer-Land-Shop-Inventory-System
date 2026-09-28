class Product {
  final int id;
  final String modelNumber;
  final String barcode;
  final double purchasePrice;
  final double profitMargin;
  final double sellingPrice;
  final String name;
  final int categoryId;
  final String categoryName;

  Product({
    required this.id,
    required this.modelNumber,
    required this.barcode,
    required this.purchasePrice,
    required this.profitMargin,
    required this.sellingPrice,
    required this.name,
    required this.categoryId,
    required this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      modelNumber: json['modelNumber'] ?? '',
      barcode: json['barcode'] ?? '',
      purchasePrice: _toDouble(json['purchasePrice']),
      profitMargin: _toDouble(json['profitMargin']),
      sellingPrice: _toDouble(json['sellingPrice']),
      name: json['name'] ?? '',
      categoryId: json['categoryId'],
      categoryName: json['categoryName'] ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }
}