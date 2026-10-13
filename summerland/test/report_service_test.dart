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
}
