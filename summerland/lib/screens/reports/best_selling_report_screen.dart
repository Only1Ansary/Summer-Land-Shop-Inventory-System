import 'package:flutter/material.dart';

import '../../models/location.dart';
import '../../models/reports/best_selling_report.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/report_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class BestSellingReportScreen extends StatefulWidget {
  const BestSellingReportScreen({super.key});

  @override
  State<BestSellingReportScreen> createState() =>
      _BestSellingReportScreenState();
}

class _BestSellingReportScreenState extends State<BestSellingReportScreen> {
  late final ReportService _reportService;
  late final LocationService _locationService;

  BestSellingReport? _report;
  List<Location> _locations = [];

  int? _selectedLocationId;
  DateTime? _from;
  DateTime? _to;

  bool _loading = true;
  String? _error;

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

      final report = await _reportService.getBestSellingReport(
        from: _from,
        to: _to,
        locationId: _selectedLocationId,
      );

      setState(() {
        _locations = locations;
        _report = report;
        _loading = false;

        // A narrower date range can leave fewer products than the user asked
        // for, so the field follows the data instead of overstating it.
        final sold = report.items.length;

        if (_rankLimit != null && sold > 0 && _rankLimit! > sold) {
          _rankLimit = sold;
          _rankController.text = '$sold';
        }
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // How many ranks to show. Null means every product that was sold.
  final TextEditingController _rankController = TextEditingController();
  int? _rankLimit;
  String? _rankError;

  @override
  void dispose() {
    _rankController.dispose();
    super.dispose();
  }

  // The user types the number of ranks they want. It has to be a whole
  // number that the current period can actually fill, so anything past the
  // amount sold is rejected instead of silently showing a short list.
  void _applyRankLimit(String raw) {
    final text = raw.trim();
    final sold = _report?.items.length ?? 0;

    if (text.isEmpty) {
      setState(() {
        _rankLimit = null;
        _rankError = null;
      });
      return;
    }

    final value = int.tryParse(text);

    if (value == null || value < 1) {
      setState(() {
        _rankError = 'Enter a whole number of ranks, 1 or more.';
      });
      return;
    }

    if (value > sold) {
      setState(() {
        _rankError =
            'Only $sold product${sold == 1 ? '' : 's'} sold in this period.';
      });
      return;
    }

    setState(() {
      _rankLimit = value;
      _rankError = null;
    });
  }

  // Ranks actually rendered, never more than the products on hand.
  int _shownRanks(int sold) {
    final requested = _rankLimit;

    if (requested == null) return sold;
    if (sold == 0) return 0;

    return requested > sold ? sold : requested;
  }

  Widget _buildRankSelector(int sold) {
    final shown = _shownRanks(sold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _rankController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Show top',
              hintText: 'All',
              helperText: 'Empty shows every product',
              errorText: _rankError,
              errorMaxLines: 2,
              prefixIcon: const Icon(Icons.emoji_events_outlined),
              border: const OutlineInputBorder(),
            ),
            onChanged: _applyRankLimit,
          ),
        ),
        if (_rankLimit != null && shown < sold) ...[
          const SizedBox(height: 6),
          Text(
            'Showing the top $shown of $sold products sold',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <BestSellingProduct>[];
    final shownRanks = _shownRanks(items.length);

    return AppShell(
      title: 'Best Selling',
      destinationId: 'report-best-selling',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: WideContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    DateFilterBar(
                      fromLabel: _from == null ? 'From' : _formatDate(_from!),
                      toLabel: _to == null ? 'To' : _formatDate(_to!),
                      onFrom: () => _pickDate(true),
                      onTo: () => _pickDate(false),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('location-$_selectedLocationId'),
                      initialValue: _selectedLocationId,
                      decoration: const InputDecoration(
                        labelText: 'Cashier Location',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Locations'),
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
                    if (report!.items.isEmpty) ...[
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 200,
                        child: EmptyState(
                          icon: Icons.trending_down_rounded,
                          title: 'No sales data',
                          message: 'Adjust the dates or add new sales.',
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildRankSelector(items.length),
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: _rankLimit == null
                            ? 'Top Sellers'
                            : 'Top $shownRanks',
                        subtitle:
                            'Ranked by units sold'
                            ' • ${items.length} product'
                            '${items.length == 1 ? '' : 's'} sold',
                      ),
                      const SizedBox(height: 8),
                      ...items.take(shownRanks).toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final item = entry.value;
                        final theme = Theme.of(context);
                        final isTopThree = index < 3;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isTopThree
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: isTopThree
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.modelNumber}\n'
                              'Sold: ${item.totalQuantitySold}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              money(item.totalSales),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColor(context, item.totalSales),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
