import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../services/bottom_nav_service.dart';
import '../../ui/app_destinations.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

/// Lets the user choose and order the shortcuts shown in the phone bottom bar.
class BottomNavigationSettingsScreen extends StatelessWidget {
  const BottomNavigationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      title: context.tr('Bottom navigation bar'),
      destinationId: 'settings',
      body: WideContent(
        child: ValueListenableBuilder<List<String>>(
          valueListenable: BottomNavService.instance.ids,
          builder: (context, ids, _) {
            final extras = ids
                .where((id) => id != BottomNavService.homeId)
                .toList();
            final available = AppDestinations.items
                .where((item) => !ids.contains(item.id))
                .toList();
            final canAdd = ids.length < BottomNavService.maxDestinations;
            final canRemove =
                extras.length > BottomNavService.minDestinations - 1;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader(
                  title: context.tr('Shown in the bar'),
                  subtitle: context.tr(
                    'Home is always shown. Drag to reorder the rest.',
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.home_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('Home'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('Always shown'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.lock_outline, size: 18),
                          ],
                        ),
                      ),
                      if (extras.isNotEmpty) ...[
                        const Divider(height: 1),
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            final next = List<String>.of(ids);
                            final item = next.removeAt(oldIndex + 1);
                            next.insert(newIndex + 1, item);

                            BottomNavService.instance.save(next);
                          },
                          children: [
                            for (var i = 0; i < extras.length; i++)
                              _BarItemTile(
                                key: ValueKey(extras[i]),
                                item: AppDestinations.byId(extras[i]),
                                index: i,
                                canRemove: canRemove,
                                onRemove: () => BottomNavService.instance.save(
                                  ids.where((id) => id != extras[i]),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: context.tr('Add a shortcut'),
                  subtitle: available.isEmpty
                      ? context.tr('Every shortcut is already in the bar.')
                      : context.tr('Tap a page to add it to the bar.'),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final item in available)
                        InkWell(
                          onTap: canAdd
                              ? () => BottomNavService.instance.save([
                                    ...ids,
                                    item.id,
                                  ])
                              : null,
                          child: Opacity(
                            opacity: canAdd ? 1.0 : 0.5,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(item.icon),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      context.tr(item.title),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.add),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarItemTile extends StatelessWidget {
  const _BarItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final AppNavigationItem item;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(item.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(item.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('Remove'),
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}