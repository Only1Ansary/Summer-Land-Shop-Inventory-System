import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/employee_service.dart';
import 'package:summerland/models/employee.dart';

// No widget tests in this file: the Flutter test binding blocks real HTTP,
// so the API payloads are checked against a local listener instead
// (same approach as api_error_messages_test.dart).
void main() {
  test('creating an employee sends only name, salary and target', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? captured;

    listener.listen((request) async {
      captured = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;

      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 1,
            'name': 'Mona',
            'salary': 5000,
            'target': 20000,
            'bonus': 0,
            'achievedTarget': false,
            'totalSales': 0,
          }),
        );

      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final created = await service.createEmployee(
      name: 'Mona',
      salary: 5000,
      target: 20000,
    );

    expect(captured!.keys.toSet(), {'name', 'salary', 'target'});
    expect(created.target, 20000);
    expect(created.bonus, 0);
    expect(created.achievedTarget, isFalse);
    expect(created.totalSales, 0);

    await listener.close(force: true);
  });

  test('editing an employee sends only the editable fields', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;
    Map<String, dynamic>? captured;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;
      captured = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 5,
            'name': 'Mona',
            'salary': 6000,
            'target': 25000,
            'bonus': 300,
            'achievedTarget': true,
            'totalSales': 26000,
          }),
        );

      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final updated = await service.updateEmployee(
      5,
      name: 'Mona',
      salary: 6000,
      target: 25000,
      bonus: 300,
      bonusType: BonusType.percentage,
    );

    expect(method, 'PUT');
    expect(path, '/api/Employees/5');
    expect(captured!.keys.toSet(), {
      'name',
      'salary',
      'target',
      'bonus',
      'bonusType',
    });
    expect(captured!['bonus'], 300);
    expect(captured!['bonusType'], 1);
    expect(captured!['target'], 25000);
    expect(captured!.containsKey('totalSales'), isFalse);
    expect(captured!.containsKey('achievedTarget'), isFalse);
    expect(updated.salary, 6000);
    expect(updated.totalSales, 26000);

    await listener.close(force: true);
  });

  test('history is fetched per employee and parsed newest first', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': 2,
              'employeeId': 7,
              'year': 2026,
              'month': 4,
              'totalSales': 21000,
              'bonus': 500,
              'achievedTarget': true,
            },
            {
              'id': 1,
              'employeeId': 7,
              'year': 2026,
              'month': 3,
              'totalSales': 15000,
              'bonus': 0,
              'achievedTarget': false,
            },
          ]),
        );

      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final history = await service.getEmployeeHistory(7);

    expect(method, 'GET');
    expect(path, '/api/Employees/7/history');
    expect(history, hasLength(2));
    expect(history.first.label, 'April 2026');
    expect(history.first.achievedTarget, isTrue);
    expect(history.last.bonus, 0);

    await listener.close(force: true);
  });

  test('deleting an employee sends a DELETE for that employee', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;
      request.response.statusCode = 204;
      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    await service.deleteEmployee(9);

    expect(method, 'DELETE');
    expect(path, '/api/Employees/9');

    await listener.close(force: true);
  });

  test('recording a payment posts the amount and date', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method;
    String? path;
    Map<String, dynamic>? captured;

    listener.listen((request) async {
      method = request.method;
      path = request.uri.path;
      captured = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;

      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 3,
            'employeeId': 4,
            'amount': 6250.5,
            'paidAt': '2026-03-01T08:00:00Z',
          }),
        );

      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final payment = await service.recordPayment(
      4,
      amount: 6250.5,
      paidAt: DateTime.utc(2026, 3, 1, 8),
    );

    expect(method, 'POST');
    expect(path, '/api/Employees/4/payments');
    expect(captured!['amount'], 6250.5);
    expect(captured!['paidAt'], contains('2026-03-01'));
    expect(payment.amount, 6250.5);
    expect(payment.employeeId, 4);

    await listener.close(force: true);
  });

  test('payments are fetched per employee', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? path;

    listener.listen((request) async {
      path = request.uri.path;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode([
            {
              'id': 2,
              'employeeId': 4,
              'amount': 500,
              'paidAt': '2026-03-02T08:00:00Z',
            },
            {
              'id': 1,
              'employeeId': 4,
              'amount': 6250.5,
              'paidAt': '2026-03-01T08:00:00Z',
            },
          ]),
        );

      await request.response.close();
    });

    final service = EmployeeService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final payments = await service.getPayments(4);

    expect(path, '/api/Employees/4/payments');
    expect(payments, hasLength(2));
    expect(payments.first.amount, 500);
    expect(payments.last.amount, 6250.5);

    await listener.close(force: true);
  });
}
