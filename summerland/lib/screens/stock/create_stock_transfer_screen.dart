import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/inventory.dart';
import '../../models/location.dart';
import '../../models/product_variant.dart';
import '../../services/api_service.dart';
import '../../services/inventory_service.dart';
import '../../services/location_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/stock_transfer_service.dart';
import '../../ui/app_widgets.dart';

class CreateStockTransferScreen extends StatefulWidget {
  const CreateStockTransferScreen({super.key});

  @override
  State<CreateStockTransferScreen> createState() =>
      _CreateStockTransferScreenState();
}

/// A variant the user has queued for this transfer, plus the quantity they
/// typed for it.
class _TransferLine {
  final ProductVariant variant;
  final TextEditingController quantityController;

  _TransferLine(this.variant)
    : quantityController = TextEditingController(text: '1');

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;

  void dispose() {
    quantityController.dispose();
  }
}

class _CreateStockTransferScreenState extends State<CreateStockTransferScreen> {
  late final LocationService _locationService;
  late final ProductVariantService _variantService;
  late final StockTransferService _transferService;
  late final InventoryService _inventoryService;

  List<Location> _locations = [];
  List<ProductVariant> _variants = [];

  /// Stock held at each location for each queued variant, keyed by variant id.
  final Map<int, List<Inventory>> _variantStock = {};

  Location? _fromLocation;
  Location? _toLocation;

  final TextEditingController _searchController = TextEditingController();

  final List<_TransferLine> _lines = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  List<ProductVariant> _filteredVariants = [];

  @override
  void initState() {
    super.initState();

    final apiService = ApiService();

    _locationService = LocationService(apiService);
    _variantService = ProductVariantService(apiService);
    _transferService = StockTransferService(apiService);
    _inventoryService = InventoryService(apiService);

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final locations = await _locationService.getLocations();
      final variants = await _variantService.getVariants();

      if (!mounted) return;

      setState(() {
        _locations = locations;
        _variants = variants;
        _filteredVariants = variants;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
        _isLoading = false;
      });
    }
  }

  void _searchVariants(String query) {
    final value = query.trim().toLowerCase();

    setState(() {
      if (value.isEmpty) {
        _filteredVariants = _variants;
        return;
      }

      _filteredVariants = _variants.where((variant) {
        return variant.modelNumber.toLowerCase().contains(value) ||
            variant.productName.toLowerCase().contains(value) ||
            variant.barcode.toLowerCase().contains(value) ||
            (variant.sizeName?.toLowerCase().contains(value) ?? false) ||
            (variant.colourName?.toLowerCase().contains(value) ?? false);
      }).toList();
    });
  }

  String _variantDisplayName(ProductVariant variant) {
    final parts = <String>[
      variant.productName,
      if (variant.sizeName != null) variant.sizeName!,
      if (variant.colourName != null) variant.colourName!,
    ];

    return parts.join(' - ');
  }

  bool _isQueued(ProductVariant variant) {
    return _lines.any((line) => line.variant.id == variant.id);
  }

  /// Asks for a quantity, then adds [variant] to the list of things to
  /// transfer, unless it is already queued.
  Future<void> _queueVariant(ProductVariant variant) async {
    if (_isQueued(variant)) {
      _showError(
        context.tr('{0} is already in the list.', [
          _variantDisplayName(variant),
        ]),
      );
      return;
    }

    final quantity = await _promptQuantity(variant);

    if (quantity == null || !mounted) return;

    setState(() {
      final line = _TransferLine(variant);
      line.quantityController.text = quantity.toString();

      _lines.add(line);
      _searchController.clear();
      _filteredVariants = _variants;
    });

    await _loadVariantStock(variant);
  }

  /// Loads the per-location stock for [variant] so each location can show how
  /// much of it is available.
  Future<void> _loadVariantStock(ProductVariant variant) async {
    if (_variantStock.containsKey(variant.id)) return;

    try {
      final inventory = await _inventoryService.getVariantInventory(variant.id);

      if (!mounted) return;

      setState(() {
        _variantStock[variant.id] = inventory;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    }
  }

  /// Stock held for [variant] at [location], or 0 when unknown.
  int _stockAt(ProductVariant variant, Location? location) {
    if (location == null) return 0;

    final inventory = _variantStock[variant.id];

    if (inventory == null) return 0;

    for (final item in inventory) {
      if (item.locationId == location.id) return item.quantity;
    }

    return 0;
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  int get _queuedCount => _lines.length;

  Future<void> _createTransfer() async {
    if (!ensureOnlineForWrite(context)) return;
    if (_fromLocation == null) {
      _showError(context.tr('Please select the source location.'));
      return;
    }

    if (_toLocation == null) {
      _showError(context.tr('Please select the destination location.'));
      return;
    }

    if (_fromLocation!.id == _toLocation!.id) {
      _showError(
        context.tr('Source and destination locations must be different.'),
      );
      return;
    }

    if (_lines.isEmpty) {
      _showError(context.tr('Add at least one product variant.'));
      return;
    }

    for (final line in _lines) {
      if (line.quantity <= 0) {
        _showError(
          context.tr('Quantity for {0} must be greater than zero.', [
            _variantDisplayName(line.variant),
          ]),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _transferService.createTransfer(
        fromLocationId: _fromLocation!.id,
        toLocationId: _toLocation!.id,
        items: _lines
            .map(
              (line) => StockTransferLine(
                productVariantId: line.variant.id,
                quantity: line.quantity,
              ),
            )
            .toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Transfer of {0} variant(s) created successfully.', [
              _queuedCount,
            ]),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLocationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: context.tr('1. Locations'),
          subtitle: context.tr('Pick source and destination for every variant'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Location>(
          key: ValueKey('from-${_fromLocation?.id}'),
          initialValue: _fromLocation,
          decoration: InputDecoration(
            labelText: context.tr('From Location'),
            prefixIcon: const Icon(Icons.file_upload_outlined),
          ),
          items: _locations.map((location) {
            return DropdownMenuItem<Location>(
              value: location,
              child: Text(location.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _fromLocation = value;

              if (_toLocation?.id == value?.id) {
                _toLocation = null;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Location>(
          key: ValueKey('to-${_toLocation?.id}'),
          initialValue: _toLocation,
          decoration: InputDecoration(
            labelText: context.tr('To Location'),
            prefixIcon: const Icon(Icons.file_download_outlined),
          ),
          items: _locations.map((location) {
            return DropdownMenuItem<Location>(
              value: location,
              child: Text(location.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _toLocation = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildVariantPicker() {
    final showResults = _searchController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.tr('2. Products'),
          subtitle: context.tr('Search and add the variants to transfer'),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _searchController,
          onChanged: _searchVariants,
          decoration: InputDecoration(
            labelText: context.tr('Search Product'),
            hintText: context.tr('Model, name, barcode, size, colour'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),

        if (showResults) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _filteredVariants.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.tr('No variants found.')),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredVariants.length,
                    itemBuilder: (context, index) {
                      final variant = _filteredVariants[index];

                      final queued = _isQueued(variant);

                      return Card(
                        child: ListTile(
                          enabled: !queued,
                          title: Text(_variantDisplayName(variant)),
                          subtitle: Text(
                            context.tr(
                              'Model: {0}\nQuantity: {1}\nBarcode: {2}',
                              [
                                variant.modelNumber,
                                variant.totalQuantity,
                                variant.barcode,
                              ],
                            ),
                          ),
                          trailing: queued
                              ? const Icon(Icons.check_circle_rounded)
                              : IconButton(
                                  tooltip: context.tr('Add to transfer'),
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _queueVariant(variant),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],

        const SizedBox(height: 12),
        _buildQueuedList(),
      ],
    );
  }

  /// Opens a small dialog to set the quantity for [variant]. Returns the
  /// entered quantity, or null if cancelled.
  Future<int?> _promptQuantity(ProductVariant variant) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) =>
          _QuantityDialog(title: _variantDisplayName(variant)),
    );

    if (value == null) return null;

    return int.tryParse(value.trim());
  }

  Widget _buildQueuedList() {
    if (_lines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: context.tr('No variants added yet'),
            message: context.tr(
              'Search above and add the variants you want to transfer.',
            ),
          ),
        ),
      );
    }

    final total = _lines.fold<int>(0, (sum, line) => sum + line.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            context.tr('{0} variant(s) · {1} unit(s)', [_queuedCount, total]),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...List.generate(_lines.length, (index) {
          final line = _lines[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _variantDisplayName(line.variant),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('Model: {0}', [line.variant.modelNumber]),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            Text(
                              _fromLocation == null
                                  ? context.tr('From: —')
                                  : context.tr('From: {0} ({1})', [
                                      _fromLocation!.name,
                                      _stockAt(line.variant, _fromLocation),
                                    ]),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                            Text(
                              _toLocation == null
                                  ? context.tr('To: —')
                                  : context.tr('To: {0} ({1})', [
                                      _toLocation!.name,
                                      _stockAt(line.variant, _toLocation),
                                    ]),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: line.quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: context.tr('Qty'),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove'),
                    onPressed: () => _removeLine(index),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Create Stock Transfer'))),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : ResponsiveFormPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLocationForm(),
                  const SizedBox(height: 24),
                  _buildVariantPicker(),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSubmitting || _lines.isEmpty
                        ? null
                        : _createTransfer,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      _queuedCount > 0
                          ? context.tr('Transfer {0} variant(s)', [
                              _queuedCount,
                            ])
                          : context.tr('Transfer Stock'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  final String title;

  const _QuantityDialog({required this.title});

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final TextEditingController _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: context.tr('Quantity'),
          prefixIcon: const Icon(Icons.pin_outlined),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.tr('Set')),
        ),
      ],
    );
  }
}
