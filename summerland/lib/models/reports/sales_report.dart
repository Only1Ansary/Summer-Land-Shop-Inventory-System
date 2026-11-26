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
  final int employeePaymentCount;
  final double employeePaymentTotal;
  final int supplierCount;
  final double supplierDebtTotal;
  final double costOfGoodsSold;
  final double grossProfit;
  final double profit;
  final List<CategorySales> categorySales;
  final List<DailySales> dailySales;

  final int customerCount;
  final int customerPaymentCount;
  final double customerPaymentsTotal;
  final double customerDebtTotal;
  final List<PaymentMethodTotal> paymentsByMethod;

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
    required this.employeePaymentCount,
    required this.employeePaymentTotal,
    required this.supplierCount,
    required this.supplierDebtTotal,
    required this.profit,
    required this.categorySales,
    this.costOfGoodsSold = 0.0,
    this.grossProfit = 0.0,
    this.dailySales = const [],
    this.customerCount = 0,
    this.customerPaymentCount = 0,
    this.customerPaymentsTotal = 0.0,
    this.customerDebtTotal = 0.0,
    this.paymentsByMethod = const [],
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
      employeePaymentCount: json['employeePaymentCount'] ?? 0,
      employeePaymentTotal: amount('employeePaymentTotal'),
      supplierCount: json['supplierCount'] ?? 0,
      supplierDebtTotal: amount('supplierDebtTotal'),
      costOfGoodsSold: amount('costOfGoodsSold'),
      grossProfit: amount('grossProfit'),
      profit: amount('profit'),
      dailySales: (json['dailySales'] as List<dynamic>? ?? [])
          .map((e) => DailySales.fromJson(e as Map<String, dynamic>))
          .toList(),
      categorySales: (json['categorySales'] as List<dynamic>? ?? [])
          .map((e) => CategorySales.fromJson(e as Map<String, dynamic>))
          .toList(),
      customerCount: json['customerCount'] ?? 0,
      customerPaymentCount: json['customerPaymentCount'] ?? 0,
      customerPaymentsTotal: amount('customerPaymentsTotal'),
      customerDebtTotal: amount('customerDebtTotal'),
      paymentsByMethod: (json['paymentsByMethod'] as List<dynamic>? ?? [])
          .map((e) =>
          PaymentMethodTotal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaymentMethodTotal {
  final int method;
  final String methodName;
  final double amount;

  PaymentMethodTotal({
    required this.method,
    required this.methodName,
    required this.amount,
  });

  factory PaymentMethodTotal.fromJson(Map<String, dynamic> json) {
    return PaymentMethodTotal(
      method: json['method'] as int? ?? 0,
      methodName: json['methodName'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
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

class DailySales {
  final DateTime date;
  final double netSales;
  final int invoiceCount;

  DailySales({
    required this.date,
    required this.netSales,
    required this.invoiceCount,
  });

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: DateTime.parse(json['date']),
      netSales: (json['netSales'] as num? ?? 0).toDouble(),
      invoiceCount: json['invoiceCount'] ?? 0,
    );
  }
}