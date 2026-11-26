import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/location.dart';
import '../../models/reports/stock_movement_report.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/report_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';
import '../../ui/report_widgets.dart';

enum _Direction { all, incoming, outgoing }

class StockMovementsReportScreen extends StatefulWidget {
  const StockMovementsReportScreen({super.key});

  @override
  State<StockMovementsReportScreen> createState() =>
      _StockMovementsReportScreenState();
}

class _StockMovementsReportScreenState extends State<StockMovementsReportScreen>
    with ReconnectReloader<StockMovementsReportScreen> {
  late final ReportService _reportService;
  late final LocationService _locationService;

  StockMovementReport? _report;
  List<Location> _locations = [];

  int? _selectedLocationId;
  DateTime? _from;
  DateTime? _to;
  _Direction _direction = _Direction.all;

  bool _loading = true;
  String? _error;

  static const int _pageSize = 10;
  int _currentPage = 0;

  List<T> _pageSlice<T>(List<T> items) {
    final start = _currentPage * _pageSize;

    if (start >= items.length) return const [];

    final end = start + _pageSize;

    return items.sublist(start, end > items.length ? items.length : end);
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  void initState() {
    super.initState();

    final apiService = ApiService();

    _reportService = ReportService(apiService);
    _locationService = LocationService(apiService);

    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final locations = await _locationService.getLocations();

      final report = await _reportService.getStockMovementReport(
        from: _from,
        to: _to,
        locationId: _selectedLocationId,
      );

      setState(() {
        _locations = locations;
        _report = report;
        _currentPage = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(context, e);
        _loading = false;
      });
    }
  }

  @override
  void onReconnected() {
    _loadData();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_from ?? nowInAppTimeZone())
          : (_to ?? nowInAppTimeZone()),
      firstDate: DateTime(2020),
      lastDate: nowInAppTimeZone(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });

    await _loadData();
  }

  String _formatDate(DateTime date) => formatDisplayDate(date);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _signed(int value) => value > 0 ? '+$value' : '$value';

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <StockMovementReportItem>[];

    // Totals are for the whole period, whatever the direction filter shows.
    var unitsIn = 0;
    var unitsOut = 0;

    for (final item in items) {
      final change = item.quantityChange.toInt();

      if (change > 0) {
        unitsIn += change;
      } else {
        unitsOut += -change;
      }
    }

    final net = unitsIn - unitsOut;

    final visible = items.where((item) {
      final change = item.quantityChange;

      switch (_direction) {
        case _Direction.all:
          return true;
        case _Direction.incoming:
          return change > 0;
        case _Direction.outgoing:
          return change < 0;
      }
    }).toList();

    // Day headers are added while walking the current page only.
    final rows = <Widget>[];
    DateTime? lastDay;

    for (final item in _pageSlice(visible)) {
      if (lastDay == null || !_sameDay(lastDay, item.createdAt)) {
        rows.add(_DayHeader(label: formatDisplayDate(item.createdAt)));
        lastDay = item.createdAt;
      }

      rows.add(_MovementTile(item: item));
    }

    return AppShell(
      title: context.tr('Stock Movements'),
      destinationId: 'report-movements',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: WideContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    ReportFiltersCard(
                      children: [
                        DatePresetBar(
                          from: _from,
                          to: _to,
                          today: nowInAppTimeZone(),
                          onSelected: (from, to) {
                            setState(() {
                              _from = from;
                              _to = to;
                            });
                            _loadData();
                          },
                        ),
                        DateFilterBar(
                          fromLabel: _from == null
                              ? context.tr('From')
                              : _formatDate(_from!),
                          toLabel: _to == null
                              ? context.tr('To')
                              : _formatDate(_to!),
                          onFrom: () => _pickDate(true),
                          onTo: () => _pickDate(false),
                        ),
                        DropdownButtonFormField<int?>(
                          key: ValueKey('location-$_selectedLocationId'),
                          initialValue: _selectedLocationId,
                          decoration: InputDecoration(
                            labelText: context.tr('Location'),
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                            ),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(context.tr('All Locations')),
                            ),
                            ..._locations.map(
                                  (location) => DropdownMenuItem<int?>(
                                value: location.id,
                                child: Text(location.name),
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              _selectedLocationId = value;
                            });

                            await _loadData();
                          },
                        ),
                        ReportChoiceChips<_Direction>(
                          selected: _direction,
                          onSelected: (value) => setState(() {
                            _direction = value;
                            _currentPage = 0;
                          }),
                          options: [
                            ChoiceOption(
                              _Direction.all,
                              context.tr('All'),
                            ),
                            ChoiceOption(
                              _Direction.incoming,
                              context.tr('Incoming'),
                              icon: Icons.arrow_upward_rounded,
                            ),
                            ChoiceOption(
                              _Direction.outgoing,
                              context.tr('Outgoing'),
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(
                      title: context.tr('Movement History'),
                      subtitle: context.tr(
                        'Quantity changes from transfers and refills',
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (visible.isEmpty)
                      SizedBox(
                        height: 220,
                        child: EmptyState(
                          icon: Icons.swap_vert_rounded,
                          title: context.tr('No movements found'),
                          message: context.tr(
                            'Adjust the dates or filters.',
                          ),
                        ),
                      )
                    else
                      ...rows,
                  ],
                ),
              ),
            ),
          ),
          if (visible.isNotEmpty)
            WideContent(
              child: PaginationBar(
                page: _currentPage,
                pageSize: _pageSize,
                totalItems: visible.length,
                onPageChanged: _goToPage,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.item});

  final StockMovementReportItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = item.quantityChange;
    final incoming = change > 0;
    final color = incoming ? AppPalette.success : AppPalette.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                incoming
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.modelNumber} \u2022 ${item.locationName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ReportPill(
                        label: context.tr(item.reason),
                        color: theme.colorScheme.secondary,
                      ),
                      Text(
                        formatDisplayDateTime(
                          item.createdAt,
                          am: context.tr('AM'),
                          pm: context.tr('PM'),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              incoming ? '+$change' : '$change',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}