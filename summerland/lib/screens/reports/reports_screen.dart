import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_destinations.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class _ReportEntry {
  const _ReportEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.destinationId,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final String destinationId;
  final Color color;
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final groups = <(String, List<_ReportEntry>)>[
      (
      context.tr('Sales & Team'),
      [
        _ReportEntry(
          title: context.tr('Sales Report'),
          description: context.tr('Revenue, profit and daily trend'),
          icon: Icons.point_of_sale_rounded,
          destinationId: 'report-sales',
          color: scheme.primary,
        ),
        _ReportEntry(
          title: context.tr('Best Selling'),
          description: context.tr('Top products by units sold'),
          icon: Icons.trending_up_rounded,
          destinationId: 'report-best-selling',
          color: AppPalette.success,
        ),
        _ReportEntry(
          title: context.tr('Employees Report'),
          description: context.tr('Targets, bonuses and payroll'),
          icon: Icons.badge_rounded,
          destinationId: 'report-employees',
          color: scheme.tertiary,
        ),
      ],
      ),
      (
      context.tr('Stock & Inventory'),
      [
        _ReportEntry(
          title: context.tr('Inventory Report'),
          description: context.tr('Stock levels and value by location'),
          icon: Icons.inventory_2_rounded,
          destinationId: 'report-inventory',
          color: scheme.secondary,
        ),
        _ReportEntry(
          title: context.tr('Low Stock Report'),
          description: context.tr('Items that need reordering'),
          icon: Icons.warning_amber_rounded,
          destinationId: 'report-low-stock',
          color: AppPalette.warning,
        ),
        _ReportEntry(
          title: context.tr('Stock Movements'),
          description: context.tr('Transfers and refills history'),
          icon: Icons.swap_vert_rounded,
          destinationId: 'report-movements',
          color: Colors.teal,
        ),
      ],
      ),
    ];

    return AppShell(
      title: context.tr('Reports'),
      destinationId: 'reports',
      body: WideContent(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 2 : 1;
            const spacing = 12.0;
            // The list adds 16 of padding on each side.
            final available = constraints.maxWidth - 32;
            final cardWidth = (available - (spacing * (columns - 1))) / columns;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: Text(
                      group.$1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final entry in group.$2)
                        SizedBox(
                          width: cardWidth,
                          child: _ReportCard(entry: entry),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.entry});

  final _ReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppDestinations.open(context, entry.destinationId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: entry.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}