import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/size_model.dart';
import '../../services/api_service.dart';
import '../../services/colour_service.dart';
import '../../services/product_service.dart';
import '../../services/size_service.dart';
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

  late final SizeService _sizeService;

  late final ColourService _colourService;

  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  List<Product> _products = [];
  List<SizeModel> _sizes = [];
  List<Colour> _colours = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;

  bool get _hasActiveFilters {
    return _selectedSizeId != null ||
        _selectedColourId != null ||
        _searchController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _productService = ProductService(_apiService);
    _sizeService = SizeService(_apiService);
    _colourService = ColourService(_apiService);

    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _sizeService.getSizes(),
        _colourService.getColours(),
        _productService.searchProducts(
          query: _searchController.text,
          categoryId: widget.category.id,
          sizeId: _selectedSizeId,
          colourId: _selectedColourId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _sizes = results[0] as List<SizeModel>;
        _colours = results[1] as List<Colour>;
        _products = results[2] as List<Product>;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
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
    _searchDebounce?.cancel();

    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final products = await _productService.searchProducts(
        query: _searchController.text,
        categoryId: widget.category.id,
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
        _errorMessage = e.toString();
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
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _search,
    );
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
      _selectedSizeId = null;
      _selectedColourId = null;
    });

    _search();
  }

  void _openProduct(Product product) {
    pushScreen(
      context,
      (_) => InventoryVariantsScreen(product: product),
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
          child: Column(
            children: [
              TextField(
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
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _search();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterRow(),
              if (_isSearching) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final sizeDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('size-$_selectedSizeId'),
      initialValue: _selectedSizeId,
      decoration: const InputDecoration(labelText: 'Size'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All sizes'),
        ),
        ..._sizes.map(
          (size) => DropdownMenuItem<int?>(
            value: size.id,
            child: Text(size.name),
          ),
        ),
      ],
      onChanged: _setSizeFilter,
    );

    final colourDropdown = DropdownButtonFormField<int?>(
      key: ValueKey('colour-$_selectedColourId'),
      initialValue: _selectedColourId,
      decoration: const InputDecoration(labelText: 'Colour'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All colours'),
        ),
        ..._colours.map(
          (colour) => DropdownMenuItem<int?>(
            value: colour.id,
            child: Text(colour.name),
          ),
        ),
      ],
      onChanged: _setColourFilter,
    );

    final clearButton = TextButton(
      onPressed: _clearFilters,
      child: const Text('Clear filters'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: sizeDropdown),
              const SizedBox(width: 10),
              Expanded(child: colourDropdown),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 6),
                clearButton,
              ],
            ],
          );
        }

        return Column(
          children: [
            sizeDropdown,
            const SizedBox(height: 10),
            colourDropdown,
            if (_hasActiveFilters)
              Align(
                alignment: Alignment.centerRight,
                child: clearButton,
              ),
          ],
        );
      },
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