class CustomerPayment {
  final int id;
  /// Null for payments on anonymous sales that were paid in full.
  final int? customerId;
  /// Invoice this part of the payment was applied to. Zero on older records
  /// that were created before the link was returned to the app.
  final int saleInvoiceId;
  final double amount;
  final int method;
  final DateTime? paidAt;

  CustomerPayment({
    required this.id,
    this.customerId,
    this.saleInvoiceId = 0,
    required this.amount,
    required this.method,
    this.paidAt,
  });

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    final paidAt = json['paidAt'] as String?;

    return CustomerPayment(
      id: json['id'] as int? ?? 0,
      customerId: json['customerId'] as int?,
      saleInvoiceId: json['saleInvoiceId'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: json['method'] as int? ?? 0,
      paidAt: paidAt == null ? null : DateTime.tryParse(paidAt),
    );
  }
}
