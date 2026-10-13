/// How an employee's bonus is worked out.
enum BonusType {
  /// A fixed amount in EGP set by the manager.
  fixed,

  /// A percentage of the employee's total sales.
  percentage;

  /// Reads the value the backend sends (0 or 1, or its name).
  static BonusType fromJson(Object? value) {
    if (value is String) {
      return value.toLowerCase() == 'percentage'
          ? BonusType.percentage
          : BonusType.fixed;
    }

    return value == 1 ? BonusType.percentage : BonusType.fixed;
  }

  /// The value sent back to the backend.
  int get asInt => this == BonusType.percentage ? 1 : 0;
}

/// The bonus owed: a fixed amount, or a percentage of the total sales.
double computeBonus(BonusType type, double value, double totalSales) {
  if (type != BonusType.percentage) {
    return value;
  }

  return (totalSales * value / 100 * 100).roundToDouble() / 100;
}

class Employee {
  final int id;
  final String name;
  final double salary;
  final double target;
  final double bonus;
  final BonusType bonusType;
  final bool achievedTarget;
  final double totalSales;

  /// Payments recorded in the current month. Null when the server does not
  /// send it (older builds).
  final double? paidThisMonth;

  /// What still has to be paid out this month. Null when the server does
  /// not send it.
  final double? leftToPay;

  Employee({
    required this.id,
    required this.name,
    required this.salary,
    required this.target,
    required this.bonus,
    this.bonusType = BonusType.fixed,
    required this.achievedTarget,
    required this.totalSales,
    this.paidThisMonth,
    this.leftToPay,
  });

  /// The bonus actually owed, following the employee's bonus type.
  double get bonusAmount => computeBonus(bonusType, bonus, totalSales);

  double get totalCompensation => salary + bonusAmount;

  /// What still has to be paid out this month.
  ///
  /// When the server does not supply the figure, falls back to the full
  /// monthly obligation (salary + bonus), assuming nothing has been paid.
  double get effectiveLeftToPay => leftToPay ?? totalCompensation;

  /// Whether the employee has reached their sales target.
  ///
  /// Worked out from the live figures rather than the stored flag, so the
  /// badge stays right the moment the target or the sales total changes.
  bool get reachedTarget => target > 0 && totalSales >= target;

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'] ?? '',
      salary: (json['salary'] as num? ?? 0).toDouble(),
      target: (json['target'] as num? ?? 0).toDouble(),
      bonus: (json['bonus'] as num? ?? 0).toDouble(),
      bonusType: BonusType.fromJson(json['bonusType']),
      achievedTarget: json['achievedTarget'] as bool? ?? false,
      totalSales: (json['totalSales'] as num? ?? 0).toDouble(),
      paidThisMonth: (json['paidThisMonth'] as num?)?.toDouble(),
      leftToPay: (json['leftToPay'] as num?)?.toDouble(),
    );
  }
}
