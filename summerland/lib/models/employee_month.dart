import 'employee.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// One month of an employee's recorded performance.
///
/// These rows are filled in from the sales data, so the app only shows
/// them - it never writes them.
class EmployeeMonth {
  final int id;
  final int employeeId;
  final int year;
  final int month;
  final double totalSales;
  final double bonus;
  final bool achievedTarget;

  EmployeeMonth({
    required this.id,
    required this.employeeId,
    required this.year,
    required this.month,
    required this.totalSales,
    required this.bonus,
    required this.achievedTarget,
  });

  /// e.g. "March 2026".
  String get label {
    final name = month >= 1 && month <= 12 ? _monthNames[month - 1] : '$month';
    return '$name $year';
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Whether this month's sales reached the given target.
  ///
  /// Worked out from the live figures so the badge reflects the current
  /// target rather than the value stored when the sale was recorded.
  bool reachedTarget(double target) => target > 0 && totalSales >= target;

  /// The bonus for this month, following the employee's bonus type.
  double bonusAmount(BonusType type, double value) =>
      computeBonus(type, value, totalSales);

  factory EmployeeMonth.fromJson(Map<String, dynamic> json) {
    return EmployeeMonth(
      id: json['id'],
      employeeId: json['employeeId'] ?? 0,
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      totalSales: (json['totalSales'] as num? ?? 0).toDouble(),
      bonus: (json['bonus'] as num? ?? 0).toDouble(),
      achievedTarget: json['achievedTarget'] as bool? ?? false,
    );
  }
}
