import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/pinned_modules_service.dart';
import '../services/shop_profile_service.dart';
import '../ui/app_destinations.dart';
import '../ui/app_shell.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import '../ui/home_modules.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Home'),
      destinationId: 'home',
      body: const _HomeDashboard(),
    );
  }
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  final PinnedModulesService _pinnedService = PinnedModulesService();

  int _maxPinned = PinnedModulesService.defaultMaxPinned;

  List<String> _pinnedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  Future<void> _loadPinned() async {
    final pinned = await _pinnedService.load();
    final maxPinned = await _pinnedService.loadMaxPinned();

    if (!mounted) return;

    setState(() {
      _pinnedIds = pinned;
      _maxPinned = maxPinned;
      _isLoading = false;
    });
  }

  Future<void> _togglePin(String destinationId) async {
    final isPinned = _pinnedIds.contains(destinationId);

    if (!isPinned && _pinnedIds.length >= _maxPinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('You can pin up to {0} modules. Unpin one first.', [
              _maxPinned,
            ]),
          ),
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

        final pinnedTiles = homeModules
            .where((tile) => _pinnedIds.contains(tile.destinationId))
            .toList();

        final otherTiles = homeModules
            .where((tile) => !_pinnedIds.contains(tile.destinationId))
            .toList();

        final atLimit = _pinnedIds.length >= _maxPinned;

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
                          context.tr('Welcome to {0}', [
                            ShopProfileService.instance.profile.value.name,
                          ]),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            'Manage products, inventory and sales from one place.',
                          ),
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
              SectionHeader(
                title: context.tr('Pinned'),
                subtitle: context.tr('Your shortcuts'),
              ),
              const SizedBox(height: 12),
              _buildGrid(
                columns: columns,
                tiles: pinnedTiles,
                atLimit: atLimit,
              ),
              const SizedBox(height: 20),
            ],
            SectionHeader(
              title: context.tr('All Modules'),
              subtitle: context.tr('Tap the star to pin up to {0} shortcuts', [
                _maxPinned,
              ]),
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
    required List<HomeModule> tiles,
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
            maxPinned: _maxPinned,
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
    required this.maxPinned,
    required this.onTogglePin,
  });

  final HomeModule tile;
  final bool pinned;
  final bool atLimit;
  final int maxPinned;
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
                    context.tr(tile.title),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(tile.subtitle),
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
                    ? context.tr('Unpin from Home')
                    : atLimit
                    ? context.tr('You can pin up to {0} modules', [maxPinned])
                    : context.tr('Pin to Home'),
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
