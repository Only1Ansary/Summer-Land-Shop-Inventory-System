class SalesReport {
  final DateTime from;
  final DateTime to;
  final int invoiceCount;
  final int itemsSold;
  final double grossSales;
  final int itemsReturned;
  final double returnsAmount;
  final double netSales;

  SalesReport({
    required this.from,
    required this.to,
    required this.invoiceCount,
    required this.itemsSold,
    required this.grossSales,
    required this.itemsReturned,
    required this.returnsAmount,
    required this.netSales,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
      invoiceCount: json['invoiceCount'],
      itemsSold: json['itemsSold'],
      grossSales: (json['grossSales'] as num).toDouble(),
      itemsReturned: json['itemsReturned'],
      returnsAmount: (json['returnsAmount'] as num).toDouble(),
      netSales: (json['netSales'] as num).toDouble(),
    );
  }
}