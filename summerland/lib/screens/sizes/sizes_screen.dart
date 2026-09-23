import 'package:flutter/material.dart';

import '../../models/size_model.dart';
import '../../services/api_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class SizesScreen extends StatefulWidget {
  const SizesScreen({super.key});

  @override
  State<SizesScreen> createState() =>
      _SizesScreenState();
}

class _SizesScreenState
    extends State<SizesScreen> {
  final SizeService _service =
      SizeService(ApiService());

  List<SizeModel> _sizes = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSizeModels();
  }

  Future<void> _loadSizeModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final size = await _service.getSizes();

      if (!mounted) return;

      setState(() {
        _sizes = size;
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

  Future<void> _addSizeModel() async {
    final name = await showAppNameDialog(
      context,
      title: 'Add Size',
      label: 'Size Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.createSize(name);
      await _loadSizeModels();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _editSizeModel(SizeModel size) async {
    final name = await showAppNameDialog(
      context,
      title: 'Edit Size',
      label: 'Size Name',
      initialValue: size.name,
      confirmLabel: 'Save',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _service.updateSize(
        size.id,
        name,
      );

      await _loadSizeModels();
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
      title: 'Sizes',
      destinationId: 'sizes',
      floatingActionButton: FloatingActionButton(
        onPressed: _addSizeModel,
        tooltip: 'Add size',
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
        onRefresh: _loadSizeModels,
        child: _sizes.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.straighten_outlined,
                    title: 'No sizes yet',
                    message: 'Add sizes to use in product variants.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sizes.length,
                itemBuilder: (context, index) {
                  final size = _sizes[index];

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
                          Icons.straighten_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(size.name),
                      trailing: IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editSizeModel(size),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}