class ReturnModel {
  final int id;
  final int invoiceId;
  final int productVariantId;
  final String modelNumber;
  final String productName;
  final String? sizeName;
  final String? colourName;
  final int locationId;
  final String locationName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String reason;
  final DateTime createdAt;

  ReturnModel({
    required this.id,
    required this.invoiceId,
    required this.productVariantId,
    required this.modelNumber,
    required this.productName,
    this.sizeName,
    this.colourName,
    required this.locationId,
    required this.locationName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.reason,
    required this.createdAt,
  });

  factory ReturnModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReturnModel(
      id: json['id'],
      invoiceId: json['invoiceId'],
      productVariantId: json['productVariantId'],
      modelNumber: json['modelNumber'],
      productName: json['productName'],
      sizeName: json['sizeName'],
      colourName: json['colourName'],
      locationId: json['locationId'],
      locationName: json['locationName'],
      quantity: json['quantity'],
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      reason: json['reason'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}