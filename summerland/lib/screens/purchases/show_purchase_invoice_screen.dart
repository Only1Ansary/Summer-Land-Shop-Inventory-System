import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../localization/app_strings.dart';
import '../../models/product.dart';
import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_printer.dart';
import '../../services/product_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../utils/payment_method.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'return_purchase_items_screen.dart';
import '../../ui/text_input_helpers.dart';

class ShowPurchaseInvoiceScreen extends StatefulWidget {
  const ShowPurchaseInvoiceScreen({super.key, this.invoice, this.invoiceId});

  final PurchaseInvoice? invoice;
  final int? invoiceId;

  @override
  State<ShowPurchaseInvoiceScreen> createState() =>
      _ShowPurchaseInvoiceScreenState();
}

class _ShowPurchaseInvoiceScreenState extends State<ShowPurchaseInvoiceScreen> {
  final PurchaseInvoiceService _purchaseInvoiceService = PurchaseInvoiceService(
    ApiService(),
  );
  final ProductService _productService = ProductService(ApiService());

  PurchaseInvoice? _invoice;
  bool _isLoading = false;
  String? _error;

  static const Color _paidColor = Color(0xFF2E9E6B);

  @override
  void initState() {
    super.initState();

    _invoice = widget.invoice;
    _isLoading = widget.invoice == null;

    _load();
  }

  // ---------------------------------------------------------------------------
  // Logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    try {
      if (widget.invoiceId != null) {
        final invoice = await _purchaseInvoiceService.getPurchaseInvoice(
          widget.invoiceId!,
        );

        if (!mounted) return;

        _invoice = invoice;
      } else {
        _invoice = widget.invoice;
      }

      await _enrichItemNames();
    } catch (e) {
      if (!mounted) return;

      if (_invoice != null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error = friendlyErrorMessage(context, e);
        _isLoading = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _enrichItemNames() async {
    final invoice = _invoice;

    if (invoice == null || invoice.items.isEmpty) return;

    try {
      final products = await _productService.getProducts();

      if (!mounted) return;

      final productById = {for (final product in products) product.id: product};

      for (final item in invoice.items) {
        final Product? product = productById[item.productId];

        item.productName = product?.name;
        item.modelNumber = product?.modelNumber;
      }

      setState(() {});
    } catch (e) {
      // Product lookup is best-effort; item rows still show prices.
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _load();
  }

  Future<void> _openReturnScreen() async {
    if (!ensureOnlineForWrite(context)) return;

    final invoice = _invoice;

    if (invoice == null) return;

    final returned = await pushScreen<DeferredCrud>(
      context,
          (_) => ReturnPurchaseItemsScreen(invoice: invoice),
    );

    if (returned == null || !mounted) return;

    scheduleDeferredCrud(context, returned, onCommitted: () async => _retry());
  }

  Future<void> _payDebt() async {
    if (!ensureOnlineForWrite(context)) return;

    final invoice = _invoice;

    if (invoice == null || invoice.debt <= 0) return;

    final remaining = invoice.debt;
    final initialMethod = paymentMethodValues.contains(invoice.paymentMethod)
        ? invoice.paymentMethod
        : paymentMethodCash;

    // The dialog is its own StatefulWidget so that its TextEditingController
    // is created and disposed by the framework together with the dialog's
    // element tree. Disposing a controller right after `showDialog` returns
    // runs while the route's exit animation is still building the TextField,
    // which crashes on Android when the keyboard is open.
    final entry = await showDialog<_PurchasePaymentEntry>(
      context: context,
      builder: (dialogContext) => _PayDebtDialog(
        remaining: remaining,
        initialMethod: initialMethod,
      ),
    );

    if (entry == null || !mounted) return;

    final amount = double.tryParse(entry.amountText.trim());

    if (amount == null || amount <= 0) {
      _showMessage(context.tr('Enter a valid payment amount.'));
      return;
    }

    if (amount > remaining) {
      _showMessage(
        context.tr('Payment cannot exceed the remaining debt of {0}.', [
          money(remaining),
        ]),
      );
      return;
    }

    scheduleUndoable(
      context,
      message: context.tr('Payment will be recorded. Tap Undo to cancel.'),
      operation: () => _purchaseInvoiceService.payDebt(
        invoiceId: invoice.id,
        amount: amount,
        method: entry.method,
      ),
      onCommitted: () async => _retry(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small visual helpers
  // ---------------------------------------------------------------------------

  Widget _sectionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        Widget? trailing,
        required Widget child,
      }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
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
                  child: Icon(icon, size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table helpers
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

  Widget _indexCell(int index) {
    return _cell(
      Text(
        '${index + 1}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      alignment: Alignment.center,
    );
  }

  Widget _qtyCell(Object quantity) {
    final scheme = Theme.of(context).colorScheme;

    return _cell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$quantity',
          style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
        ),
      ),
      alignment: Alignment.center,
    );
  }

  BoxDecoration _zebra(int index) {
    final scheme = Theme.of(context).colorScheme;

    return BoxDecoration(
      color: index.isOdd
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : Colors.transparent,
    );
  }

  Widget _tableShell({
    required Map<int, TableColumnWidth> columnWidths,
    required double minWidth,
    required List<Widget> headers,
    required List<TableRow> rows,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, minWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: columnWidths,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: scheme.primaryContainer),
                  children: headers,
                ),
                ...rows,
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? context.tr('Purchase Invoice')
              : context.tr('Purchase Invoice #{0}', [invoice.id]),
        ),
        actions: [
          if (invoice != null &&
              defaultTargetPlatform != TargetPlatform.android)
            IconButton(
              tooltip: context.tr('Print'),
              icon: const Icon(Icons.print_outlined),
              onPressed: () => InvoicePrinter.printPurchaseInvoice(invoice),
            ),
          if (invoice != null && invoice.items.isNotEmpty)
            IconButton(
              tooltip: context.tr('Return Items'),
              icon: const Icon(Icons.assignment_return_outlined),
              onPressed: _openReturnScreen,
            ),
          if (invoice != null && invoice.debt > 0)
            IconButton(
              tooltip: context.tr('Pay Debt'),
              icon: const Icon(Icons.payments_outlined),
              onPressed: _payDebt,
            ),
        ],
      ),
      body: _buildBody(invoice),
    );
  }

  Widget _buildBody(PurchaseInvoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _retry);
    }

    if (invoice == null) {
      return EmptyState(title: context.tr('No purchase invoice'));
    }

    return WideContent(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeroCard(invoice),
          const SizedBox(height: 14),
          if (invoice.items.isNotEmpty) _buildItemsCard(invoice),
          if (invoice.returns.isNotEmpty) _buildReturnsCard(invoice),
          if (invoice.fees.isNotEmpty) _buildFeesCard(invoice),
          _buildTotalsCard(invoice),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _metaChip(IconData icon, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ? scheme.primaryContainer : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
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

  Widget _buildHeroCard(PurchaseInvoice invoice) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = invoice.date ?? invoice.createdAt;
    final hasDebt = invoice.debt > 0;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;

              final invoiceTitle = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: foregroundColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Purchase Invoice #{0}', [invoice.id]),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );

              final paymentStatus = _pill(
                context,
                hasDebt
                    ? '${context.tr('Debt')}: ${money(invoice.debt)}'
                    : context.tr('Paid'),
                foregroundColor,
                icon: hasDebt
                    ? Icons.hourglass_bottom_rounded
                    : Icons.check_circle_rounded,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    invoiceTitle,
                    const SizedBox(height: 12),
                    paymentStatus,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: invoiceTitle),
                  const SizedBox(width: 12),
                  paymentStatus,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Total Cost'),
            style: TextStyle(color: secondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              money(invoice.totalCost),
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
              _metaChip(Icons.business_outlined, invoice.supplierName),
              _metaChip(Icons.event_outlined, DateFormat('yyyy/MM/dd HH:mm:ss').format(date)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  Widget _buildItemsCard(PurchaseInvoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    final rows = <TableRow>[];
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final displayName =
          item.productName ?? context.tr('Product #{0}', [item.productId]);

      rows.add(
        TableRow(
          decoration: _zebra(i),
          children: [
            _indexCell(i),
            _cell(
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _cell(_textOrDash(item.modelNumber)),
            _qtyCell(item.quantity),
            _cell(
              Text(
                money(item.unitPurchasePrice),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              alignment: Alignment.centerRight,
            ),
            _cell(
              Text(
                money(item.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      context,
      icon: Icons.inventory_2_outlined,
      title: context.tr('Items'),
      subtitle: context.tr('Products received on this purchase'),
      trailing: _pill(context, '${invoice.items.length}', scheme.primary),
      child: _tableShell(
        minWidth: 640,
        columnWidths: const {
          0: FixedColumnWidth(48),
          1: FlexColumnWidth(3.2),
          2: FlexColumnWidth(1.8),
          3: FixedColumnWidth(72),
          4: FlexColumnWidth(1.8),
          5: FlexColumnWidth(1.9),
        },
        headers: [
          _headerCell('#', alignment: Alignment.center),
          _headerCell(context.tr('Product Name')),
          _headerCell(context.tr('Model')),
          _headerCell(context.tr('Qty'), alignment: Alignment.center),
          _headerCell(
            context.tr('Unit price'),
            alignment: Alignment.centerRight,
          ),
          _headerCell(context.tr('Total'), alignment: Alignment.centerRight),
        ],
        rows: rows,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Returns
  // ---------------------------------------------------------------------------

  Widget _buildReturnsCard(PurchaseInvoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    final rows = <TableRow>[];
    for (var i = 0; i < invoice.returns.length; i++) {
      final ret = invoice.returns[i];
      final date = ret.createdAt;

      rows.add(
        TableRow(
          decoration: _zebra(i),
          children: [
            _indexCell(i),
            _cell(
              Text(
                ret.productName.isEmpty
                    ? context.tr('Product #{0}', [ret.productId])
                    : ret.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _qtyCell(ret.quantity),
            _cell(
              Text(
                money(ret.unitPurchasePrice),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              alignment: Alignment.centerRight,
            ),
            _cell(_textOrDash(ret.reason)),
            _cell(_textOrDash(date == null ? null : '$date')),
            _cell(
              Text(
                money(ret.totalPrice),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.error,
                ),
              ),
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      context,
      icon: Icons.assignment_return_outlined,
      title: context.tr('Returns'),
      subtitle: context.tr('Items returned against this purchase'),
      trailing: _pill(context, '${invoice.returns.length}', scheme.error),
      child: _tableShell(
        minWidth: 860,
        columnWidths: const {
          0: FixedColumnWidth(48),
          1: FlexColumnWidth(3),
          2: FixedColumnWidth(72),
          3: FlexColumnWidth(1.7),
          4: FlexColumnWidth(2.4),
          5: FlexColumnWidth(2.2),
          6: FlexColumnWidth(1.8),
        },
        headers: [
          _headerCell('#', alignment: Alignment.center),
          _headerCell(context.tr('Product Name')),
          _headerCell(context.tr('Qty'), alignment: Alignment.center),
          _headerCell(
            context.tr('Unit price'),
            alignment: Alignment.centerRight,
          ),
          _headerCell(context.tr('Reason')),
          _headerCell(context.tr('Date')),
          _headerCell(context.tr('Total'), alignment: Alignment.centerRight),
        ],
        rows: rows,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fees
  // ---------------------------------------------------------------------------

  Widget _buildFeesCard(PurchaseInvoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    final rows = <TableRow>[];
    for (var i = 0; i < invoice.fees.length; i++) {
      final fee = invoice.fees[i];

      rows.add(
        TableRow(
          decoration: _zebra(i),
          children: [
            _indexCell(i),
            _cell(
              Text(
                fee.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _cell(
              fee.isPaid
                  ? _pill(
                context,
                context.tr('Paid (total cost)'),
                _paidColor,
                icon: Icons.check_circle_outline,
              )
                  : _pill(
                context,
                context.tr('Unpaid (debt)'),
                scheme.error,
                icon: Icons.local_shipping_outlined,
              ),
            ),
            _cell(
              Text(
                money(fee.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      context,
      icon: Icons.local_shipping_outlined,
      title: context.tr('Extra Fees'),
      subtitle: context.tr(
        'Paid fees add to the total cost; unpaid fees add to debt',
      ),
      trailing: _pill(context, '${invoice.fees.length}', scheme.primary),
      child: _tableShell(
        minWidth: 520,
        columnWidths: const {
          0: FixedColumnWidth(48),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(2.4),
          3: FlexColumnWidth(1.8),
        },
        headers: [
          _headerCell('#', alignment: Alignment.center),
          _headerCell(context.tr('Description')),
          _headerCell(context.tr('Status')),
          _headerCell(context.tr('Amount'), alignment: Alignment.centerRight),
        ],
        rows: rows,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  Widget _buildTotalsCard(PurchaseInvoice invoice) {

    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ? scheme.primaryContainer : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InfoTile(
            label: context.tr('Total Cost'),
            value: money(invoice.totalCost),
          ),
          InfoTile(
            label: context.tr('Total Paid'),
            value: money(invoice.totalPaid),
          ),
          InfoTile(
            label: context.tr('Payment method'),
            value: paymentMethodLabel(context, invoice.paymentMethod),
          ),
          const Divider(height: 20),
          InfoTile(
            label: context.tr('Debt'),
            value: moneyNegative(invoice.debt),
            valueStyle: amountStyle(context, -invoice.debt),
          ),
          InfoTile(
            label: context.tr('Supplier Total Debt'),
            value: moneyNegative(invoice.supplierTotalDebt),
            valueStyle: amountStyle(context, -invoice.supplierTotalDebt),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared pill helper (top-level so both the screen and the dialog can use it)
// -----------------------------------------------------------------------------

Widget _pill(
    BuildContext context,
    String text,
    Color color, {
      IconData? icon,
      bool onDark = false,
    }) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final fg = onDark ? scheme.primaryContainer : color;
  final bg = onDark
      ? scheme.primaryContainer.withValues(alpha: 0.2)
      : color.withValues(alpha: 0.12);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Pay debt dialog
// -----------------------------------------------------------------------------

class _PayDebtDialog extends StatefulWidget {
  const _PayDebtDialog({
    required this.remaining,
    required this.initialMethod,
  });

  final double remaining;
  final int initialMethod;

  @override
  State<_PayDebtDialog> createState() => _PayDebtDialogState();
}

class _PayDebtDialogState extends State<_PayDebtDialog> {
  late final TextEditingController _amountController;
  late int _method;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remaining.toStringAsFixed(2),
    );
    _method = widget.initialMethod;
  }

  @override
  void dispose() {
    // Runs only once the dialog route has been fully removed from the tree.
    _amountController.dispose();
    super.dispose();
  }

  void _cancel() {
    // Let the keyboard start closing before the route's exit animation.
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _PurchasePaymentEntry(
        amountText: _amountController.text,
        method: _method,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      // With the default padding, the title and button bar alone can
      // overflow the space left by a tall Android on-screen keyboard.
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      // Title and buttons are inside the scrollable content so every part
      // of the dialog can scroll when the keyboard shrinks the viewport.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('Pay Debt'))),
            ],
          ),
          const SizedBox(height: 20),
          _pill(
            context,
            context.tr('Remaining debt: {0}', [money(widget.remaining)]),
            scheme.error,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            // Avoid opening the keyboard (and shrinking the viewport)
            // as soon as the dialog appears on Android.
            autofocus: textFieldAutofocus(true),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*$'),
              ),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              prefixText: '\u20a6 ',
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 1.6),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('purchase-payment-method'),
            initialValue: _method,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Payment method'),
              prefixIcon: const Icon(Icons.credit_card_outlined),
            ),
            items: paymentMethodValues.map((value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Row(
                  children: [
                    Icon(paymentMethodIcon(value), size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        paymentMethodLabel(context, value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _method = value);
            },
          ),
          const SizedBox(height: 20),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: _cancel,
                child: Text(context.tr('Cancel')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('Pay')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Amount and method chosen in the per-invoice purchase payment dialog.
class _PurchasePaymentEntry {
  const _PurchasePaymentEntry({required this.amountText, required this.method});

  final String amountText;
  final int method;
}