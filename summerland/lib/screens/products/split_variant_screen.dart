import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/colour.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/size_model.dart';

import '../../services/api_service.dart';
import '../../services/colour_service.dart';
import '../../services/product_variant_service.dart';
import '../../services/size_service.dart';

import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';

/// Redistributes the stock of an auto-created default variant (no size, no
/// colour) across new size/colour variants. The quantities entered must total
/// the source variant's stock; the source variant is deleted once emptied.
class SplitVariantScreen extends StatefulWidget {
  final Product product;
  final ProductVariant sourceVariant;
  final List<SizeModel> sizes;
  final List<Colour> colours;

  const SplitVariantScreen({
    super.key,
    required this.product,
    required this.sourceVariant,
    required this.sizes,
    required this.colours,
  });

  @override
  State<SplitVariantScreen> createState() => _SplitVariantScreenState();
}

class _SplitVariantRow {
  int? sizeId;
  int? colourId;
  final TextEditingController quantityController;

  _SplitVariantRow() : quantityController = TextEditingController();

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;

  void dispose() {
    quantityController.dispose();
  }
}

class _SplitVariantScreenState extends State<SplitVariantScreen> {
  final ProductVariantService _variantService = ProductVariantService(
    ApiService(),
  );

  final SizeService _sizeService = SizeService(ApiService());

  final ColourService _colourService = ColourService(ApiService());

  final List<_SplitVariantRow> _rows = [];

  late List<SizeModel> _sizes;

  late List<Colour> _colours;

  bool _isSaving = false;

  bool _isCreatingOption = false;

  int get _sourceStock => widget.sourceVariant.totalQuantity;

  int get _assigned => _rows.fold(0, (sum, row) => sum + row.quantity);

  int get _remaining => _sourceStock - _assigned;

  @override
  void initState() {
    super.initState();

    _sizes = List.of(widget.sizes);
    _colours = List.of(widget.colours);

    _addRow();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }

    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_SplitVariantRow());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  /// Distributes whatever is left evenly across the current rows, so the
  /// numbers always add up to the source stock.
  void _distributeEvenly() {
    if (_rows.isEmpty || _sourceStock <= 0) return;

    final base = _sourceStock ~/ _rows.length;
    var remainder = _sourceStock % _rows.length;

    setState(() {
      for (final row in _rows) {
        final quantity = base + (remainder > 0 ? 1 : 0);

        if (remainder > 0) remainder--;

        row.quantityController.text = quantity.toString();
      }
    });
  }

  Future<void> _save() async {
    if (!ensureOnlineForWrite(context)) return;
    if (_isSaving) return;

    if (_rows.isEmpty) {
      _showError(context.tr('Add at least one split.'));
      return;
    }

    final seen = <String>{};

    for (final row in _rows) {
      if (row.sizeId == null && row.colourId == null) {
        _showError(context.tr('Each split needs a size or a colour.'));
        return;
      }

      if (row.quantity <= 0) {
        _showError(
          context.tr('Every split quantity must be greater than zero.'),
        );
        return;
      }

      final key = '${row.sizeId ?? '-'}:${row.colourId ?? '-'}';

      if (!seen.add(key)) {
        _showError(
          context.tr('Each split must target a different size and colour.'),
        );
        return;
      }
    }

    if (_remaining != 0) {
      _showError(
        _remaining > 0
            ? context.tr('Assign the remaining {0} unit(s).', [_remaining])
            : context.tr('You assigned {0} unit(s) too many.', [-_remaining]),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final splits = _rows
        .map(
          (row) => <String, dynamic>{
            'sizeId': row.sizeId,
            'colourId': row.colourId,
            'quantity': row.quantity,
          },
        )
        .toList();

    scheduleUndoable(
      context,
      message: context.tr('This variant will be split. Tap Undo to cancel.'),
      operation: () => _variantService.splitVariant(
        sourceVariantId: widget.sourceVariant.id,
        splits: splits,
      ),
      onCommitted: () async {
        if (!mounted) return;

        Navigator.pop(context, true);
      },
      onUndone: () {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addSize(_SplitVariantRow row) async {
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Size'),
      label: context.tr('Size Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.trim().isEmpty) return;

    final trimmed = name.trim();

    final existing = _sizes.where(
      (size) => size.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      setState(() {
        row.sizeId = existing.first.id;
      });
      return;
    }

    setState(() {
      _isCreatingOption = true;
    });

    try {
      final size = await _sizeService.createSize(trimmed);

      if (!mounted) return;

      setState(() {
        _sizes = [..._sizes, size];
        row.sizeId = size.id;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOption = false;
        });
      }
    }
  }

  Future<void> _addColour(_SplitVariantRow row) async {
    if (_isCreatingOption) return;

    final name = await showAppNameDialog(
      context,
      title: context.tr('Add Colour'),
      label: context.tr('Colour Name'),
      confirmLabel: context.tr('Add'),
    );

    if (name == null || name.trim().isEmpty) return;

    final trimmed = name.trim();

    final existing = _colours.where(
      (colour) => colour.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      setState(() {
        row.colourId = existing.first.id;
      });
      return;
    }

    setState(() {
      _isCreatingOption = true;
    });

    try {
      final colour = await _colourService.createColour(trimmed);

      if (!mounted) return;

      setState(() {
        _colours = [..._colours, colour];
        row.colourId = colour.id;
      });
    } catch (e) {
      if (!mounted) return;

      _showError(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOption = false;
        });
      }
    }
  }

  String _variantLabel(_SplitVariantRow row) {
    String? size;

    for (final item in _sizes) {
      if (item.id == row.sizeId) {
        size = item.name;
        break;
      }
    }

    String? colour;

    for (final item in _colours) {
      if (item.id == row.colourId) {
        colour = item.name;
        break;
      }
    }

    return [if (size != null) size, if (colour != null) colour].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Split Into Variants'))),
      body: ResponsiveFormPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceCard(),
            const SizedBox(height: 20),
            SectionHeader(
              title: context.tr('Distribute Stock'),
              subtitle: context.tr(
                'Assign a size and/or colour to each portion.',
              ),
              trailing: Row(
                children: [
                  TextButton.icon(
                    onPressed: _distributeEvenly,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(context.tr('Even')),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: context.tr('Add split'),
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_rows.length, _buildRow),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving || _remaining != 0 ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.call_split),
                label: Text(context.tr('Split Variant')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Model: {0}', [widget.product.modelNumber]),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            InfoTile(
              label: context.tr('Default variant stock'),
              value: '$_sourceStock',
              valueStyle: amountStyle(context, _sourceStock.toDouble()),
            ),
            Text(
              context.tr(
                'The default variant will be removed once all stock is assigned.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton.filledTonal(
        onPressed: _isCreatingOption ? null : onPressed,
        icon: _isCreatingOption
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  Widget _buildRow(int index) {
    final row = _rows[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _variantLabel(row).isEmpty
                        ? context.tr('Assignment {0}', [index + 1])
                        : _variantLabel(row),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Remove'),
                  onPressed: _rows.length == 1 ? null : () => _removeRow(index),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('split-size-$index-${row.sizeId}'),
                    initialValue: row.sizeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Size'),
                      prefixIcon: const Icon(Icons.straighten_outlined),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(context.tr('Any')),
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
                        row.sizeId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _buildAddButton(
                  icon: Icons.straighten_outlined,
                  label: context.tr('Add size'),
                  onPressed: () => _addSize(row),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('split-colour-$index-${row.colourId}'),
                    initialValue: row.colourId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Colour'),
                      prefixIcon: const Icon(Icons.palette_outlined),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(context.tr('Any')),
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
                        row.colourId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _buildAddButton(
                  icon: Icons.palette_outlined,
                  label: context.tr('Add colour'),
                  onPressed: () => _addColour(row),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.quantityController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('Quantity'),
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isBalanced = _remaining == 0;

    final color = isBalanced
        ? Theme.of(context).colorScheme.primary
        : (_remaining > 0
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.error);

    final label = _remaining == 0
        ? context.tr('All {0} unit(s) assigned.', [_sourceStock])
        : (_remaining > 0
              ? context.tr('{0} unit(s) left to assign.', [_remaining])
              : context.tr('{0} unit(s) too many.', [-_remaining]));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isBalanced ? Icons.check_circle_outline : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$_assigned / $_sourceStock',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
