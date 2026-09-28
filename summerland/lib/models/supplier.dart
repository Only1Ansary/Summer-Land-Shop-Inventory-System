class Supplier {
  final int id;
  final String supplierName;
  final double debt;
  final List<PurchaseInvoiceSummary> purchaseInvoices;

  Supplier({
    required this.id,
    required this.supplierName,
    required this.debt,
    required this.purchaseInvoices,
  });

  int get invoiceCount => purchaseInvoices.length;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      supplierName: json['supplierName'] ?? json['name'] ?? '',
      debt: (json['debt'] as num? ?? 0).toDouble(),
      purchaseInvoices:
          ((json['purchaseInvoices'] as List?) ?? const [])
              .map(
                (e) => PurchaseInvoiceSummary.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class PurchaseInvoiceSummary {
  final int id;
  final DateTime? date;
  final DateTime? createdAt;
  final double totalCost;
  final double totalPaid;
  final double debt;

  PurchaseInvoiceSummary({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.totalCost,
    required this.totalPaid,
    required this.debt,
  });

  factory PurchaseInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceSummary(
      id: json['id'],
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      totalCost: (json['totalCost'] as num? ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      debt: (json['debt'] as num? ?? 0).toDouble(),
    );
  }
}