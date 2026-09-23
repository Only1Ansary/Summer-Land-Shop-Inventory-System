import 'package:flutter/material.dart';

import '../../models/location.dart';
import '../../models/reports/best_selling_report.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/report_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class BestSellingReportScreen extends StatefulWidget {
  const BestSellingReportScreen({super.key});

  @override
  State<BestSellingReportScreen> createState() =>
      _BestSellingReportScreenState();
}

class _BestSellingReportScreenState
    extends State<BestSellingReportScreen> {
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
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_from ?? DateTime.now())
          : (_to ?? DateTime.now()),
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

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return AppShell(
      title: 'Best Selling',
      destinationId: 'report-best-selling',
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _loadData,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: WideContent(
                    child: report!.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              EmptyState(
                                icon: Icons.trending_down_rounded,
                                title: 'No sales data',
                                message:
                                    'Adjust the filters or add new sales.',
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              DateFilterBar(
                                fromLabel: _from == null
                                    ? 'From'
                                    : _formatDate(_from!),
                                toLabel: _to == null
                                    ? 'To'
                                    : _formatDate(_to!),
                                onFrom: () => _pickDate(true),
                                onTo: () => _pickDate(false),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                key: ValueKey('location-$_selectedLocationId'),
                                initialValue: _selectedLocationId,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                  prefixIcon: Icon(Icons.location_on_outlined),
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
                              const SizedBox(height: 16),
                              const SectionHeader(
                                title: 'Top Sellers',
                                subtitle: 'Ranked by units sold',
                              ),
                              const SizedBox(height: 8),
                              ...report.items.asMap().entries.map(
                                (entry) {
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
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                ),
    );
  }
}