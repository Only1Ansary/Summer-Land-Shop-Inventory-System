class PurchaseInvoiceItem {
  final int productId;
  final double unitPurchasePrice;
  final int quantity;
  final double totalPrice;

  String? productName;
  String? modelNumber;

  PurchaseInvoiceItem({
    required this.productId,
    required this.unitPurchasePrice,
    required this.quantity,
    required this.totalPrice,
    this.productName,
    this.modelNumber,
  });

  factory PurchaseInvoiceItem.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceItem(
      productId: json['productId'],
      unitPurchasePrice: (json['unitPurchasePrice'] as num? ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      totalPrice: (json['totalPrice'] as num? ?? 0).toDouble(),
      productName: json['productName'],
      modelNumber: json['modelNumber'],
    );
  }
}