import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Shared building blocks for the report screens, so they all look and
/// behave the same way.

// ---------------------------------------------------------------------------
// Pill: small tinted label with an optional icon.
// ---------------------------------------------------------------------------
class ReportPill extends StatelessWidget {
  const ReportPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card: the one number that matters most on a screen.
// ---------------------------------------------------------------------------
class ReportHeroCard extends StatelessWidget {
  const ReportHeroCard({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.insights_rounded,
    this.color,
    this.valueColor,
    this.caption,
    this.chips = const [],
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final Color? valueColor;
  final String? caption;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search field with a clear button.
// ---------------------------------------------------------------------------
class ReportSearchField extends StatelessWidget {
  const ReportSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single-select chips (sorting, direction filters, top-N...).
// ---------------------------------------------------------------------------
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class ReportChoiceChips<T> extends StatelessWidget {
  const ReportChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in options)
          ChoiceChip(
            avatar: option.icon == null ? null : Icon(option.icon, size: 16),
            label: Text(option.label),
            selected: option.value == selected,
            onSelected: (_) => onSelected(option.value),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rounded progress bar used for shares and stock levels.
// ---------------------------------------------------------------------------
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 6,
  });

  final double fraction;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final value = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: c.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(c),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rank badge: gold / silver / bronze for the top three.
// ---------------------------------------------------------------------------
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  /// 1-based rank.
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color? medal;
    if (rank == 1) medal = const Color(0xFFF5B301);
    if (rank == 2) medal = const Color(0xFF9AA5B1);
    if (rank == 3) medal = const Color(0xFFCD7F32);

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: medal ?? theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: medal != null
              ? Colors.white
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date presets: Today / Last 7 days / This month / Last month.
// ---------------------------------------------------------------------------
class DatePresetBar extends StatelessWidget {
  const DatePresetBar({
    super.key,
    required this.from,
    required this.to,
    required this.today,
    required this.onSelected,
  });

  final DateTime? from;
  final DateTime? to;

  /// Today in the app's time zone (pass `nowInAppTimeZone()`).
  final DateTime today;

  final void Function(DateTime from, DateTime to) onSelected;

  DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  List<(String, DateTime, DateTime)> _presets(BuildContext context) {
    final t = _d(today);
    final firstOfThis = DateTime(t.year, t.month, 1);
    final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));

    return [
      (context.tr('Today'), t, t),
      (context.tr('Last 7 days'), t.subtract(const Duration(days: 6)), t),
      (context.tr('This month'), firstOfThis, t),
      (
      context.tr('Last month'),
      DateTime(lastOfPrev.year, lastOfPrev.month, 1),
      lastOfPrev,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = from == null ? null : _d(from!);
    final t = to == null ? null : _d(to!);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final preset in _presets(context))
          ChoiceChip(
            label: Text(preset.$1),
            selected: f == preset.$2 && t == preset.$3,
            onSelected: (_) => onSelected(preset.$2, preset.$3),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filters panel: groups several filter controls in one tidy card.
// ---------------------------------------------------------------------------
class ReportFiltersCard extends StatelessWidget {
  const ReportFiltersCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 12));
      spaced.add(children[i]);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: spaced,
        ),
      ),
    );
  }
}