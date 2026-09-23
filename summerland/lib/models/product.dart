class Product {
  final int id;
  final String modelNumber;
  final String name;
  final int categoryId;
  final String categoryName;

  Product({
    required this.id,
    required this.modelNumber,
    required this.name,
    required this.categoryId,
    required this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      modelNumber: json['modelNumber'],
      name: json['name'],
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
    );
  }
}