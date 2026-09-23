import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/product_service.dart';
import '../../ui/app_widgets.dart';
import 'inventory_variants_screen.dart';

class InventoryProductsScreen extends StatefulWidget {
  final Category category;

  const InventoryProductsScreen({super.key, required this.category});

  @override
  State<InventoryProductsScreen> createState() =>
      _InventoryProductsScreenState();
}

class _InventoryProductsScreenState extends State<InventoryProductsScreen> {
  final ApiService _apiService = ApiService();

  late final ProductService _productService;

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _productService = ProductService(_apiService);

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
      _errorMessage = null;
    });

    try {
      await Future.wait([_loadProducts()]);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<Product>> _loadProducts() async {
    final products = await _productService.searchProducts(
      query: _searchController.text,
      categoryId: widget.category.id,
      sizeId: _selectedSizeId,
      colourId: _selectedColourId,
    );

    if (mounted) {
      setState(() {
        _products = products;
      });
    }

    return products;
  }

  Future<void> _search() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadProducts();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryVariantsScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    return Column(
      children: [
        _buildSearchAndFilters(),
        const Divider(height: 1),
        Expanded(child: _buildProductsList()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Model, name or barcode',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search();
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return WideContent(
      child: RefreshIndicator(
        onRefresh: _search,
        child: _products.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No products found',
                    message: 'No products match in this category.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = _products[index];

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
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
                      subtitle: Text('Model: ${product.modelNumber}'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                      ),
                      onTap: () => _openProduct(product),
                    ),
                  );
                },
              ),
      ),
    );
  }
}