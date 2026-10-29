import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/report_service.dart';
import '../../models/reports/inventory_report.dart';

import '../../localization/app_strings.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

/// The inventory report's product list, without the summary stats on top.
///
/// Meant for looking stock up quickly: every product with stock shows its
/// model, total quantity, and the per-location breakdown once expanded.
class InventorySearchScreen extends StatefulWidget {
  const InventorySearchScreen({super.key});

  @override
  State<InventorySearchScreen> createState() => _InventorySearchScreenState();
}

class _InventorySearchScreenState extends State<InventorySearchScreen>
    with ReconnectReloader<InventorySearchScreen> {
  static const int _pageSize = 10;

  late final ReportService _reportService;

  InventoryReport? _report;
  bool _loading = true;
  String? _error;

  int _currentPage = 0;
  String _query = '';
  final Debouncer _searchDebounce = Debouncer();

  List<T> _pageSlice<T>(List<T> items) {
    final start = _currentPage * _pageSize;

    if (start >= items.length) return const [];

    final end = start + _pageSize;

    return items.sublist(start, end > items.length ? items.length : end);
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _onQueryChanged(String value) {
    _searchDebounce.run(() {
      setState(() {
        _query = value;
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reportService = ReportService(ApiService());
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _reportService.getInventoryReport();

      setState(() {
        _report = report;
        _currentPage = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(context, e);
        _loading = false;
      });
    }
  }

  @override
  void onReconnected() {
    _loadReport();
  }

  /// Adds up the report's variant rows into one row per product.
  ///
  /// A product's quantity is the sum of every variant's stock. Each variant's
  /// per-location figures are grouped by size so an expanded row can show how
  /// much of each size sits at each location. Products with no stock at all are
  /// left out.
  List<_ProductStockRow> _groupByProduct(
    BuildContext context,
    List<InventoryReportItem> items,
  ) {
    final order = <String>[];
    final names = <String, String>{};
    final models = <String, String>{};
    final minPrices = <String, double>{};
    final maxPrices = <String, double>{};
    final quantities = <String, int>{};
    final sizeNames = <String, Set<String>>{};
    // productKey → locationId → (locationName, sizeName → quantity).
    final locations = <String, Map<int, _MutableLocation>>{};

    for (final item in items) {
      final key = '${item.modelNumber}:${item.productName}';
      final sizeName = _sizeLabel(context, item);

      if (!quantities.containsKey(key)) {
        order.add(key);
        names[key] = item.productName;
        models[key] = item.modelNumber;
        minPrices[key] = item.price;
        maxPrices[key] = item.price;
        quantities[key] = 0;
        sizeNames[key] = {};
        locations[key] = {};
      }

      minPrices[key] = item.price < minPrices[key]!
          ? item.price
          : minPrices[key]!;
      maxPrices[key] = item.price > maxPrices[key]!
          ? item.price
          : maxPrices[key]!;

      quantities[key] = quantities[key]! + item.totalQuantity;
      sizeNames[key]!.add(sizeName);

      for (final location in item.locations) {
        final bySize = locations[key]!.putIfAbsent(
          location.locationId,
          () => _MutableLocation(location.locationName),
        );
        bySize.quantities[sizeName] =
            (bySize.quantities[sizeName] ?? 0) + location.quantity;
      }
    }

    return order.where((key) => quantities[key]! > 0).map((key) {
      final sizes = sizeNames[key]!.toList()..sort(_compareSizes);

      final locationRows = locations[key]!.entries.map((entry) {
        return _LocationStock(
          locationName: entry.value.name,
          sizes: [
            for (final size in sizes)
              _SizeStock(
                sizeName: size,
                quantity: entry.value.quantities[size] ?? 0,
              ),
          ],
        );
      }).toList();

      return _ProductStockRow(
        productName: names[key]!,
        modelNumber: models[key]!,
        minPrice: minPrices[key]!,
        maxPrice: maxPrices[key]!,
        totalQuantity: quantities[key]!,
        locations: locationRows,
      );
    }).toList();
  }

  /// A size's label, falling back for variants that carry no size.
  String _sizeLabel(BuildContext context, InventoryReportItem item) {
    final size = item.sizeName;

    if (size != null && size.isNotEmpty) return size;

    return context.tr('One size');
  }

  /// Orders size labels, preferring a natural numeric order when possible.
  int _compareSizes(String a, String b) {
    final numA = int.tryParse(a);
    final numB = int.tryParse(b);

    if (numA != null && numB != null) return numA.compareTo(numB);

    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  List<_ProductStockRow> _matching(List<_ProductStockRow> products) {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return products;

    return products
        .where(
          (product) =>
              product.productName.toLowerCase().contains(query) ||
              product.modelNumber.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final items = report?.items ?? const <InventoryReportItem>[];
    final bool hasQuery = _query.trim().isNotEmpty;
    // Nothing is listed until the user searches, so the screen stays quiet
    // instead of dumping the whole catalogue.
    final products = hasQuery
        ? _matching(_groupByProduct(context, items))
        : const <_ProductStockRow>[];

    return AppShell(
      title: context.tr('Inventory Search'),
      destinationId: 'inventory-search',
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadReport)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: WideContent(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: context.tr('Search products'),
                        hintText: context.tr('Name or model number'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadReport,
                    child: WideContent(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (products.isEmpty)
                            EmptyState(
                              icon: hasQuery
                                  ? Icons.search_off_rounded
                                  : Icons.search_rounded,
                              title: hasQuery
                                  ? context.tr('No products found')
                                  : context.tr('Search for a product'),
                              message: hasQuery
                                  ? context.tr(
                                      'No product with stock matches your search.',
                                    )
                                  : context.tr(
                                      'Type a product name or model number to '
                                      'see its stock.',
                                    ),
                            ),
                          ..._pageSlice(products).map((product) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    Expanded(child: Text(product.productName)),
                                    Text(
                                      product.priceLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: amountColor(
                                          context,
                                          product.maxPrice,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  context.tr('{0} • Qty: {1}', [
                                    product.modelNumber,
                                    product.totalQuantity,
                                  ]),
                                ),
                                children: [
                                  const Divider(height: 1),
                                  ...product.locations.map(
                                    (location) =>
                                        _LocationBlock(location: location),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
                if (products.isNotEmpty)
                  WideContent(
                    child: PaginationBar(
                      page: _currentPage,
                      pageSize: _pageSize,
                      totalItems: products.length,
                      onPageChanged: _goToPage,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One product's stock, with every variant's quantity added together.
class _ProductStockRow {
  final String productName;
  final String modelNumber;
  final double minPrice;
  final double maxPrice;
  final int totalQuantity;
  final List<_LocationStock> locations;

  _ProductStockRow({
    required this.productName,
    required this.modelNumber,
    required this.minPrice,
    required this.maxPrice,
    required this.totalQuantity,
    required this.locations,
  });

  /// The product's price, or a range when its variants differ.
  String get priceLabel {
    if (minPrice == maxPrice) return money(minPrice);

    return '${money(minPrice)} – ${money(maxPrice)}';
  }
}

/// How much of one product sits at a single location, split by size.
class _LocationStock {
  final String locationName;

  /// Size name (or a fallback for variants without a size) → quantity there.
  final List<_SizeStock> sizes;

  _LocationStock({required this.locationName, required this.sizes});

  int get totalQuantity => sizes.fold(0, (sum, size) => sum + size.quantity);
}

/// A location line inside an expanded product, listing how much of each size
/// of the product is stocked there.
class _LocationBlock extends StatelessWidget {
  const _LocationBlock({required this.location});

  final _LocationStock location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(location.locationName),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final size in location.sizes)
              Text(
                context.tr('{0}: {1}', [size.sizeName, size.quantity]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      trailing: Text(
        '${location.totalQuantity}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Builder for a product's size breakdown at one location.
class _MutableLocation {
  final String name;
  final Map<String, int> quantities = {};

  _MutableLocation(this.name);
}

/// One size's quantity at a location.
class _SizeStock {
  final String sizeName;
  final int quantity;

  _SizeStock({required this.sizeName, required this.quantity});
}
