import 'package:flutter/material.dart';

import '../../models/location.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() =>
      _LocationsScreenState();
}

class _LocationsScreenState
    extends State<LocationsScreen> {
  final LocationService _service =
      LocationService(ApiService());

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addLocation() async {
    final name = await showAppNameDialog(
      context,
      title: 'Add Location',
      label: 'Location Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.createLocation(name);
      await _loadLocations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _editLocation(Location location) async {
    final name = await showAppNameDialog(
      context,
      title: 'Edit Location',
      label: 'Location Name',
      initialValue: location.name,
      confirmLabel: 'Save',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.updateLocation(
        location.id,
        name,
      );

      await _loadLocations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Locations',
      destinationId: 'locations',
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        tooltip: 'Add location',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadLocations,
        child: _locations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.location_on_outlined,
                    title: 'No locations yet',
                    message: 'Add store locations to manage stock.',
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
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(location.name),
                      trailing: IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editLocation(location),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}