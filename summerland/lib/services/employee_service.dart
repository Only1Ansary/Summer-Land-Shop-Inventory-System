import '../models/employee.dart';
import '../models/employee_month.dart';
import '../models/employee_payment.dart';
import 'api_service.dart';

class EmployeeService {
  static const String _base = '/api/Employees';

  final ApiService _apiService;

  EmployeeService(this._apiService);

  Future<List<Employee>> getEmployees() async {
    final data = await _apiService.get(_base);

    return (data as List)
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Employee> createEmployee({
    required String name,
    required double salary,
    required double target,
  }) async {
    final data = await _apiService.post(_base, {
      'name': name,
      'salary': salary,
      'target': target,
    });

    return Employee.fromJson(data as Map<String, dynamic>);
  }

  Future<Employee> updateEmployee(
    int id, {
    required String name,
    required double salary,
    required double target,
    required double bonus,
    required BonusType bonusType,
  }) async {
    final data = await _apiService.put('$_base/$id', {
      'name': name,
      'salary': salary,
      'target': target,
      'bonus': bonus,
      'bonusType': bonusType.asInt,
    });

    return Employee.fromJson(data as Map<String, dynamic>);
  }

  Future<List<EmployeeMonth>> getEmployeeHistory(int employeeId) async {
    final data = await _apiService.get('$_base/$employeeId/history');

    return (data as List)
        .map((json) => EmployeeMonth.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Deletes the employee. Their monthly history is removed too; the
  /// invoices they sold keep the employee name.
  Future<void> deleteEmployee(int id) async {
    await _apiService.delete('$_base/$id');
  }

  /// Records a payment to the employee. The backend clears the bonus, since
  /// a payment settles salary plus the outstanding bonus in one go.
  Future<EmployeePayment> recordPayment(
    int employeeId, {
    required double amount,
    required DateTime paidAt,
  }) async {
    final data = await _apiService.post('$_base/$employeeId/payments', {
      'amount': amount,
      'paidAt': paidAt.toIso8601String(),
    });

    return EmployeePayment.fromJson(data as Map<String, dynamic>);
  }

  Future<List<EmployeePayment>> getPayments(int employeeId) async {
    final data = await _apiService.get('$_base/$employeeId/payments');

    return (data as List)
        .map((json) => EmployeePayment.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
