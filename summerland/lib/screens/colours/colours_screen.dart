import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../services/api_service.dart';
import '../../services/colour_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class ColoursScreen extends StatefulWidget {
  const ColoursScreen({super.key});

  @override
  State<ColoursScreen> createState() =>
      _ColoursScreenState();
}

class _ColoursScreenState
    extends State<ColoursScreen> {
  final ColourService _service =
      ColourService(ApiService());

  List<Colour> _colours = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadColours();
  }

  Future<void> _loadColours() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final colours = await _service.getColours();

      if (!mounted) return;

      setState(() {
        _colours = colours;
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

  Future<void> _addColour() async {
    final name = await showAppNameDialog(
      context,
      title: 'Add Colour',
      label: 'Colour Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.createColour(name);
      await _loadColours();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _editColour(Colour colour) async {
    final name = await showAppNameDialog(
      context,
      title: 'Edit Colour',
      label: 'Colour Name',
      initialValue: colour.name,
      confirmLabel: 'Save',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.updateColour(
        colour.id,
        name,
      );

      await _loadColours();
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
      title: 'Colours',
      destinationId: 'colours',
      floatingActionButton: FloatingActionButton(
        onPressed: _addColour,
        tooltip: 'Add colour',
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
        onRefresh: _loadColours,
        child: _colours.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.palette_outlined,
                    title: 'No colours yet',
                    message: 'Add colours to use in product variants.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _colours.length,
                itemBuilder: (context, index) {
                  final colour = _colours[index];

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
                          Icons.palette_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(colour.name),
                      trailing: IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editColour(colour),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}