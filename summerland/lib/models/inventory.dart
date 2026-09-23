class Inventory {
  final int id;
  final int productVariantId;
  final int locationId;
  final String locationName;
  final int quantity;

  Inventory({
    required this.id,
    required this.productVariantId,
    required this.locationId,
    required this.locationName,
    required this.quantity,
  });

  factory Inventory.fromJson(
      Map<String, dynamic> json,
      ) {
    return Inventory(
      id: json['id'],
      productVariantId: json['productVariantId'],
      locationId: json['locationId'],
      locationName: json['locationName'],
      quantity: json['quantity'],
    );
  }
}