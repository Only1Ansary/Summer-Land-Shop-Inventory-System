import 'customer_payment.dart';
import 'invoice_item.dart';

class Invoice {
  final int id;
  final DateTime createdAt;
  final int locationId;
  final String locationName;
  final int? employeeId;
  final String? employeeName;
  final double totalAmount;
  final double discountAmount;
  final double? discountPercent;
  final List<InvoiceItem> items;

  // Customer and payment details. Null/zero for invoices created before
  // customers were tracked, so old data still parses.
  final int? customerId;
  final String? customerPhone;
  final String? customerName;
  final double customerTotalPaid;
  final double customerTotalDebt;
  final int? paymentMethod;
  final double paidAmount;
  final double remainingAmount;
  final List<CustomerPayment> payments;

  Invoice({
    required this.id,
    required this.createdAt,
    required this.locationId,
    required this.locationName,
    this.employeeId,
    this.employeeName,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.discountPercent,
    required this.items,
    this.customerId,
    this.customerPhone,
    this.customerName,
    this.customerTotalPaid = 0.0,
    this.customerTotalDebt = 0.0,
    this.paymentMethod,
    this.paidAmount = 0.0,
    double? remainingAmount,
    this.payments = const [],
  }) : remainingAmount = remainingAmount ??
            (totalAmount - paidAmount > 0 ? totalAmount - paidAmount : 0.0);

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final total = (json['totalAmount'] as num).toDouble();
    final paid = (json['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (json['remainingAmount'] as num?)?.toDouble() ??
        (total - paid > 0 ? total - paid : 0.0);

    return Invoice(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      locationId: json['locationId'],
      locationName: json['locationName'],
      employeeId: json['employeeId'] as int?,
      employeeName: json['employeeName'] as String?,
      totalAmount: total,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble(),
      items: (json['items'] as List)
          .map((item) => InvoiceItem.fromJson(item))
          .toList(),
      customerId: json['customerId'] as int?,
      customerPhone: json['customerPhone'] as String?,
      customerName: json['customerName'] as String?,
      customerTotalPaid:
          (json['customerTotalPaid'] as num?)?.toDouble() ?? 0.0,
      customerTotalDebt:
          (json['customerTotalDebt'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as int?,
      paidAmount: paid,
      remainingAmount: remaining,
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((payment) => CustomerPayment.fromJson(payment))
          .toList(),
    );
  }

  bool get isFullyPaid => remainingAmount <= 0.005;

  /// Name shown in the UI: the optional customer name, or the phone number.
  String? get customerDisplayName {
    final value = customerName?.trim() ?? '';
    if (value.isNotEmpty) return value;

    final phone = customerPhone?.trim() ?? '';
    return phone.isEmpty ? null : phone;
  }
}
