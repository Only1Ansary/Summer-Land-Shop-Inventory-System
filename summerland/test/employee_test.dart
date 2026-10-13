import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/employee.dart';
import 'package:summerland/models/employee_month.dart';
import 'package:summerland/models/employee_payment.dart';
import 'package:summerland/screens/employees/add_employee_screen.dart';
import 'package:summerland/screens/employees/employee_history_screen.dart';
import 'package:summerland/screens/employees/employees_screen.dart';
import 'package:summerland/screens/home_screen.dart';
import 'package:summerland/ui/app_destinations.dart';

void main() {
  test('employee parses every stored field', () {
    final employee = Employee.fromJson({
      'id': 4,
      'name': 'Mona',
      'salary': 5000,
      'target': 20000,
      'bonus': 250.5,
      'achievedTarget': true,
      'totalSales': 12000.75,
    });

    expect(employee.id, 4);
    expect(employee.name, 'Mona');
    expect(employee.salary, 5000);
    expect(employee.target, 20000);
    expect(employee.bonus, 250.5);
    expect(employee.achievedTarget, isTrue);
    expect(employee.totalSales, 12000.75);
    expect(employee.totalCompensation, 5250.5);
  });

  test('employee left-to-pay falls back to the full obligation', () {
    final employee = Employee.fromJson({
      'id': 4,
      'name': 'Mona',
      'salary': 5000,
      'target': 20000,
      'bonus': 250,
      'bonusType': 0,
      'achievedTarget': true,
      'totalSales': 12000,
    });

    // Without the server's figures, everything is still owed (bonus is fixed).
    expect(employee.paidThisMonth, isNull);
    expect(employee.leftToPay, isNull);
    expect(employee.effectiveLeftToPay, 5250);
  });

  test('employee uses the server-sided left-to-pay figures when present', () {
    final employee = Employee.fromJson({
      'id': 4,
      'name': 'Mona',
      'salary': 5000,
      'target': 20000,
      'bonus': 250,
      'bonusType': 0,
      'achievedTarget': true,
      'totalSales': 12000,
      'paidThisMonth': 3000,
      'leftToPay': 2250,
    });

    expect(employee.paidThisMonth, 3000);
    expect(employee.leftToPay, 2250);
    expect(employee.effectiveLeftToPay, 2250);
  });

  test('a percentage bonus is worked out from total sales', () {
    final percentEmployee = Employee(
      id: 1,
      name: 'Mona',
      salary: 5000,
      target: 20000,
      bonus: 10,
      bonusType: BonusType.percentage,
      achievedTarget: false,
      totalSales: 15000,
    );

    expect(percentEmployee.bonusAmount, 1500);
    expect(percentEmployee.totalCompensation, 6500);

    final fixedEmployee = Employee(
      id: 1,
      name: 'Mona',
      salary: 5000,
      target: 20000,
      bonus: 250,
      achievedTarget: false,
      totalSales: 15000,
    );

    expect(fixedEmployee.bonusAmount, 250);
    expect(fixedEmployee.totalCompensation, 5250);
  });

  test('a parsed percentage bonus type is recognised', () {
    final employee = Employee.fromJson({
      'id': 1,
      'name': 'Mona',
      'salary': 5000,
      'target': 20000,
      'bonus': 5,
      'bonusType': 1,
      'achievedTarget': false,
      'totalSales': 10000,
    });

    expect(employee.bonusType, BonusType.percentage);
    expect(employee.bonusAmount, 500);
  });

  test('employee payment parses its stored fields', () {
    final payment = EmployeePayment.fromJson({
      'id': 2,
      'employeeId': 4,
      'amount': 6250.5,
      'paidAt': '2026-03-01T08:00:00Z',
    });

    expect(payment.id, 2);
    expect(payment.employeeId, 4);
    expect(payment.amount, 6250.5);
    expect(payment.paidAt.toUtc(), DateTime.utc(2026, 3, 1, 8));
  });

  test('the target badge follows the live sales figures', () {
    final reached = Employee(
      id: 1,
      name: 'Mona',
      salary: 5000,
      target: 20000,
      bonus: 0,
      achievedTarget: false,
      totalSales: 20000,
    );

    expect(reached.reachedTarget, isTrue);

    final below = Employee(
      id: 1,
      name: 'Mona',
      salary: 5000,
      target: 20000,
      bonus: 0,
      achievedTarget: false,
      totalSales: 19999.99,
    );

    expect(below.reachedTarget, isFalse);

    // Without a target there is nothing to reach.
    final noTarget = Employee(
      id: 1,
      name: 'Mona',
      salary: 5000,
      target: 0,
      bonus: 0,
      achievedTarget: false,
      totalSales: 5000,
    );

    expect(noTarget.reachedTarget, isFalse);
  });

  test('employees destination is registered', () {
    expect(AppDestinations.byId('employees').title, 'Employees');
    expect(AppDestinations.byId('employees').builder(), isA<EmployeesScreen>());
  });

  testWidgets('home shows an Employees tile', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('Employees'), findsWidgets);
  });

  testWidgets('adding an employee asks for name, salary and target only', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddEmployeeScreen()));
    await tester.pump();

    final addButton = find.widgetWithText(FilledButton, 'Add Employee');

    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    expect(find.text('Enter the employee name.'), findsOneWidget);
    expect(find.text('Enter the salary.'), findsOneWidget);
    expect(find.text('Enter the target.'), findsOneWidget);

    // Bonus and the recorded sales figures are not entry fields yet.
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('Total Sales'), findsNothing);
    expect(find.text('Achieved target'), findsNothing);
  });

  test('a monthly record parses and labels its month', () {
    final record = EmployeeMonth.fromJson({
      'id': 3,
      'employeeId': 1,
      'year': 2026,
      'month': 3,
      'totalSales': 18000,
      'bonus': 400.25,
      'achievedTarget': true,
    });

    expect(record.employeeId, 1);
    expect(record.label, 'March 2026');
    expect(record.totalSales, 18000);
    expect(record.bonus, 400.25);
    expect(record.achievedTarget, isTrue);
  });

  testWidgets('a month tile shows sales, target and bonus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmployeeMonthTile(
            target: 20000,
            bonusType: BonusType.fixed,
            bonusValue: 400.25,
            record: EmployeeMonth(
              id: 1,
              employeeId: 1,
              year: 2026,
              month: 3,
              totalSales: 18000,
              bonus: 400.25,
              achievedTarget: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('BELOW TARGET'), findsOneWidget);
    expect(find.text('18000.00 EGP'), findsOneWidget);
    expect(find.text('20000.00 EGP'), findsOneWidget);
    expect(find.text('400.25 EGP'), findsOneWidget);
  });

  testWidgets('a month tile shows target met when sales reach the target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmployeeMonthTile(
            target: 20000,
            bonusType: BonusType.percentage,
            bonusValue: 10,
            record: EmployeeMonth(
              id: 1,
              employeeId: 1,
              year: 2026,
              month: 3,
              totalSales: 25000,
              bonus: 0,
              // Stored flag is stale; the live figures decide the badge.
              achievedTarget: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('TARGET MET'), findsOneWidget);
    expect(find.text('BELOW TARGET'), findsNothing);

    // A 10% bonus on 25000 of sales is 2500.
    expect(find.text('2500.00 EGP'), findsOneWidget);
  });

  testWidgets('editing an employee keeps sales figures view-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddEmployeeScreen(
          employee: Employee(
            id: 1,
            name: 'Mona',
            salary: 5000,
            target: 20000,
            bonus: 250.5,
            achievedTarget: true,
            totalSales: 22000.75,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Employee'), findsOneWidget);
    expect(find.text('Bonus'), findsOneWidget);
    expect(find.text('250.5'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Total sales and the target flag are shown, but cannot be edited.
    expect(find.text('Recorded from sales (view only)'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('22000.75 EGP'), findsOneWidget);
    expect(find.text('TARGET MET'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Total Sales'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Achieved target'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('editing lets the bonus be a fixed amount or a percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddEmployeeScreen(
          employee: Employee(
            id: 1,
            name: 'Mona',
            salary: 5000,
            target: 20000,
            bonus: 250.5,
            achievedTarget: false,
            totalSales: 22000.75,
          ),
        ),
      ),
    );
    await tester.pump();

    // Fixed by default: the bonus is entered in EGP.
    expect(find.text('Fixed amount'), findsOneWidget);
    expect(find.text('Percent of sales'), findsOneWidget);
    expect(find.text('Bonus'), findsOneWidget);

    final percentSegment = find.text('Percent of sales');
    await tester.ensureVisible(percentSegment);
    await tester.tap(percentSegment);
    await tester.pump();

    // Switching to a percent changes the field's label and suffix.
    expect(find.text('Bonus Percent'), findsOneWidget);
    expect(find.text('Bonus'), findsNothing);
  });
}
