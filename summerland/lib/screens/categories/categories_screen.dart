import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() =>
      _CategoriesScreenState();
}

class _CategoriesScreenState
    extends State<CategoriesScreen> {
  final CategoryService _categoryService =
      CategoryService(ApiService());

  List<Category> _categories = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _editCategory(Category category) async {
    final name = await showAppNameDialog(
      context,
      title: 'Edit Category',
      label: 'Category Name',
      initialValue: category.name,
      confirmLabel: 'Save',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _categoryService.updateCategory(
        category.id,
        name,
      );

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _addCategory() async {
    final name = await showAppNameDialog(
      context,
      title: 'Add Category',
      label: 'Category Name',
      confirmLabel: 'Add',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _categoryService.createCategory(name);
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories =
          await _categoryService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
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
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Categories',
      destinationId: 'categories',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(),
        tooltip: 'Add category',
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
      return ErrorState(
        message: _error!,
        onRetry: _loadCategories,
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadCategories,
        child: _categories.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message: 'Add a category to start organising products.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category =
                      _categories[index];

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
                          Icons.category_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(category.name),
                      trailing: IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editCategory(category),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}