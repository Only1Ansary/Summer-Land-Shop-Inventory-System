class SalesReport {
  final DateTime from;
  final DateTime to;
  final int invoiceCount;
  final int itemsSold;
  final double grossSales;
  final int itemsReturned;
  final double returnsAmount;
  final double netSales;
  final int purchaseInvoiceCount;
  final double purchaseTotalCost;
  final double purchaseTotalPaid;
  final double purchaseDebt;
  final int supplierCount;
  final double supplierDebtTotal;
  final double profit;

  SalesReport({
    required this.from,
    required this.to,
    required this.invoiceCount,
    required this.itemsSold,
    required this.grossSales,
    required this.itemsReturned,
    required this.returnsAmount,
    required this.netSales,
    required this.purchaseInvoiceCount,
    required this.purchaseTotalCost,
    required this.purchaseTotalPaid,
    required this.purchaseDebt,
    required this.supplierCount,
    required this.supplierDebtTotal,
    required this.profit,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    double amount(String key) => (json[key] as num? ?? 0).toDouble();

    return SalesReport(
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
      invoiceCount: json['invoiceCount'] ?? 0,
      itemsSold: json['itemsSold'] ?? 0,
      grossSales: amount('grossSales'),
      itemsReturned: json['itemsReturned'] ?? 0,
      returnsAmount: amount('returnsAmount'),
      netSales: amount('netSales'),
      purchaseInvoiceCount: json['purchaseInvoiceCount'] ?? 0,
      purchaseTotalCost: amount('purchaseTotalCost'),
      purchaseTotalPaid: amount('purchaseTotalPaid'),
      purchaseDebt: amount('purchaseDebt'),
      supplierCount: json['supplierCount'] ?? 0,
      supplierDebtTotal: amount('supplierDebtTotal'),
      profit: amount('profit'),
    );
  }
}