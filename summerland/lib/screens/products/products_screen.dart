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
  final ProductService _productService =
      ProductService(ApiService());

  final CategoryService _categoryService =
      CategoryService(ApiService());

  final SizeService _sizeService =
      SizeService(ApiService());

  final ColourService _colourService =
      ColourService(ApiService());

  final TextEditingController _searchController =
      TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<SizeModel> _sizes = [];
  List<Colour> _colours = [];

  int? _selectedCategoryId;
  int? _selectedSizeId;
  int? _selectedColourId;

  bool _isLoading = false;
  String? _error;

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
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _productService.getProducts(),
        _categoryService.getCategories(),
        _sizeService.getSizes(),
        _colourService.getColours(),
      ]);

      if (!mounted) return;

      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
        _sizes = results[2] as List<SizeModel>;
        _colours = results[3] as List<Colour>;
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

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.isEmpty &&
        _selectedCategoryId == null &&
        _selectedSizeId == null &&
        _selectedColourId == null) {
      _loadData();
      return;
    }

    setState(() {
      _isLoading = true;
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

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _selectedCategoryId = null;
      _selectedSizeId = null;
      _selectedColourId = null;
    });

    _loadData();
  }

  Future<void> _openProductForm({
    Product? product,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          product: product,
          categories: _categories,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _openDetails(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          product: product,
          sizes: _sizes,
          colours: _colours,
        ),
      ),
    );

    _loadData();
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
        const SnackBar(
          content: Text('Product deleted successfully.'),
        ),
      );

      _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
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
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: 'Model, name or barcode',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchController.clear();
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      _showFilters ? Icons.expand_less : Icons.tune,
                    ),
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
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All'),
        ),
        ..._categories.map(
          (category) => DropdownMenuItem<int?>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
    );

    final sizeDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('size-$_selectedSizeId'),
      initialValue: _selectedSizeId,
      decoration: const InputDecoration(labelText: 'Size'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All'),
        ),
        ..._sizes.map(
          (size) => DropdownMenuItem<int?>(
            value: size.id,
            child: Text(size.name),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSizeId = value;
        });
      },
    );

    final colourDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('colour-$_selectedColourId'),
      initialValue: _selectedColourId,
      decoration: const InputDecoration(labelText: 'Colour'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All'),
        ),
        ..._colours.map(
          (colour) => DropdownMenuItem<int?>(
            value: colour.id,
            child: Text(colour.name),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedColourId = value;
        });
      },
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
        onRetry: _loadData,
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _products.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                    message:
                        'Try adjusting your search or add a new product.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
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
                            _openProductForm(
                              product: product,
                            );
                          } else if (value == 'delete') {
                            _deleteProduct(product);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'details',
                            child: Text('Details'),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
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