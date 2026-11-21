import 'customer_payment.dart';

/// Full view of one customer, returned by `GET /api/Customers/{id}/details`.
class CustomerDetails {
  final int id;
  final String phoneNumber;
  final String? name;
  final double totalPaid;
  final double totalDebt;
  final int invoiceCount;
  final int unpaidInvoiceCount;
  final DateTime? createdAt;
  final List<CustomerInvoiceSummary> invoices;
  final List<CustomerPayment> payments;

  CustomerDetails({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.totalPaid = 0.0,
    this.totalDebt = 0.0,
    this.invoiceCount = 0,
    this.unpaidInvoiceCount = 0,
    this.createdAt,
    this.invoices = const [],
    this.payments = const [],
  });

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;

    return CustomerDetails(
      id: json['id'] as int? ?? 0,
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      name: json['name'] as String?,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: json['invoiceCount'] as int? ?? 0,
      unpaidInvoiceCount: json['unpaidInvoiceCount'] as int? ?? 0,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
      invoices: (json['invoices'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                CustomerInvoiceSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((item) => CustomerPayment.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? phoneNumber : value;
  }
}

/// One invoice row in the customer's invoice list.
class CustomerInvoiceSummary {
  final int id;
  final DateTime? createdAt;
  final String locationName;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;

  CustomerInvoiceSummary({
    required this.id,
    this.createdAt,
    this.locationName = '',
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    required this.remainingAmount,
  });

  factory CustomerInvoiceSummary.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;

    return CustomerInvoiceSummary(
      id: json['id'] as int? ?? 0,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
      locationName: (json['locationName'] as String?) ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isFullyPaid => remainingAmount <= 0.005;
}
