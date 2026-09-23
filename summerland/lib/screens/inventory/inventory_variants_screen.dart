import 'package:flutter/material.dart';

import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/colour_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_widgets.dart';

import 'add_inventory_screen.dart';

class InventoryVariantsScreen extends StatefulWidget {
  final Product product;

  const InventoryVariantsScreen({
    super.key,
    required this.product,
  });

  @override
  State<InventoryVariantsScreen> createState() =>
      _InventoryVariantsScreenState();
}

class _InventoryVariantsScreenState
    extends State<InventoryVariantsScreen> {
  final ApiService _apiService = ApiService();

  late final ProductVariantService _variantService;
  late final SizeService _sizeService;
  late final ColourService _colourService;

  final TextEditingController _searchController =
      TextEditingController();

  List<ProductVariant> _allVariants = [];
  List<ProductVariant> _filteredVariants = [];

  List<SizeModel> _sizes = [];
  List<Colour> _colours = [];

  int? _selectedSizeId;
  int? _selectedColourId;

  bool _isLoading = true;
  String? _errorMessage;

  bool _showFilters = false;

  @override
  void initState() {
    super.initState();

    _variantService = ProductVariantService(_apiService);
    _sizeService = SizeService(_apiService);
    _colourService = ColourService(_apiService);

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
      final results = await Future.wait([
        _variantService.getVariants(),
        _sizeService.getSizes(),
        _colourService.getColours(),
      ]);

      final variants = results[0] as List<ProductVariant>;

      if (!mounted) return;

      setState(() {
        _allVariants = variants
            .where(
              (variant) => variant.productId == widget.product.id,
            )
            .toList();

        _sizes = results[1] as List<SizeModel>;
        _colours = results[2] as List<Colour>;

        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredVariants = _allVariants.where((variant) {
        final matchesSearch =
            query.isEmpty ||
                variant.barcode.toLowerCase().contains(query) ||
                (variant.sizeName?.toLowerCase().contains(query) ?? false) ||
                (variant.colourName?.toLowerCase().contains(query) ?? false);

        final matchesSize =
            _selectedSizeId == null ||
                variant.sizeId == _selectedSizeId;

        final matchesColour =
            _selectedColourId == null ||
                variant.colourId == _selectedColourId;

        return matchesSearch &&
            matchesSize &&
            matchesColour;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedSizeId = null;
      _selectedColourId = null;
      _filteredVariants = List.from(_allVariants);
    });
  }

  Future<void> _openVariant(ProductVariant variant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInventoryScreen(
          variant: variant,
        ),
      ),
    );

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
      ),
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
        Expanded(
          child: _buildVariantsList(),
        ),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: 'Barcode, size or colour',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final sizeDropdown = DropdownButtonFormField<int>(
                      key: ValueKey('size-$_selectedSizeId'),
                      initialValue: _selectedSizeId,
                      decoration: const InputDecoration(
                        labelText: 'Size',
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('All Sizes'),
                        ),
                        ..._sizes.map(
                          (size) => DropdownMenuItem<int>(
                            value: size.id,
                            child: Text(size.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSizeId = value;
                        });
                        _applyFilters();
                      },
                    );

                    final colourDropdown = DropdownButtonFormField<int>(
                      key: ValueKey('colour-$_selectedColourId'),
                      initialValue: _selectedColourId,
                      decoration: const InputDecoration(
                        labelText: 'Colour',
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('All Colours'),
                        ),
                        ..._colours.map(
                          (colour) => DropdownMenuItem<int>(
                            value: colour.id,
                            child: Text(colour.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedColourId = value;
                        });
                        _applyFilters();
                      },
                    );

                    if (constraints.maxWidth >= 640) {
                      return Row(
                        children: [
                          Expanded(child: sizeDropdown),
                          const SizedBox(width: 10),
                          Expanded(child: colourDropdown),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        sizeDropdown,
                        const SizedBox(height: 10),
                        colourDropdown,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Apply Filters'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantsList() {
    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _filteredVariants.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No variants found',
                    message: 'Try changing the search or filters.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredVariants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final variant = _filteredVariants[index];

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _buildVariantName(variant),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (variant.isLowStock) const LowStockBadge(),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (variant.barcode.isNotEmpty)
                            Text(
                              'Barcode: ${variant.barcode}',
                            ),
                          Text(
                            'Stock: ${variant.totalQuantity}  •  Price: ${money(variant.price)}',
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                      ),
                      onTap: () => _openVariant(variant),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _buildVariantName(ProductVariant variant) {
    final parts = <String>[];

    if (variant.sizeName != null &&
        variant.sizeName!.isNotEmpty) {
      parts.add(variant.sizeName!);
    }

    if (variant.colourName != null &&
        variant.colourName!.isNotEmpty) {
      parts.add(variant.colourName!);
    }

    if (parts.isEmpty) {
      return 'Variant #${variant.id}';
    }

    return parts.join(' / ');
  }
}