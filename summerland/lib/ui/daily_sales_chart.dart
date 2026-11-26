import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/reports/sales_report.dart';
import 'app_widgets.dart';


/// Bar chart of net sales per day. Scrolls horizontally for long ranges.
/// Long-press / hover a bar to see the exact day and amount.
class DailySalesChart extends StatelessWidget {
  const DailySalesChart({
    super.key,
    required this.days,
    required this.format,
  });

  final List<DailySales> days;

  /// Formats an amount (pass the app's `money` function).
  final String Function(double) format;

  static const double _chartHeight = 140;
  static const double _barWidth = 22;
  static const double _gap = 6;

  String _short(DateTime d) {
    final local = inAppTimeZone(d);

    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    final hasSales = days.any((d) => d.netSales > 0);

    if (days.isEmpty || !hasSales) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(context.tr('No sales in this period'))),
      );
    }

    final theme = Theme.of(context);
    final maxValue =
    days.map((d) => d.netSales).reduce((a, b) => a > b ? a : b);
    final best = days.reduce((a, b) => a.netSales >= b.netSales ? a : b);
    final total = days.fold<double>(0, (sum, d) => sum + d.netSales);
    final average = total / days.length;
    final showMonth = days.length > 31;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: false,
          child: SizedBox(
            height: _chartHeight + 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: Tooltip(
                      message: '${_short(d.date)}  •  ${format(d.netSales)}'
                          '  •  ${d.invoiceCount} ${context.tr('Invoices')}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: _barWidth,
                            height: d.netSales <= 0
                                ? 2
                                : (d.netSales / maxValue) * _chartHeight,
                            decoration: BoxDecoration(
                              color: d == best
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary
                                  .withValues(alpha: 0.45),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: _barWidth + _gap,
                            child: Text(
                              showMonth
                                  ? _short(d.date)
                                  : '${inAppTimeZone(d.date).day}',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Fact(
                label: context.tr('Best day'),
                value: '${_short(best.date)} · ${format(best.netSales)}',
              ),
            ),
            Expanded(
              child: _Fact(
                label: context.tr('Daily average'),
                value: format(average),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}