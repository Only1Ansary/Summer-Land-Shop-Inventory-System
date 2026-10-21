import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/connectivity_service.dart';
import 'app_theme.dart';

/// Renders a number as a two-decimal money string with the EGP currency.
String money(num value) => '${value.toStringAsFixed(2)} EGP';

/// Renders an unpaid debt as a negative figure (e.g. -100.00 EGP).
String moneyNegative(num value) =>
    value == 0 ? '0.00 EGP' : '-${value.toStringAsFixed(2)} EGP';

/// Renders a discount percentage without a needless .0 (e.g. 10%).
String percentLabel(double value) =>
    value % 1 == 0 ? '${value.toInt()}%' : '$value%';

/// Strips the time component from a date.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Default start of a date filter that has not been set: yesterday.
DateTime defaultFilterFromDate() =>
    dateOnly(DateTime.now().subtract(const Duration(days: 1)));

/// Default end of a date filter that has not been set: today.
DateTime defaultFilterToDate() => dateOnly(DateTime.now());

/// Pushes a screen using an instant (zero-duration) route.
///
/// Animated route transitions leave the covered route offstage while its
/// subtree rebuilds; on desktop the mouse tracker hit-tests the tree during
/// that window and can touch a scaffold body that has not been laid out yet,
/// throwing "Cannot hit test a render box with no size". Using an instant
/// route removes the outgoing screen in the same frame, which avoids the race.
Future<T?> pushScreen<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => builder(context),
    ),
  );
}

/// Loading state used consistently across all screens.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.tr(message ?? 'Loading…'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin bar that appears while the backend is unreachable, noting that
/// the data on screen is the last copy the app managed to load.
///
/// It listens to [ConnectivityService.online] and hides itself the moment
/// the server comes back, so it never takes space when all is well.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.online,
      builder: (context, online, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: online
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  color: AppPalette.warning.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: AppPalette.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(
                            'No connection to the server. Showing the last '
                            'loaded data.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Shared empty-state pattern for list / report screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Shared error state with an optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppPalette.danger,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.tr('Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bold section title used to structure dense screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ?trailing,
        ],
      ),
    );
  }
}

/// A [SectionHeader] whose content can be hidden by tapping the header.
///
/// The header and a rotating chevron stay visible while the child collapses,
/// so long reports keep their structure when the reader focuses on one part
/// of the page. Starts expanded unless [initiallyExpanded] says otherwise.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  /// The key under which this section remembers whether it is open.
  ///
  /// A list view disposes its off-screen children, so without this a section
  /// scrolled out of view would spring back to [initiallyExpanded] when the
  /// user scrolls back to it. Persisting the choice in the route's
  /// [PageStorage] keeps open sections open while scrolling.
  String get _storageKey => 'collapsible.${widget.title}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final stored = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey);

    if (stored is bool) _expanded = stored;
  }

  void _toggle() {
    final next = !_expanded;

    setState(() => _expanded = next);

    PageStorage.maybeOf(context)
        ?.writeState(context, next, identifier: _storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.title,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _toggle,
            child: SectionHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Icon(
                  Icons.expand_more_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const SizedBox(height: 8), widget.child],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A compact labelled value card used for report / summary stats.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for [StatGrid].
class StatData {
  const StatData({
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final Color? valueColor;
}

/// Responsive grid of [StatCard]s used by report screens.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats, this.columns = 2});

  final List<StatData> stats;

  /// Number of columns on wide layouts (single column on narrow).
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final perRow = wide ? columns : 1;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (perRow - 1))) / perRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: stat.label,
                    value: stat.value,
                    icon: stat.icon,
                    color: stat.color,
                    valueColor: stat.valueColor,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Two date range buttons used to filter report screens.
class DateFilterBar extends StatelessWidget {
  const DateFilterBar({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.onFrom,
    required this.onTo,
  });

  final String fromLabel;
  final String toLabel;
  final VoidCallback onFrom;
  final VoidCallback onTo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFrom,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(fromLabel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTo,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(toLabel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full month names, used by the month picker and month-scoped reports.
const List<String> monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a year and month as e.g. "October 2026".
String monthLabel(int year, int month) => '${monthNames[month - 1]} $year';

/// A single button that opens a month picker, used by month-scoped reports.
class MonthFilterBar extends StatelessWidget {
  const MonthFilterBar({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

/// Opens a dialog to pick a month, returning the first day of that month.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedMonth = widget.initial.year == _year
        ? widget.initial.month
        : 0;

    return AlertDialog(
      titlePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left),
            tooltip: context.tr('Previous year'),
          ),
          Text('$_year', style: theme.textTheme.titleMedium),
          IconButton(
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right),
            tooltip: context.tr('Next year'),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var month = 1; month <= 12; month++)
              _MonthCell(
                label: context.tr(monthNames[month - 1]),
                selected: month == selectedMonth,
                onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onTap, child: Text(label))
        : OutlinedButton(onPressed: onTap, child: Text(label));
  }
}

/// Small rounded pill used for statuses such as low stock / normal.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Low-stock badge used across product / inventory / report screens.
class LowStockBadge extends StatelessWidget {
  const LowStockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: context.tr('LOW STOCK'),
      color: AppPalette.warning,
      icon: Icons.warning_amber_rounded,
    );
  }
}

/// Footer bar showing the visible item range with previous / next page
/// controls. Hidden when there is nothing to page through.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
  });

  /// Zero-based index of the page being shown.
  final int page;

  /// Number of items shown on each page.
  final int pageSize;

  /// Total number of items across every page.
  final int totalItems;

  /// Called with the requested zero-based page index.
  final ValueChanged<int> onPageChanged;

  int get _pageCount =>
      totalItems == 0 ? 0 : ((totalItems - 1) ~/ pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final start = page * pageSize;
    final end = start + pageSize > totalItems ? totalItems : start + pageSize;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Showing {0}-{1} of {2}', [start + 1, end, totalItems]),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.tr('Previous page'),
                onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  context.tr('Page {0} of {1}', [page + 1, _pageCount]),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: context.tr('Next page'),
                onPressed: page < _pageCount - 1
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Label / value row used on detail screens.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable, centred, width-constrained wrapper for form screens.
class ResponsiveFormPage extends StatelessWidget {
  const ResponsiveFormPage({
    super.key,
    this.maxWidth = AppTheme.pageMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Centres and constrains list content on wide screens.
class WideContent extends StatelessWidget {
  const WideContent({
    super.key,
    this.maxWidth = AppTheme.contentMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Standardised confirmation dialog (delete etc).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(cancelLabel ?? 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr(confirmLabel ?? 'Delete')),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}

/// Standardised single-text-field dialog (add / edit names).
Future<String?> showAppNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _AppNameDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      confirmLabel: confirmLabel ?? ctx.tr('Save'),
    ),
  );
}

/// Standardised amount-entry dialog (pay debt etc). Returns the raw input.
Future<String?> showAppAmountDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String helperText = '',
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _AppAmountDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      helperText: helperText,
      confirmLabel: confirmLabel ?? ctx.tr('Pay'),
    ),
  );
}

class _AppAmountDialog extends StatefulWidget {
  const _AppAmountDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.helperText,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initialValue;
  final String helperText;
  final String confirmLabel;

  @override
  State<_AppAmountDialog> createState() => _AppAmountDialogState();
}

class _AppAmountDialogState extends State<_AppAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: '\u20a6 ',
          helperText: widget.helperText.isEmpty ? null : widget.helperText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _AppNameDialog extends StatefulWidget {
  const _AppNameDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initialValue;
  final String confirmLabel;

  @override
  State<_AppNameDialog> createState() => _AppNameDialogState();
}

class _AppNameDialogState extends State<_AppNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.label,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
