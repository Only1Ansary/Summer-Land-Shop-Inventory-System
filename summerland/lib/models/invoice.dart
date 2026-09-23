import 'invoice_item.dart';

class Invoice {
  final int id;
  final DateTime createdAt;
  final int locationId;
  final String locationName;
  final double totalAmount;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.createdAt,
    required this.locationId,
    required this.locationName,
    required this.totalAmount,
    required this.items,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      locationId: json['locationId'],
      locationName: json['locationName'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      items: (json['items'] as List)
          .map(
            (item) => InvoiceItem.fromJson(item),
      )
          .toList(),
    );
  }
}