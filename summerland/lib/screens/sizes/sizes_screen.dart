import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/size_model.dart';
import '../../services/api_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

class SizesScreen extends StatefulWidget {
  const SizesScreen({super.key});

  @override
  State<SizesScreen> createState() => _SizesScreenState();
}

class _SizesScreenState extends State<SizesScreen>
    with ReconnectReloader<SizesScreen> {
  final SizeService _service = SizeService(ApiService());

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
    _loadSizeModels();
  }

  Future<void> _addSizeModel() async {
    if (!ensureOnlineForWrite(context)) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Size'),
      label: context.tr('Size Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    scheduleUndoable(
      context,
      message: context.tr('"{0}" will be added. Tap Undo to cancel.', [name]),
      operation: () => _service.createSize(name),
      onOptimistic: () async {
        setState(() {
          _sizes = [
            ..._sizes,
            SizeModel(id: -DateTime.now().millisecondsSinceEpoch, name: name),
          ];
        });
      },
      onCommitted: _loadSizeModels,
      onUndone: _loadSizeModels,
    );
  }

  Future<void> _editSizeModel(SizeModel size) async {
    if (!ensureOnlineForWrite(context)) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Edit Size'),
      label: context.tr('Size Name'),
      initialValue: size.name,
      confirmLabel: context.tr('Save'),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    scheduleUndoable(
      context,
      message: context.tr(
        'Changes to "{0}" will be saved. Tap Undo to cancel.',
        [name],
      ),
      operation: () => _service.updateSize(size.id, name),
      onOptimistic: () async {
        setState(() {
          _sizes = _sizes
              .map(
                (s) => s.id == size.id ? SizeModel(id: s.id, name: name) : s,
              )
              .toList();
        });
      },
      onCommitted: _loadSizeModels,
      onUndone: _loadSizeModels,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Sizes'),
      destinationId: 'sizes',
      floatingActionButton: FloatingActionButton(
        onPressed: _addSizeModel,
        tooltip: context.tr('Add size'),
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
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.straighten_outlined,
                    title: context.tr('No sizes yet'),
                    message: context.tr(
                      'Add sizes to use in product variants.',
                    ),
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
                          color: Theme.of(context).colorScheme.primary
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
                        tooltip: context.tr('Edit'),
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
