import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/reports/sales_report.dart';
import 'app_widgets.dart';

/// Donut chart showing the share of sales (by amount) per category.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.categories});

  final List<CategorySales> categories;

  static const List<Color> _palette = [
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFF9A825),
    Color(0xFF1E88E5),
    Color(0xFFF4511E),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF00ACC1),
  ];

  String _formatPercent(double fraction) {
    final pct = fraction * 100;
    return pct == pct.roundToDouble()
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = categories
        .where((c) => c.amount > 0)
        .toList(growable: false);

    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 56,
                  color: theme.colorScheme.outline.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sales in this period',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final total = entries.fold<double>(0, (sum, c) => sum + c.amount);

    final slices = <_Slice>[];
    for (var i = 0; i < entries.length; i++) {
      slices.add(
        _Slice(
          color: _palette[i % _palette.length],
          fraction: entries[i].amount / total,
          percentLabel: _formatPercent(entries[i].amount / total),
        ),
      );
    }

    const chartSize = 220.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: chartSize,
              height: chartSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(chartSize),
                    painter: _DonutPainter(slices: slices),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(total),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: chartSize),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        _LegendRow(
                          color: _palette[i % _palette.length],
                          name: entries[i].categoryName,
                          percentLabel: slices[i].percentLabel,
                          amount: entries[i].amount,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice({
    required this.color,
    required this.fraction,
    required this.percentLabel,
  });

  final Color color;
  final double fraction;
  final String percentLabel;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.percentLabel,
    required this.amount,
  });

  final Color color;
  final String name;
  final String percentLabel;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            percentLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(amount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<_Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 52.0;
    final center = (size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth - 8) / 2;
    const startAngle = -1.5707963268; // -90 degrees (top)

    var angle = startAngle;

    for (final slice in slices) {
      if (slice.fraction <= 0) continue;

      final sweep = 6.2831853072 * slice.fraction; // 2 * pi

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.$1, center.$2), radius: radius),
        angle,
        sweep,
        false,
        paint,
      );

      if (slice.fraction >= 0.07) {
        _drawPercent(
          canvas,
          slice.percentLabel,
          center: Offset(center.$1, center.$2),
          radius: radius,
          midAngle: angle + sweep / 2,
        );
      }

      angle += sweep;
    }
  }

  void _drawPercent(
    Canvas canvas,
    String label, {
    required Offset center,
    required double radius,
    required double midAngle,
  }) {
    final position = Offset(
      center.dx + radius * 0.72 * math.cos(midAngle),
      center.dy + radius * 0.72 * math.sin(midAngle),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      position - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
