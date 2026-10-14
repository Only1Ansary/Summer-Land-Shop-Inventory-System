import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/colour_service.dart';
import '../../services/product_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

import 'product_details_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService(ApiService());

  final CategoryService _categoryService = CategoryService(ApiService());

  final SizeService _sizeService = SizeService(ApiService());

  final ColourService _colourService = ColourService(ApiService());

  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  List<Product> _products = [];
  List<Category> _categories = [];
  List<SizeModel> _sizes = [];
  List<Colour> _colours = [];

  int? _selectedCategoryId;
  int? _selectedSizeId;
  int? _selectedColourId;

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
        _selectedSizeId != null ||
        _selectedColourId != null ||
        _searchController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _categoryService.getCategories(),
        _sizeService.getSizes(),
        _colourService.getColours(),
      ]);

      if (!mounted) return;

      setState(() {
        _categories = results[0] as List<Category>;
        _sizes = results[1] as List<SizeModel>;
        _colours = results[2] as List<Colour>;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    _searchDebounce?.cancel();

    if (!mounted) return;

    final query = _searchController.text.trim();

    final hasFilters =
        query.isNotEmpty ||
        _selectedCategoryId != null ||
        _selectedSizeId != null ||
        _selectedColourId != null;

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
        sizeId: _selectedSizeId,
        colourId: _selectedColourId,
      );

      if (!mounted) return;

      setState(() {
        _products = products;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyError(e);
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

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _setCategoryFilter(int? value) {
    setState(() {
      _selectedCategoryId = value;
    });

    _search();
  }

  void _setSizeFilter(int? value) {
    setState(() {
      _selectedSizeId = value;
    });

    _search();
  }

  void _setColourFilter(int? value) {
    setState(() {
      _selectedColourId = value;
    });

    _search();
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _selectedCategoryId = null;
      _selectedSizeId = null;
      _selectedColourId = null;
    });

    _search();
  }

  Future<void> _openProductForm({Product? product}) async {
    final result = await pushScreen(
      context,
      (_) => ProductFormScreen(product: product, categories: _categories),
    );

    if (result == true) {
      _refreshAfterChange();
    }
  }

  Future<void> _openDetails(Product product) async {
    await pushScreen(
      context,
      (_) => ProductDetailsScreen(
        product: product,
        sizes: _sizes,
        colours: _colours,
      ),
    );

    _refreshAfterChange();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Product',
      message: 'Are you sure you want to delete "${product.name}"?',
    );

    if (!confirmed) return;

    try {
      await _productService.deleteProduct(product.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );

      _refreshAfterChange();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Products',
      destinationId: 'products',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProductForm(),
        tooltip: 'Add product',
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
                        labelText: 'Search',
                        hintText: 'Model, name or barcode',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear',
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
                    label: Text(_showFilters ? 'Hide Filters' : 'Filters'),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
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
    final categoryDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('category-$_selectedCategoryId'),
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ..._categories.map(
          (category) => DropdownMenuItem<int?>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: _setCategoryFilter,
    );

    final sizeDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('size-$_selectedSizeId'),
      initialValue: _selectedSizeId,
      decoration: const InputDecoration(labelText: 'Size'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ..._sizes.map(
          (size) =>
              DropdownMenuItem<int?>(value: size.id, child: Text(size.name)),
        ),
      ],
      onChanged: _setSizeFilter,
    );

    final colourDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('colour-$_selectedColourId'),
      initialValue: _selectedColourId,
      decoration: const InputDecoration(labelText: 'Colour'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ..._colours.map(
          (colour) => DropdownMenuItem<int?>(
            value: colour.id,
            child: Text(colour.name),
          ),
        ),
      ],
      onChanged: _setColourFilter,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: 10),
              Expanded(child: sizeDropdown),
              const SizedBox(width: 10),
              Expanded(child: colourDropdown),
            ],
          );
        }

        return Column(
          children: [
            categoryDropdown,
            const SizedBox(height: 10),
            sizeDropdown,
            const SizedBox(height: 10),
            colourDropdown,
          ],
        );
      },
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.search,
            title: 'Search for products',
            message:
                'Enter a model, name or barcode, or use the filters, '
                'to find products.',
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products found',
            message: 'Try adjusting your search or add a new product.',
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
                        'Model: ${product.modelNumber}\n'
                        'Category: ${product.categoryName}',
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
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'details',
                            child: Text('Details'),
                          ),
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
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
