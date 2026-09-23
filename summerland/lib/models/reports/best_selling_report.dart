class BestSellingReport {
  final DateTime from;
  final DateTime to;
  final List<BestSellingProduct> items;

  BestSellingReport({
    required this.from,
    required this.to,
    required this.items,
  });

  factory BestSellingReport.fromJson(Map<String, dynamic> json) {
    return BestSellingReport(
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
      items: (json['items'] as List)
          .map((item) => BestSellingProduct.fromJson(item))
          .toList(),
    );
  }
}

class BestSellingProduct {
  final int productId;
  final String modelNumber;
  final String productName;
  final int totalQuantitySold;
  final double totalSales;

  BestSellingProduct({
    required this.productId,
    required this.modelNumber,
    required this.productName,
    required this.totalQuantitySold,
    required this.totalSales,
  });

  factory BestSellingProduct.fromJson(Map<String, dynamic> json) {
    return BestSellingProduct(
      productId: json['productId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      totalQuantitySold: json['totalQuantitySold'],
      totalSales: (json['totalSales'] as num).toDouble(),
    );
  }
}