import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with ReconnectReloader<CategoriesScreen> {
  final CategoryService _categoryService = CategoryService(ApiService());

  List<Category> _categories = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _editCategory(Category category) async {
    if (!ensureOnlineForWrite(context)) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Edit Category'),
      label: context.tr('Category Name'),
      initialValue: category.name,
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
      operation: () => _categoryService.updateCategory(category.id, name),
      onOptimistic: () async {
        setState(() {
          _categories = _categories
              .map(
                (c) => c.id == category.id ? Category(id: c.id, name: name) : c,
              )
              .toList();
        });
      },
      onCommitted: _loadCategories,
      onUndone: _loadCategories,
    );
  }

  Future<void> _deleteCategory(Category category) async {
    if (!ensureOnlineForWrite(context)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete category?')),
        content: Text(context.tr('Delete "{0}"?', [category.name])),
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

    scheduleUndoable(
      context,
      message: context.tr('"{0}" will be deleted. Tap Undo to cancel.', [
        category.name,
      ]),
      operation: () => _categoryService.deleteCategory(category.id),
      onOptimistic: () async {
        setState(() {
          _categories = _categories.where((c) => c.id != category.id).toList();
        });
      },
      onCommitted: _loadCategories,
      onUndone: _loadCategories,
    );
  }

  Future<void> _addCategory() async {
    if (!ensureOnlineForWrite(context)) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Category'),
      label: context.tr('Category Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    scheduleUndoable(
      context,
      message: context.tr('"{0}" will be added. Tap Undo to cancel.', [name]),
      operation: () => _categoryService.createCategory(name),
      onOptimistic: () async {
        setState(() {
          _categories = [
            ..._categories,
            Category(id: -DateTime.now().millisecondsSinceEpoch, name: name),
          ];
        });
      },
      onCommitted: _loadCategories,
      onUndone: _loadCategories,
    );
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _categoryService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
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
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Categories'),
      destinationId: 'categories',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(),
        tooltip: context.tr('Add category'),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadCategories);
    }

    final theme = Theme.of(context);

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadCategories,
        child: _categories.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.category_outlined,
                    title: context.tr('No categories yet'),
                    message: context.tr(
                      'Add a category to start organising products.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];

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
                          Icons.category_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(category.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.tr('Edit'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editCategory(category),
                          ),
                          IconButton(
                            tooltip: context.tr('Delete'),
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            onPressed: () => _deleteCategory(category),
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
