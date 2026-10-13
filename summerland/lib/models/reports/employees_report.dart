import '../employee.dart';

class EmployeesReport {
  final int year;
  final int month;
  final int employeeCount;
  final double totalMonthlySalaries;
  final double totalBonusOwed;
  final double totalSales;
  final int targetMetCount;
  final int paymentCountInMonth;
  final double paymentTotalInMonth;
  final double totalPaid;
  final double totalLeftToPay;
  final List<EmployeeOfMonth> employeeOfTheMonth;
  final List<EmployeeReportItem> employees;

  EmployeesReport({
    required this.year,
    required this.month,
    required this.employeeCount,
    required this.totalMonthlySalaries,
    required this.totalBonusOwed,
    required this.totalSales,
    required this.targetMetCount,
    required this.paymentCountInMonth,
    required this.paymentTotalInMonth,
    required this.totalPaid,
    required this.totalLeftToPay,
    required this.employeeOfTheMonth,
    required this.employees,
  });

  factory EmployeesReport.fromJson(Map<String, dynamic> json) {
    double amount(String key) => (json[key] as num? ?? 0).toDouble();

    return EmployeesReport(
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      employeeCount: json['employeeCount'] ?? 0,
      totalMonthlySalaries: amount('totalMonthlySalaries'),
      totalBonusOwed: amount('totalBonusOwed'),
      totalSales: amount('totalSales'),
      targetMetCount: json['targetMetCount'] ?? 0,
      paymentCountInMonth: json['paymentCountInMonth'] ?? 0,
      paymentTotalInMonth: amount('paymentTotalInMonth'),
      totalPaid: amount('totalPaid'),
      totalLeftToPay: amount('totalLeftToPay'),
      employeeOfTheMonth: (json['employeeOfTheMonth'] as List<dynamic>? ?? [])
          .map((e) => EmployeeOfMonth.fromJson(e as Map<String, dynamic>))
          .toList(),
      employees: (json['employees'] as List<dynamic>? ?? [])
          .map((e) => EmployeeReportItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One of the employees with the highest sales in the reported month.
class EmployeeOfMonth {
  final int employeeId;
  final String name;
  final double totalSales;

  EmployeeOfMonth({
    required this.employeeId,
    required this.name,
    required this.totalSales,
  });

  factory EmployeeOfMonth.fromJson(Map<String, dynamic> json) {
    return EmployeeOfMonth(
      employeeId: json['employeeId'] ?? 0,
      name: json['name'] ?? '',
      totalSales: (json['totalSales'] as num? ?? 0).toDouble(),
    );
  }
}

class EmployeeReportItem {
  final int employeeId;
  final String name;
  final BonusType bonusType;
  final double salary;
  final double target;
  final double bonus;
  final double bonusAmount;
  final double totalSales;
  final bool achievedTarget;
  final int paymentCountInMonth;
  final double paymentTotalInMonth;
  final double totalPaid;
  final double monthlyObligation;
  final double leftToPay;

  EmployeeReportItem({
    required this.employeeId,
    required this.name,
    required this.bonusType,
    required this.salary,
    required this.target,
    required this.bonus,
    required this.bonusAmount,
    required this.totalSales,
    required this.achievedTarget,
    required this.paymentCountInMonth,
    required this.paymentTotalInMonth,
    required this.totalPaid,
    required this.monthlyObligation,
    required this.leftToPay,
  });

  factory EmployeeReportItem.fromJson(Map<String, dynamic> json) {
    double amount(String key) => (json[key] as num? ?? 0).toDouble();

    return EmployeeReportItem(
      employeeId: json['employeeId'] ?? 0,
      name: json['name'] ?? '',
      bonusType: BonusType.fromJson(json['bonusType']),
      salary: amount('salary'),
      target: amount('target'),
      bonus: amount('bonus'),
      bonusAmount: amount('bonusAmount'),
      totalSales: amount('totalSales'),
      achievedTarget: json['achievedTarget'] as bool? ?? false,
      paymentCountInMonth: json['paymentCountInMonth'] ?? 0,
      paymentTotalInMonth: amount('paymentTotalInMonth'),
      totalPaid: amount('totalPaid'),
      monthlyObligation: amount('monthlyObligation'),
      leftToPay: amount('leftToPay'),
    );
  }
}
