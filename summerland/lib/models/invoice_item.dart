class InvoiceItem {
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double totalBeforeDiscount;
  final double unitPriceAfterDiscount;
  final double discountAmount;
  final double? discountPercent;

  InvoiceItem({
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.totalBeforeDiscount,
    required this.unitPriceAfterDiscount,
    required this.discountAmount,
    this.discountPercent,
  });

  bool get hasDiscount => discountAmount > 0 || (discountPercent ?? 0) > 0;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num).toInt();
    final unitPrice = (json['unitPrice'] as num).toDouble();

    return InvoiceItem(
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      totalBeforeDiscount:
          (json['totalBeforeDiscount'] as num?)?.toDouble() ??
          unitPrice * quantity,
      unitPriceAfterDiscount:
          (json['unitPriceAfterDiscount'] as num?)?.toDouble() ?? unitPrice,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble(),
    );
  }
}
