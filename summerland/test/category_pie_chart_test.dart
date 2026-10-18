import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/models/reports/sales_report.dart';
import 'package:summerland/ui/category_pie_chart.dart';

List<CategorySales> _categories() => [
  CategorySales(categoryName: 'T-Shirts', quantitySold: 12, amount: 4520.5),
  CategorySales(categoryName: 'Jeans', quantitySold: 5, amount: 1999.99),
  CategorySales(
    categoryName: 'Summer Dresses and Swimwear',
    quantitySold: 3,
    amount: 875.25,
  ),
];

void main() {
  Future<void> pumpChart(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [CategoryPieChart(categories: _categories())],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone width stacks the legend under the donut', (tester) async {
    await pumpChart(tester, const Size(360, 690));

    expect(find.byType(CategoryPieChart), findsOneWidget);
    expect(find.text('T-Shirts'), findsOneWidget);

    final overflow = tester.takeException();
    expect(
      overflow,
      isNull,
      reason: 'Sales by Category overflowed on a phone: $overflow',
    );
  });

  testWidgets('wide screen keeps the side-by-side layout', (tester) async {
    await pumpChart(tester, const Size(1280, 900));

    expect(find.byType(CategoryPieChart), findsOneWidget);
    expect(find.text('T-Shirts'), findsOneWidget);

    final overflow = tester.takeException();
    expect(overflow, isNull, reason: 'Sales by Category overflowed: $overflow');
  });
}
