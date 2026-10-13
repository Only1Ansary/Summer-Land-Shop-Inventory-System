/// One recorded payment to an employee (salary and/or bonus).
class EmployeePayment {
  final int id;
  final int employeeId;
  final double amount;
  final DateTime paidAt;

  EmployeePayment({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.paidAt,
  });

  factory EmployeePayment.fromJson(Map<String, dynamic> json) {
    return EmployeePayment(
      id: json['id'],
      employeeId: json['employeeId'] ?? 0,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      paidAt: DateTime.tryParse(json['paidAt'] ?? '') ?? DateTime.now(),
    );
  }
}
