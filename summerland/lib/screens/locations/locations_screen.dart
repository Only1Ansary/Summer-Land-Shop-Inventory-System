import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/location.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen>
    with ReconnectReloader<LocationsScreen> {
  final LocationService _service = LocationService(ApiService());

  List<Location> _locations = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await _service.getLocations();

      if (!mounted) return;

      setState(() {
        _locations = locations;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void onReconnected() {
    _loadLocations();
  }

  Future<void> _addLocation() async {
    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Location'),
      label: context.tr('Location Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.createLocation(name);
      await _loadLocations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));
    }
  }

  Future<void> _editLocation(Location location) async {
    final name = await showAppNameDialog(
      context,
      title: context.tr('Edit Location'),
      label: context.tr('Location Name'),
      initialValue: location.name,
      confirmLabel: context.tr('Save'),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.updateLocation(location.id, name);

      await _loadLocations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));
    }
  }

  Future<void> _deleteLocation(Location location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete location?')),
        content: Text(
          context.tr('Delete "{0}"? This cannot be undone.', [location.name]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteLocation(location.id);

      if (!mounted) return;

      await _loadLocations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('{0} deleted.', [location.name]))),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Locations'),
      destinationId: 'locations',
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        tooltip: context.tr('Add location'),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    final theme = Theme.of(context);

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadLocations,
        child: _locations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.location_on_outlined,
                    title: context.tr('No locations yet'),
                    message: context.tr('Add store locations to manage stock.'),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final location = _locations[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(location.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.tr('Edit'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editLocation(location),
                          ),
                          IconButton(
                            tooltip: context.tr('Delete'),
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            onPressed: () => _deleteLocation(location),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
