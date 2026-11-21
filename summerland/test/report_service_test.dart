import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/employee.dart';
import 'package:summerland/services/api_service.dart';
import 'package:summerland/services/report_service.dart';

void main() {
  test('employees report requests the month and parses employees', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? path;

    listener.listen((request) async {
      path =
          request.uri.path +
          (request.uri.hasQuery ? '?${request.uri.query}' : '');

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'year': 2026,
            'month': 10,
            'employeeCount': 2,
            'totalMonthlySalaries': 11000,
            'totalBonusOwed': 1250,
            'totalSales': 30000,
            'targetMetCount': 1,
            'paymentCountInMonth': 3,
            'paymentTotalInMonth': 9000,
            'totalPaid': 21000,
            'totalLeftToPay': 3250,
            'employeeOfTheMonth': [
              {'employeeId': 1, 'name': 'Mona', 'totalSales': 22000},
            ],
            'employees': [
              {
                'employeeId': 1,
                'name': 'Mona',
                'bonusType': 1,
                'salary': 5000,
                'target': 20000,
                'bonus': 10,
                'bonusAmount': 1000,
                'totalSales': 22000,
                'achievedTarget': true,
                'paymentCountInMonth': 2,
                'paymentTotalInMonth': 6000,
                'totalPaid': 16000,
                'monthlyObligation': 6000,
                'leftToPay': 0,
              },
              {
                'employeeId': 2,
                'name': 'Omar',
                'bonusType': 0,
                'salary': 6000,
                'target': 15000,
                'bonus': 250,
                'bonusAmount': 250,
                'totalSales': 8000,
                'achievedTarget': false,
                'paymentCountInMonth': 1,
                'paymentTotalInMonth': 3000,
                'totalPaid': 5000,
                'monthlyObligation': 6250,
                'leftToPay': 3250,
              },
            ],
          }),
        );

      await request.response.close();
    });

    final service = ReportService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final report = await service.getEmployeesReport(year: 2026, month: 10);

    expect(path, contains('/api/Reports/employees'));
    expect(path, contains('year=2026'));
    expect(path, contains('month=10'));

    expect(report.year, 2026);
    expect(report.month, 10);
    expect(report.employeeCount, 2);
    expect(report.totalMonthlySalaries, 11000);
    expect(report.paymentTotalInMonth, 9000);
    expect(report.totalPaid, 21000);
    expect(report.totalLeftToPay, 3250);
    expect(report.employees, hasLength(2));

    expect(report.employeeOfTheMonth, hasLength(1));
    expect(report.employeeOfTheMonth.first.name, 'Mona');
    expect(report.employeeOfTheMonth.first.totalSales, 22000);

    final mona = report.employees.first;
    expect(mona.name, 'Mona');
    expect(mona.bonusType, BonusType.percentage);
    expect(mona.bonusAmount, 1000);
    expect(mona.achievedTarget, isTrue);
    expect(mona.paymentTotalInMonth, 6000);
    expect(mona.monthlyObligation, 6000);
    expect(mona.leftToPay, 0);

    final omar = report.employees.last;
    expect(omar.bonusType, BonusType.fixed);
    expect(omar.bonusAmount, 250);
    expect(omar.monthlyObligation, 6250);
    expect(omar.leftToPay, 3250);

    await listener.close(force: true);
  });

  test('a report with nobody selling has no employee of the month', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    listener.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'year': 2026,
            'month': 9,
            'employeeCount': 1,
            'employeeOfTheMonth': [],
            'employees': [
              {
                'employeeId': 1,
                'name': 'Mona',
                'bonusType': 0,
                'salary': 5000,
                'totalSales': 0,
              },
            ],
          }),
        );

      await request.response.close();
    });

    final service = ReportService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final report = await service.getEmployeesReport(year: 2026, month: 9);

    expect(report.employeeOfTheMonth, isEmpty);
    expect(report.employees.single.totalSales, 0);

    await listener.close(force: true);
  });

  test('sales report parses customer and payment fields', () async {
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    listener.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'from': '2026-11-01T00:00:00Z',
            'to': '2026-11-30T23:59:59Z',
            'invoiceCount': 4,
            'customerCount': 3,
            'customerPaymentCount': 5,
            'customerPaymentsTotal': 1750.0,
            'customerDebtTotal': 2250.0,
            'paymentsByMethod': [
              {'method': 0, 'methodName': 'Cash', 'amount': 1000.0},
              {'method': 2, 'methodName': 'InstaPay', 'amount': 750.0},
            ],
          }),
        );

      await request.response.close();
    });

    final service = ReportService(
      ApiService(baseUrl: 'http://127.0.0.1:${listener.port}'),
    );

    final report = await service.getSalesReport();

    expect(report.customerCount, 3);
    expect(report.customerPaymentCount, 5);
    expect(report.customerPaymentsTotal, 1750);
    expect(report.customerDebtTotal, 2250);
    expect(report.paymentsByMethod, hasLength(2));
    expect(report.paymentsByMethod.first.method, 0);
    expect(report.paymentsByMethod.first.methodName, 'Cash');
    expect(report.paymentsByMethod.last.amount, 750);

    await listener.close(force: true);
  });
}
