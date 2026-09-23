import 'package:flutter/material.dart';

import '../ui/app_destinations.dart';
import '../ui/app_shell.dart';
import '../ui/app_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Home',
      destinationId: 'home',
      body: const _HomeDashboard(),
    );
  }
}

class _HomeTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final String destinationId;

  const _HomeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destinationId,
  });
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  static const List<_HomeTile> _tiles = [
    _HomeTile(
      title: 'Products',
      subtitle: 'Catalog & variants',
      icon: Icons.inventory_2_rounded,
      destinationId: 'products',
    ),
    _HomeTile(
      title: 'Inventory',
      subtitle: 'Stock by location',
      icon: Icons.warehouse_rounded,
      destinationId: 'inventory',
    ),
    _HomeTile(
      title: 'New Sale',
      subtitle: 'Create an invoice',
      icon: Icons.point_of_sale_rounded,
      destinationId: 'sales',
    ),
    _HomeTile(
      title: 'Stock Transfers',
      subtitle: 'Move stock around',
      icon: Icons.swap_horiz_rounded,
      destinationId: 'transfers',
    ),
    _HomeTile(
      title: 'Returns',
      subtitle: 'Process returns',
      icon: Icons.assignment_return_rounded,
      destinationId: 'returns',
    ),
    _HomeTile(
      title: 'Reports',
      subtitle: 'Sales & stock insights',
      icon: Icons.assessment_rounded,
      destinationId: 'reports',
    ),
    _HomeTile(
      title: 'Categories',
      subtitle: 'Organise products',
      icon: Icons.category_rounded,
      destinationId: 'categories',
    ),
    _HomeTile(
      title: 'Colours',
      subtitle: 'Colour options',
      icon: Icons.palette_rounded,
      destinationId: 'colours',
    ),
    _HomeTile(
      title: 'Sizes',
      subtitle: 'Size options',
      icon: Icons.straighten_rounded,
      destinationId: 'sizes',
    ),
    _HomeTile(
      title: 'Locations',
      subtitle: 'Store locations',
      icon: Icons.location_on_rounded,
      destinationId: 'locations',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 34,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Summerland',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage products, inventory and sales from one place.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Quick Access',
              subtitle: 'Jump into any module',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns >= 3 ? 1.25 : 1.0,
              children: [
                for (final tile in _tiles) _HomeTileCard(tile: tile),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HomeTileCard extends StatelessWidget {
  const _HomeTileCard({required this.tile});

  final _HomeTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppDestinations.open(context, tile.destinationId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tile.icon,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tile.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tile.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}