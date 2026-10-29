import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import 'app_destinations.dart';
import 'app_widgets.dart';
import 'shop_logo.dart';

/// Persistent, app-wide navigation shell.
///
/// Desktop / wide screens get an always-visible grouped navigation panel next
/// to the content. Mobile / narrow screens get a hamburger drawer plus a
/// bottom navigation bar for the most-used destinations.
///
/// On Android, the system back button navigates to the Home screen when on a
/// different top-level destination, and exits the app only from the Home
/// screen.
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

  /// Resets the remembered navigation scroll positions. Intended for tests so
  /// state does not leak between cases.
  @visibleForTesting
  static void resetNavScrollForTest() => _NavScroll.reset();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isDesktop = width >= 960;

    // On the home screen the system back button should exit the app normally.
    // On any other top-level screen it should navigate back to Home first.
    final bool isHome = destinationId == 'home';

    Widget scaffold;

    // Desktop layout: persistent side rail + content column.
    if (isDesktop) {
      scaffold = Scaffold(
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
                  const OfflineBanner(),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout: drawer + bottom navigation bar.
      scaffold = Scaffold(
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
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: body),
          ],
        ),
      );
    }

    // When already on Home, let the system back button exit the app.
    if (isHome) return scaffold;

    // On every other top-level screen, intercept the back gesture and
    // navigate to Home instead of exiting.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppDestinations.open(context, 'home');
        }
      },
      child: scaffold,
    );
  }
}

/// Persistent scroll positions for the navigation panels.
///
/// Navigating calls [AppDestinations.open], which replaces the whole route and
/// therefore rebuilds (and disposes) the nav panel; the drawer also disposes
/// its list every time it closes. A plain [ScrollController] loses its offset
/// when detached, so the last offset is remembered here and re-applied when the
/// list is rebuilt.
class _NavScroll {
  _NavScroll._();

  static final ScrollController rail = ScrollController();
  static final ScrollController drawer = ScrollController();

  static double railOffset = 0;
  static double drawerOffset = 0;

  /// Groups the user has collapsed in the navigation panel.
  ///
  /// Navigating rebuilds (and disposes) the whole nav panel, so the collapsed
  /// choice is remembered here to survive moving between modules.
  static final Set<String> collapsedGroups = {};

  /// Restores the remembered offset once the controller has attached to a new
  /// scrollable.
  static void restore(ScrollController controller, double offset) {
    if (!controller.hasClients) return;
    final double bounded = offset.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    if (bounded != controller.offset) controller.jumpTo(bounded);
  }

  @visibleForTesting
  static void reset() {
    railOffset = 0;
    drawerOffset = 0;
    collapsedGroups.clear();
    if (rail.hasClients) rail.jumpTo(0);
    if (drawer.hasClients) drawer.jumpTo(0);
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
  /// Groups whose destinations are shown as plain standalone tiles instead
  /// of a labelled, collapsible section: the core entry point (Home) and
  /// the end-of-list utility (Settings).
  static const Set<String> _ungroupedSections = {'Overview', 'System'};

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Debouncer _searchDebounce = Debouncer();

  /// Which groups the user has collapsed. Stored on [_NavScroll] rather than
  /// in this widget so the choice survives both the ListView disposing
  /// off-screen children and the panel being rebuilt on navigation.
  Set<String> get _collapsedGroups => _NavScroll.collapsedGroups;

  ScrollController get _scrollController =>
      widget.inDrawer ? _NavScroll.drawer : _NavScroll.rail;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_rememberScroll);

    // Re-apply the remembered offset once the rebuilt list has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _NavScroll.restore(
        _scrollController,
        widget.inDrawer ? _NavScroll.drawerOffset : _NavScroll.railOffset,
      );
    });
  }

  void _rememberScroll() {
    if (!_scrollController.hasClients) return;

    if (widget.inDrawer) {
      _NavScroll.drawerOffset = _scrollController.offset;
    } else {
      _NavScroll.railOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _scrollController.removeListener(_rememberScroll);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleGroup(String group) {
    setState(() {
      if (!_collapsedGroups.remove(group)) {
        _collapsedGroups.add(group);
      }
    });
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

    // Home sits at the top on its own; Settings is pinned at the bottom.
    // Both skip the grouped sections so neither gets a section header.
    final List<AppNavigationItem> topItems = visible
        .where((item) => item.id == 'home')
        .toList();
    final List<AppNavigationItem> bottomItems = visible
        .where((item) => item.id == 'settings')
        .toList();

    final List<Widget> rows = [];
    String? previousGroup;
    final List<AppNavigationItem> groupItems = [];

    void flushGroup() {
      final String? group = previousGroup;

      if (group == null) return;

      rows.add(
        _NavGroup(
          title: group,
          items: List.of(groupItems),
          selectedId: widget.selectedId,
          inDrawer: widget.inDrawer,
          // Searching should reveal matches, so groups open while a query
          // is active and the user is not forced to expand each one.
          forceExpanded: query.isNotEmpty,
          expanded: !_collapsedGroups.contains(group),
          onToggle: () => _toggleGroup(group),
        ),
      );

      groupItems.clear();
    }

    for (final item in visible) {
      // Home and Settings are rendered outside the sections.
      if (_ungroupedSections.contains(item.group)) continue;

      if (item.group != previousGroup) {
        flushGroup();
        previousGroup = item.group;
      }

      groupItems.add(item);
    }

    flushGroup();

    final List<Widget> navChildren = [
      ...topItems.map(
        (item) => _NavTile(
          item: item,
          selected: item.id == widget.selectedId,
          inDrawer: widget.inDrawer,
        ),
      ),
      if (topItems.isNotEmpty && rows.isNotEmpty) const SizedBox(height: 4),
      ...rows,
      if (bottomItems.isNotEmpty) ...[
        const SizedBox(height: 4),
        const Divider(height: 17, indent: 14, endIndent: 14),
        ...bottomItems.map(
          (item) => _NavTile(
            item: item,
            selected: item.id == widget.selectedId,
            inDrawer: widget.inDrawer,
          ),
        ),
      ],
    ];

    final Color? railColor = widget.inDrawer
        ? null
        : theme.colorScheme.surfaceContainerLow;

    // The header sits on its own opaque surface so a hovered or selected
    // row scrolling underneath can never tint the logo or search field. It
    // matches the panel it lives in: the rail's tint, or the drawer surface.
    final Color headerColor = railColor ?? theme.colorScheme.surface;

    return Material(
      color: railColor ?? Colors.transparent,
      child: SizedBox(
        width: widget.inDrawer ? null : 268,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: headerColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _searchDebounce.run(() => setState(() => _query = value));
                      },
                      decoration: InputDecoration(
                        hintText: context.tr('Search pages…'),
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
                                tooltip: context.tr('Clear search'),
                                onPressed: () {
                                  _searchDebounce.cancel();
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: navChildren.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('No pages match “{0}”', [_query]),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                      children: navChildren,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 80),
        child: Center(child: ShopLogo(radius: 10, constrain: false)),
      ),
    );
  }
}

class _NavGroup extends StatefulWidget {
  const _NavGroup({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.inDrawer,
    required this.forceExpanded,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final List<AppNavigationItem> items;
  final String selectedId;
  final bool inDrawer;
  final bool forceExpanded;

  /// Whether the group is open, owned by the panel so the state is not lost
  /// when the list disposes off-screen children.
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.expanded ? 1 : 0,
  );

  // Eases the height so the collapse feels springy rather than linear.
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // The content fades slightly ahead of the height so it never looks
  // squashed while on screen.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0, 0.55, curve: Curves.easeIn),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool open = widget.forceExpanded || widget.expanded;
    final bool wasOpen = oldWidget.forceExpanded || oldWidget.expanded;

    if (open == wasOpen) return;

    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // While searching the group is pinned open so matches are never hidden.
    final bool expanded = widget.forceExpanded || widget.expanded;

    final bool hasSelection = widget.items.any(
      (item) => item.id == widget.selectedId,
    );

    final Widget tiles = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.items
          .map(
            (item) => _NavTile(
              item: item,
              selected: item.id == widget.selectedId,
              inDrawer: widget.inDrawer,
            ),
          )
          .toList(),
    );

    final Color labelColor = hasSelection
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(widget.title).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: labelColor,
              ),
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Icon(Icons.expand_more_rounded, size: 18, color: labelColor),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: widget.title,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.forceExpanded ? null : widget.onToggle,
            child: header,
          ),
        ),
        ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Once the collapse has fully settled the tiles leave the
              // tree, so nothing hidden stays tappable or findable.
              final settled = _controller.isDismissed && !expanded;

              return SizeTransition(
                sizeFactor: _size,
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: _fade,
                  child: settled
                      ? const SizedBox(width: double.infinity)
                      : tiles,
                ),
              );
            },
          ),
        ),
      ],
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
    final scheme = theme.colorScheme;

    final Color foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (selected) return;

            final navigator = Navigator.of(context);

            if (inDrawer) {
              navigator.pop();
            }

            AppDestinations.open(navigator.context, item.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // A slim accent bar marks the active page.
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: selected ? 3 : 0,
                    decoration: BoxDecoration(
                      color: scheme.onSecondaryContainer,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                  child: Row(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 21,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: foreground,
                          ),
                          child: Text(
                            context.tr(item.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          label: context.tr(item.title),
        );
      }).toList(),
    );
  }
}
