import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_destinations.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = <(String, IconData, String)>[
      (context.tr('Sales Report'), Icons.point_of_sale_rounded, 'report-sales'),
      (
        context.tr('Inventory Report'),
        Icons.inventory_2_rounded,
        'report-inventory',
      ),
      (
        context.tr('Low Stock Report'),
        Icons.warning_amber_rounded,
        'report-low-stock',
      ),
      (
        context.tr('Stock Movements'),
        Icons.swap_vert_rounded,
        'report-movements',
      ),
      (
        context.tr('Best Selling'),
        Icons.trending_up_rounded,
        'report-best-selling',
      ),
      (context.tr('Employees Report'), Icons.badge_rounded, 'report-employees'),
    ];

    return AppShell(
      title: context.tr('Reports'),
      destinationId: 'reports',
      body: WideContent(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 2 : 1;
            final spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: reports.map((report) {
                    return SizedBox(
                      width: cardWidth,
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              report.$2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            report.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                          ),
                          onTap: () {
                            AppDestinations.open(context, report.$3);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
