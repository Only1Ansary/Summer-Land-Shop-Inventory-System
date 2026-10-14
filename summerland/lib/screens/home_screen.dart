import 'package:flutter/material.dart';

import '../services/pinned_modules_service.dart';
import '../ui/app_destinations.dart';
import '../ui/app_shell.dart';
import '../ui/app_theme.dart';
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

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  final PinnedModulesService _pinnedService = PinnedModulesService();

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
      title: 'Sale Invoices',
      subtitle: 'View & search invoices',
      icon: Icons.receipt_long_rounded,
      destinationId: 'sale-invoices',
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
      title: 'Purchases',
      subtitle: 'View & search invoices',
      icon: Icons.shopping_bag_rounded,
      destinationId: 'purchase-invoices',
    ),
    _HomeTile(
      title: 'New Purchase',
      subtitle: 'Record a purchase',
      icon: Icons.shopping_cart_checkout_rounded,
      destinationId: 'add-purchase',
    ),
    _HomeTile(
      title: 'Suppliers',
      subtitle: 'Manage suppliers',
      icon: Icons.factory_rounded,
      destinationId: 'suppliers',
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
    _HomeTile(
      title: 'Employees',
      subtitle: 'Staff & payroll',
      icon: Icons.badge_rounded,
      destinationId: 'employees',
    ),
  ];

  List<String> _pinnedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  Future<void> _loadPinned() async {
    final ids = await _pinnedService.load();

    if (!mounted) return;

    setState(() {
      _pinnedIds = ids;
      _isLoading = false;
    });
  }

  Future<void> _togglePin(String destinationId) async {
    final isPinned = _pinnedIds.contains(destinationId);

    if (!isPinned && _pinnedIds.length >= PinnedModulesService.maxPinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can pin up to 4 modules. Unpin one first.'),
        ),
      );

      return;
    }

    setState(() {
      if (isPinned) {
        _pinnedIds = [..._pinnedIds]..remove(destinationId);
      } else {
        _pinnedIds = [..._pinnedIds, destinationId];
      }
    });

    await _pinnedService.save(_pinnedIds);
  }

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

        final pinnedTiles = _tiles
            .where((tile) => _pinnedIds.contains(tile.destinationId))
            .toList();

        final otherTiles = _tiles
            .where((tile) => !_pinnedIds.contains(tile.destinationId))
            .toList();

        final atLimit = _pinnedIds.length >= PinnedModulesService.maxPinned;

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
            if (!_isLoading && pinnedTiles.isNotEmpty) ...[
              const SectionHeader(title: 'Pinned', subtitle: 'Your shortcuts'),
              const SizedBox(height: 12),
              _buildGrid(
                columns: columns,
                tiles: pinnedTiles,
                atLimit: atLimit,
              ),
              const SizedBox(height: 20),
            ],
            const SectionHeader(
              title: 'All Modules',
              subtitle: 'Tap the star to pin up to 4 shortcuts',
            ),
            const SizedBox(height: 12),
            _buildGrid(columns: columns, tiles: otherTiles, atLimit: atLimit),
          ],
        );
      },
    );
  }

  Widget _buildGrid({
    required int columns,
    required List<_HomeTile> tiles,
    required bool atLimit,
  }) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: columns >= 3 ? 1.25 : 1.0,
      children: [
        for (final tile in tiles)
          _HomeTileCard(
            tile: tile,
            pinned: _pinnedIds.contains(tile.destinationId),
            atLimit: atLimit,
            onTogglePin: () => _togglePin(tile.destinationId),
          ),
      ],
    );
  }
}

class _HomeTileCard extends StatelessWidget {
  const _HomeTileCard({
    required this.tile,
    required this.pinned,
    required this.atLimit,
    required this.onTogglePin,
  });

  final _HomeTile tile;
  final bool pinned;
  final bool atLimit;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppDestinations.open(context, tile.destinationId),
        child: Stack(
          children: [
            Padding(
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
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                onPressed: onTogglePin,
                tooltip: pinned
                    ? 'Unpin from Home'
                    : atLimit
                    ? 'You can pin up to 4 modules'
                    : 'Pin to Home',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  pinned ? Icons.star_rounded : Icons.star_border_rounded,
                  color: pinned
                      ? AppPalette.warning
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
