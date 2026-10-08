import 'purchase_invoice_item.dart';

class PurchaseInvoice {
  final int id;
  final int supplierId;
  final String supplierName;
  final DateTime? date;
  final DateTime createdAt;
  final double totalCost;
  final double totalPaid;
  final double debt;
  final double supplierTotalDebt;
  final double itemsTotal;
  final double feesTotal;
  final List<PurchaseInvoiceFee> fees;
  final List<PurchaseInvoiceItem> items;
  final List<PurchaseReturn> returns;

  PurchaseInvoice({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    required this.createdAt,
    required this.totalCost,
    required this.totalPaid,
    required this.debt,
    required this.supplierTotalDebt,
    required this.items,
    required this.returns,
    this.itemsTotal = 0,
    this.feesTotal = 0,
    this.fees = const [],
  });

  /// The part of [totalCost] the supplier can still be owed: the goods after
  /// discount. Extra fees are part of the cost but are never owed.
  double get payableTotal => totalCost - feesTotal;

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoice(
      id: json['id'],
      supplierId: json['supplierId'] ?? 0,
      supplierName:
          json['supplierName'] ?? 'Supplier #${json['supplierId'] ?? '?'}',
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      totalCost: (json['totalCost'] as num? ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      debt: ((json['invoiceDebt'] ?? json['debt']) as num? ?? 0).toDouble(),
      supplierTotalDebt: (json['supplierTotalDebt'] as num? ?? 0).toDouble(),
      itemsTotal: (json['itemsTotal'] as num? ?? 0).toDouble(),
      feesTotal: (json['feesTotal'] as num? ?? 0).toDouble(),
      fees: (json['fees'] as List? ?? [])
          .map((fee) => PurchaseInvoiceFee.fromJson(fee))
          .toList(),
      items: (json['items'] as List? ?? [])
          .map((item) => PurchaseInvoiceItem.fromJson(item))
          .toList(),
      returns: (json['returns'] as List? ?? [])
          .map((ret) => PurchaseReturn.fromJson(ret))
          .toList(),
    );
  }
}

class PurchaseInvoiceFee {
  final int id;
  final String description;
  final double amount;

  PurchaseInvoiceFee({
    required this.id,
    required this.description,
    required this.amount,
  });

  factory PurchaseInvoiceFee.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceFee(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }
}

class PurchaseReturn {
  final int id;
  final int productId;
  final String productName;
  final double unitPurchasePrice;
  final int quantity;
  final String reason;
  final DateTime? createdAt;

  PurchaseReturn({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPurchasePrice,
    required this.quantity,
    required this.reason,
    required this.createdAt,
  });

  double get totalPrice => unitPurchasePrice * quantity;

  factory PurchaseReturn.fromJson(Map<String, dynamic> json) {
    return PurchaseReturn(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'] ?? '',
      unitPurchasePrice: (json['unitPurchasePrice'] as num? ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      reason: json['reason'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
