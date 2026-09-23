import 'package:flutter/material.dart';

import '../../models/location.dart';
import '../../models/reports/stock_movement_report.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/report_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

class StockMovementsReportScreen extends StatefulWidget {
  const StockMovementsReportScreen({super.key});

  @override
  State<StockMovementsReportScreen> createState() =>
      _StockMovementsReportScreenState();
}

class _StockMovementsReportScreenState
    extends State<StockMovementsReportScreen> {
  late final ReportService _reportService;
  late final LocationService _locationService;

  StockMovementReport? _report;
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

      final report =
          await _reportService.getStockMovementReport(
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
      title: 'Stock Movements',
      destinationId: 'report-movements',
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
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        DateFilterBar(
                          fromLabel: _from == null
                              ? 'From'
                              : _formatDate(_from!),
                          toLabel:
                              _to == null ? 'To' : _formatDate(_to!),
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
                        StatGrid(
                          stats: [
                            StatData(
                              label: 'Movements',
                              value: '${report!.movementCount}',
                              icon: Icons.swap_vert_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SectionHeader(
                          title: 'Movement History',
                          subtitle: 'Quantity changes from transfers and refills',
                        ),
                        const SizedBox(height: 8),
                        ...report.items.map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              isThreeLine: true,
                              title: Text(item.productName),
                              subtitle: Text(
                                '${item.modelNumber}\n'
                                '${item.locationName} • ${item.reason}\n'
                                '${item.createdAt}',
                              ),
                              trailing: StatusBadge(
                                label: item.quantityChange > 0
                                    ? '+${item.quantityChange}'
                                    : '${item.quantityChange}',
                                color: item.quantityChange > 0
                                    ? AppPalette.success
                                    : AppPalette.danger,
                                icon: item.quantityChange > 0
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}