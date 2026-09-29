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
  final List<CategorySales> categorySales;

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
    required this.categorySales,
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
      categorySales: (json['categorySales'] as List<dynamic>? ?? [])
          .map((e) => CategorySales.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategorySales {
  final String categoryName;
  final int quantitySold;
  final double amount;

  CategorySales({
    required this.categoryName,
    required this.quantitySold,
    required this.amount,
  });

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    return CategorySales(
      categoryName: json['categoryName'] as String? ?? 'Uncategorized',
      quantitySold: json['quantitySold'] ?? 0,
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }
}