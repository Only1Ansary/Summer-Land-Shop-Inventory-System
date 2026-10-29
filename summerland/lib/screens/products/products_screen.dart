import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';

import '../../localization/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

import 'product_details_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with ReconnectReloader<ProductsScreen> {
  final ProductService _productService = ProductService(ApiService());

  final CategoryService _categoryService = CategoryService(ApiService());

  final TextEditingController _searchController = TextEditingController();

  final Debouncer _searchDebounce = Debouncer();

  List<Product> _products = [];
  List<Category> _categories = [];

  int? _selectedCategoryId;

  bool _isLoading = false;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;

  static const int _pageSize = 10;
  int _currentPage = 0;

  List<Product> get _pageProducts {
    final start = _currentPage * _pageSize;

    if (start >= _products.length) return const [];

    final end = start + _pageSize;

    return _products.sublist(
      start,
      end > _products.length ? _products.length : end,
    );
  }

  bool _showFilters = false;

  bool get _hasActiveFilters {
    return _selectedCategoryId != null ||
        _searchController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    _searchDebounce.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
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
    _loadReferenceData();
  }

  /// Re-runs the current search after a product changes.
  ///
  /// Products are never listed on their own, so when nothing is being
  /// searched there is nothing to refresh.
  Future<void> _refreshAfterChange() async {
    if (_hasSearched) {
      await _search();
    }
  }

  Future<void> _search() async {
    _searchDebounce.cancel();

    if (!mounted) return;

    final query = _searchController.text.trim();

    final hasFilters = query.isNotEmpty || _selectedCategoryId != null;

    if (!hasFilters) {
      // Nothing to search for - return to the "start searching" state
      // instead of listing every product.
      setState(() {
        _hasSearched = false;
        _products = [];
        _currentPage = 0;
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final products = await _productService.searchProducts(
        query: query.isEmpty ? null : query,
        categoryId: _selectedCategoryId,
      );

      if (!mounted) return;

      setState(() {
        _products = products;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _onQueryChanged(String _) {
    setState(() {});

    _searchDebounce.run(_search);
  }

  void _setCategoryFilter(int? value) {
    setState(() {
      _selectedCategoryId = value;
    });

    _search();
  }

  void _clearFilters() {
    _searchDebounce.cancel();
    _searchController.clear();

    setState(() {
      _selectedCategoryId = null;
    });

    _search();
  }

  Future<void> _loadAllProducts() async {
    _searchDebounce.cancel();
    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final products = await _productService.getProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _openProductForm({Product? product}) async {
    if (!ensureOnlineForWrite(context)) return;

    final result = await pushScreen<DeferredCrud>(
      context,
      (_) => ProductFormScreen(product: product, categories: _categories),
    );

    if (result == null) return;

    scheduleDeferredCrud(context, result, onCommitted: _refreshAfterChange);
  }

  Future<void> _openDetails(Product product) async {
    await pushScreen(context, (_) => ProductDetailsScreen(product: product));

    _refreshAfterChange();
  }

  Future<void> _deleteProduct(Product product) async {
    if (!ensureOnlineForWrite(context)) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: context.tr('Delete Product'),
      message: context.tr('Are you sure you want to delete "{0}"?', [
        product.name,
      ]),
    );

    if (!confirmed) return;

    scheduleUndoable(
      context,
      message: context.tr('"{0}" will be deleted. Tap Undo to cancel.', [
        product.name,
      ]),
      operation: () => _productService.deleteProduct(product.id),
      onCommitted: _refreshAfterChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Products'),
      destinationId: 'products',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProductForm(),
        tooltip: context.tr('Add product'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: context.tr('Search'),
                        hintText: context.tr('Model, name or barcode'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: context.tr('Clear'),
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isSearching) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(_showFilters ? Icons.expand_less : Icons.tune),
                    label: Text(
                      _showFilters
                          ? context.tr('Hide Filters')
                          : context.tr('Filters'),
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: Text(context.tr('Clear filters')),
                    ),
                ],
              ),
              if (_showFilters) _buildFilterPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return DropdownButtonFormField<int?>(
      key: ValueKey('category-$_selectedCategoryId'),
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(labelText: context.tr('Category')),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(context.tr('All'))),
        ..._categories.map(
          (category) => DropdownMenuItem<int?>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: _setCategoryFilter,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _hasSearched ? _search : _loadReferenceData,
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.search,
            title: context.tr('Search for products'),
            message: context.tr(
              'Enter a model, name or barcode, or use the filters, '
              'to find products.',
            ),
            action: FilledButton.tonalIcon(
              icon: const Icon(Icons.list_alt_rounded),
              label: Text(context.tr('Show all products')),
              onPressed: _loadAllProducts,
            ),
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: context.tr('No products found'),
            message: context.tr(
              'Try adjusting your search or add a new product.',
            ),
          ),
        ),
      );
    }

    return WideContent(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _search,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pageProducts.length,
                itemBuilder: (context, index) {
                  final product = _pageProducts[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
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
                          Icons.inventory_2_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        context.tr('Model: {0}\nCategory: {1}', [
                          product.modelNumber,
                          product.categoryName,
                        ]),
                      ),
                      isThreeLine: true,
                      onTap: () => _openDetails(product),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'details') {
                            _openDetails(product);
                          } else if (value == 'edit') {
                            _openProductForm(product: product);
                          } else if (value == 'delete') {
                            _deleteProduct(product);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'details',
                            child: Text(context.tr('Details')),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(context.tr('Edit')),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.tr('Delete')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          PaginationBar(
            page: _currentPage,
            pageSize: _pageSize,
            totalItems: _products.length,
            onPageChanged: _goToPage,
          ),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }
}
