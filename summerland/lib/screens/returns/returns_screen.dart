import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../localization/app_strings.dart';
import '../../models/invoice.dart';
import '../../models/location.dart';
import '../../models/invoice_item.dart';
import '../../models/return_model.dart';
import '../../services/api_service.dart';
import '../../services/invoice_service.dart';
import '../../services/location_service.dart';
import '../../services/return_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import '../../ui/text_input_helpers.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final ApiService _apiService = ApiService();

  late final InvoiceService _invoiceService;
  late final LocationService _locationService;
  late final ReturnService _returnService;

  final TextEditingController _invoiceIdController = TextEditingController();

  Invoice? _invoice;
  List<Location> _locations = [];

  bool _isLoadingLocations = true;
  bool _isLoadingInvoice = false;

  // Minimum width of the items table; narrower screens scroll sideways.
  static const double _tableMinWidth = 880;

  @override
  void initState() {
    super.initState();

    _invoiceService = InvoiceService(_apiService);
    _locationService = LocationService(_apiService);
    _returnService = ReturnService(_apiService);

    _loadLocations();
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _loadLocations() async {
    try {
      final locations = await _locationService.getLocations();

      if (!mounted) return;

      setState(() {
        _locations = locations;
        _isLoadingLocations = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingLocations = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
  }

  Future<void> _loadInvoice() async {
    final invoiceId = int.tryParse(_invoiceIdController.text.trim());

    if (invoiceId == null || invoiceId <= 0) {
      _showError(context.tr('Please enter a valid invoice ID.'));
      return;
    }

    setState(() {
      _isLoadingInvoice = true;
      _invoice = null;
    });

    try {
      final invoice = await _invoiceService.getInvoice(invoiceId);

      if (!mounted) return;

      setState(() {
        _invoice = invoice;
        _isLoadingInvoice = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingInvoice = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
  }

  Future<void> _showReturnDialog(InvoiceItem item) async {
    if (_locations.isEmpty) {
      _showError(context.tr('No stock locations available.'));
      return;
    }

    final result = await showDialog<_ReturnData>(
      context: context,
      builder: (context) =>
          _ReturnItemDialog(item: item, locations: _locations),
    );

    if (result == null) return;

    await _createReturn(item: item, data: result);
  }

  Future<void> _createReturn({
    required InvoiceItem item,
    required _ReturnData data,
  }) async {
    ReturnModel? returnRecord;

    scheduleUndoable(
      context,
      message: context.tr('Return will be created. Tap Undo to cancel.'),
      operation: () async {
        returnRecord = await _returnService.createReturn(
          invoiceId: _invoice!.id,
          productVariantId: item.productVariantId,
          quantity: data.quantity,
          stockLocationId: data.stockLocation.id,
          reason: data.reason,
        );
      },
      onCommitted: () async {
        if (!mounted) return;

        final record = returnRecord;

        if (record == null) return;

        await showDialog(
          context: context,
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;

            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppPalette.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('Return Created'))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(
                        label: context.tr('DONE'),
                        color: AppPalette.success,
                        icon: Icons.check_circle_outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.productName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        InfoTile(
                          label: context.tr('Quantity'),
                          value: '${record.quantity}',
                        ),
                        if (item.hasDiscount) ...[
                          InfoTile(
                            label: context.tr('Unit before discount'),
                            value: money(item.unitPrice),
                            valueStyle: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.outline,
                            ),
                          ),
                          InfoTile(
                            label: context.tr('Unit after discount'),
                            value: money(record.unitPrice),
                            valueStyle: amountStyle(context, record.unitPrice),
                          ),
                          InfoTile(
                            label: context.tr('Total before discount'),
                            value: money(item.unitPrice * record.quantity),
                            valueStyle: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                        InfoTile(
                          label: context.tr('Location'),
                          value: record.locationName,
                        ),
                        const Divider(height: 18),
                        InfoTile(
                          label: context.tr('Total'),
                          value: money(record.totalAmount),
                          valueStyle: amountStyle(context, record.totalAmount),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(context.tr('OK')),
                ),
              ],
            );
          },
        );

        if (!mounted) return;

        await _loadInvoice();
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Returns'),
      destinationId: 'returns',
      body: _isLoadingLocations
          ? const LoadingState()
          : Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(
                  _isLoadingInvoice ? 'loading' : (_invoice?.id ?? 'empty'),
                ),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingInvoice) return const LoadingState();

    if (_invoice == null) {
      return EmptyState(
        icon: Icons.assignment_return_outlined,
        title: context.tr('Enter an invoice ID to start a return.'),
        message: context.tr('Load an invoice to return sold items.'),
      );
    }

    return _buildInvoice();
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: WideContent(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _invoiceIdController,
                autofocus: textFieldAutofocus(true),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.tr('Invoice ID'),
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  filled: true,
                  fillColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: scheme.primary, width: 1.6),
                  ),
                ),
                onSubmitted: (_) => _loadInvoice(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isLoadingInvoice ? null : _loadInvoice,
                icon: _isLoadingInvoice
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.search_rounded),
                label: Text(context.tr('Load')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Invoice view
  // ---------------------------------------------------------------------------

  Widget _metaChip(IconData icon, String text) {

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ?  scheme.primaryContainer : Colors.white;
    final secondaryColor = isDark ? scheme.primaryContainer : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: secondaryColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Invoice invoice) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ? scheme.primaryContainer : Colors.white;
    final secondaryColor = isDark ? scheme.primaryContainer : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55) ?? scheme.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: foregroundColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: foregroundColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('Invoice #{0}', [invoice.id]),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Invoice Total'),
            style: TextStyle(color: secondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              money(invoice.totalAmount),
              style: TextStyle(
                color: foregroundColor,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Icons.storefront_outlined, invoice.locationName),
              _metaChip(
                Icons.event_outlined,
                formatDisplayDateTime(
                  invoice.createdAt,
                  am: context.tr('AM'),
                  pm: context.tr('PM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoice() {
    final invoice = _invoice!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return WideContent(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeroCard(invoice),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.assignment_return_outlined,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Invoice Items'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              context.tr(
                                'Return an item with the Return button',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${invoice.items.length}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (invoice.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: EmptyState(
                      icon: Icons.assignment_return_outlined,
                      title: context.tr('Fully returned'),
                      message: context.tr(
                        'Every item on this invoice was returned.',
                      ),
                    ),
                  )
                else
                  _buildItemsTable(invoice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items table
  // ---------------------------------------------------------------------------

  Widget _headerCell(String text, {Alignment alignment = Alignment.centerLeft}) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _cell(Widget child, {Alignment alignment = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(alignment: alignment, child: child),
    );
  }

  Widget _textOrDash(String? value) {
    if (value == null || value.trim().isEmpty) {
      return Text(
        '-',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }
    return Text(value, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  TableRow _itemRow(int index, InvoiceItem item) {
    final scheme = Theme.of(context).colorScheme;
    final zebra = index.isOdd
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : Colors.transparent;

    final Widget unitPriceCell;
    if (!item.hasDiscount) {
      unitPriceCell = Text(
        money(item.unitPrice),
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      unitPriceCell = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            money(item.unitPrice),
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
              color: scheme.outline,
            ),
          ),
          Text(
            money(item.unitPriceAfterDiscount),
            style: TextStyle(
              color: amountColor(context, item.unitPriceAfterDiscount),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final Widget discountCell;
    if (!item.hasDiscount) {
      discountCell = _textOrDash(null);
    } else {
      final percent = item.discountPercent == null
          ? ''
          : ' (${percentLabel(item.discountPercent!)})';
      discountCell = Text(
        '-${money(item.discountAmount)}$percent',
        style: TextStyle(
          color: amountColor(context, -item.discountAmount),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(color: zebra),
      children: [
        _cell(
          Text(
            '${index + 1}',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          alignment: Alignment.center,
        ),
        _cell(
          Text(
            item.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _cell(_textOrDash(item.modelNumber)),
        _cell(_textOrDash(item.sizeName)),
        _cell(_textOrDash(item.colourName)),
        _cell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          alignment: Alignment.center,
        ),
        _cell(unitPriceCell, alignment: Alignment.centerRight),
        _cell(discountCell, alignment: Alignment.centerRight),
        _cell(
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showReturnDialog(item),
            icon: const Icon(Icons.assignment_return_outlined, size: 15),
            label: Text(context.tr('Return'),
              style: TextStyle(fontWeight: FontWeight.w600),),
          ),
          alignment: Alignment.center,
        ),
      ],
    );
  }

  Widget _buildItemsTable(Invoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, _tableMinWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FixedColumnWidth(48),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(1.7),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.4),
                5: FixedColumnWidth(72),
                6: FlexColumnWidth(1.7),
                7: FlexColumnWidth(1.9),
                8: FixedColumnWidth(130),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: scheme.primaryContainer),
                  children: [
                    _headerCell('#', alignment: Alignment.center),
                    _headerCell(context.tr('Product Name')),
                    _headerCell(context.tr('Model')),
                    _headerCell(context.tr('Size')),
                    _headerCell(context.tr('Colour')),
                    _headerCell(
                      context.tr('Quantity'),
                      alignment: Alignment.center,
                    ),
                    _headerCell(
                      context.tr('Unit price'),
                      alignment: Alignment.centerRight,
                    ),
                    _headerCell(
                      context.tr('Discount'),
                      alignment: Alignment.centerRight,
                    ),
                    _headerCell('', alignment: Alignment.center),
                  ],
                ),
                for (var i = 0; i < invoice.items.length; i++)
                  _itemRow(i, invoice.items[i]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReturnData {
  final int quantity;
  final Location stockLocation;
  final String reason;

  _ReturnData({
    required this.quantity,
    required this.stockLocation,
    required this.reason,
  });
}

class _ReturnItemDialog extends StatefulWidget {
  const _ReturnItemDialog({required this.item, required this.locations});

  final InvoiceItem item;
  final List<Location> locations;

  @override
  State<_ReturnItemDialog> createState() => _ReturnItemDialogState();
}

class _ReturnItemDialogState extends State<_ReturnItemDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;

  Location? _selectedLocation;

  @override
  void initState() {
    super.initState();

    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _changeQuantity(int delta) {
    final current = int.tryParse(_quantityController.text.trim()) ?? 1;
    final next = (current + delta).clamp(1, math.max(1, widget.item.quantity));
    _quantityController.text = '$next';
  }

  void _submit() {
    final navigator = Navigator.of(context);
    final item = widget.item;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please choose a stock location.'))),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter a valid quantity.'))),
      );
      return;
    }

    if (quantity > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Maximum returnable quantity: {0}', [item.quantity]),
          ),
        ),
      );
      return;
    }

    navigator.pop(
      _ReturnData(
        quantity: quantity,
        stockLocation: _selectedLocation!,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  InputDecoration _fieldDecoration(
      BuildContext context, {
        required String label,
        IconData? icon,
        String? hint,
        String? helper,
      }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assignment_return_outlined,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.tr('Create Return'))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppPill(text: item.modelNumber),
                      if (item.sizeName != null)
                        AppPill(text: context.tr('Size: {0}', [item.sizeName])),
                      if (item.colourName != null)
                        AppPill(
                          text: context.tr('Colour: {0}', [item.colourName]),
                        ),
                      AppPill(
                        text: context.tr('Sold Quantity: {0}', [item.quantity]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!item.hasDiscount)
                    Text(
                      context.tr('Unit Price: {0}', [money(item.unitPrice)]),
                      style: TextStyle(
                        color: amountColor(context, item.unitPrice),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else ...[
                    Text(
                      context.tr('Unit price before discount: {0}', [
                        money(item.unitPrice),
                      ]),
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: scheme.outline,
                      ),
                    ),
                    Text(
                      context.tr('Unit price after discount: {0}', [
                        money(item.unitPriceAfterDiscount),
                      ]),
                      style: TextStyle(
                        color: amountColor(context, item.unitPriceAfterDiscount),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.tr('Discount: -{0}/unit{1}', [
                        money(item.discountAmount),
                        item.discountPercent == null
                            ? ''
                            : ' (${percentLabel(item.discountPercent!)})',
                      ]),
                      style: TextStyle(
                        color: amountColor(context, -item.discountAmount),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('location-${_selectedLocation?.id}'),
              initialValue: _selectedLocation?.id,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              decoration: _fieldDecoration(
                context,
                label: context.tr('Return Stock Location'),
                icon: Icons.location_on_outlined,
              ),
              items: widget.locations.map((location) {
                return DropdownMenuItem<int>(
                  value: location.id,
                  child: Text(location.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedLocation = widget.locations.firstWhere(
                        (location) => location.id == value,
                  );
                });
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton.filledTonal(
                    onPressed: () => _changeQuantity(-1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    autofocus: textFieldAutofocus(false),
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: _fieldDecoration(
                      context,
                      label: context.tr('Return Quantity'),
                      helper: context.tr(
                        'Maximum returnable quantity: {0}',
                        [item.quantity],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton.filledTonal(
                    onPressed: () => _changeQuantity(1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              autofocus: textFieldAutofocus(false),
              controller: _reasonController,
              maxLines: 3,
              decoration: _fieldDecoration(
                context,
                label: context.tr('Reason'),
                hint: context.tr('Enter return reason'),
                icon: Icons.notes_rounded,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(context.tr('Return')),
        ),
      ],
    );
  }
}