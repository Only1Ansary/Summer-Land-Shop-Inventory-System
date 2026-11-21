class Customer {
  final int id;
  final String phoneNumber;
  final String? name;
  final double totalPaid;
  final double totalDebt;
  final int invoiceCount;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.totalPaid = 0.0,
    this.totalDebt = 0.0,
    this.invoiceCount = 0,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;

    return Customer(
      id: json['id'] as int? ?? 0,
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      name: json['name'] as String?,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: json['invoiceCount'] as int? ?? 0,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }

  /// Shows the name when one was recorded, otherwise the phone number.
  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? phoneNumber : value;
  }
}
