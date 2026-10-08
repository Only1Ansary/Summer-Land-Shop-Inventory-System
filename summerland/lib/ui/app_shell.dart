import 'package:flutter/material.dart';

import 'app_destinations.dart';

/// Persistent, app-wide navigation shell.
///
/// Desktop / wide screens get an always-visible grouped navigation panel next
/// to the content. Mobile / narrow screens get a hamburger drawer plus a
/// bottom navigation bar for the most-used destinations.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.destinationId,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final String destinationId;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isDesktop = width >= 960;

    // Desktop layout: persistent side rail + content column.
    if (isDesktop) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            _AppNavPanel(
              items: AppDestinations.items,
              selectedId: destinationId,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Column(
                children: [
                  AppBar(title: Text(title), actions: actions),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout: drawer + bottom navigation bar.
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: Drawer(
        child: SafeArea(
          child: _AppNavPanel(
            items: AppDestinations.items,
            selectedId: destinationId,
            inDrawer: true,
          ),
        ),
      ),
      bottomNavigationBar: _AppBottomNav(selectedId: destinationId),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Renders the grouped destination list for both rail and drawer layouts.
class _AppNavPanel extends StatefulWidget {
  const _AppNavPanel({
    required this.items,
    required this.selectedId,
    this.inDrawer = false,
  });

  final List<AppNavigationItem> items;
  final String selectedId;
  final bool inDrawer;

  @override
  State<_AppNavPanel> createState() => _AppNavPanelState();
}

class _AppNavPanelState extends State<_AppNavPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String query = _query.trim().toLowerCase();
    final List<AppNavigationItem> visible = query.isEmpty
        ? widget.items
        : widget.items
              .where(
                (item) =>
                    item.title.toLowerCase().contains(query) ||
                    item.group.toLowerCase().contains(query),
              )
              .toList();

    final List<Widget> rows = [];
    String? previousGroup;

    for (final item in visible) {
      if (item.group != previousGroup) {
        rows.add(_GroupLabel(item.group));
        previousGroup = item.group;
      }

      rows.add(
        _NavTile(
          item: item,
          selected: item.id == widget.selectedId,
          inDrawer: widget.inDrawer,
        ),
      );
    }

    final Color? railColor = widget.inDrawer
        ? null
        : theme.colorScheme.surfaceContainerLow;

    return Material(
      color: railColor ?? Colors.transparent,
      child: SizedBox(
        width: widget.inDrawer ? null : 268,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search pages…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No pages match “$_query”',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                      children: rows,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: theme.colorScheme.onPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summerland',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Inventory & POS',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.inDrawer,
  });

  final AppNavigationItem item;
  final bool selected;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(selected ? item.selectedIcon : item.icon, size: 22),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      selectedColor: theme.colorScheme.onSecondaryContainer,
      textColor: theme.colorScheme.onSurfaceVariant,
      iconColor: theme.colorScheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        if (selected) return;

        final navigator = Navigator.of(context);

        if (inDrawer) {
          navigator.pop();
        }

        AppDestinations.open(navigator.context, item.id);
      },
    );
  }
}

/// Bottom navigation bar for phones with the most-used destinations.
class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({required this.selectedId});

  final String selectedId;

  int _selectedIndex() {
    const order = AppDestinations.bottomNavIds;

    if (AppDestinations.reportIds.contains(selectedId)) {
      return 4;
    }

    final int index = order.indexOf(selectedId);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return NavigationBar(
      selectedIndex: _selectedIndex(),
      onDestinationSelected: (index) {
        final String id = AppDestinations.bottomNavIds[index];
        AppDestinations.open(navigator.context, id);
      },
      destinations: AppDestinations.bottomNavIds.map((id) {
        final item = AppDestinations.byId(id);
        return NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: item.title,
        );
      }).toList(),
    );
  }
}
