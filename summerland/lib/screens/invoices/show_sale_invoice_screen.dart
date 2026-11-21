import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../models/invoice.dart';
import '../../services/api_service.dart';
import '../../services/invoice_printer.dart';
import '../../services/invoice_service.dart';
import '../../ui/app_theme.dart';
import '../../utils/payment_method.dart';
import '../../ui/app_widgets.dart';

class ShowSaleInvoiceScreen extends StatefulWidget {
  const ShowSaleInvoiceScreen({super.key, this.invoice, this.invoiceId});

  final Invoice? invoice;
  final int? invoiceId;

  @override
  State<ShowSaleInvoiceScreen> createState() => _ShowSaleInvoiceScreenState();
}

class _ShowSaleInvoiceScreenState extends State<ShowSaleInvoiceScreen> {
  final InvoiceService _invoiceService = InvoiceService(ApiService());

  Invoice? _invoice;
  bool _isLoading = false;
  bool _isPaying = false;
  String? _error;

  static const Color _paidColor = Color(0xFF2E9E6B);

  // Minimum width of the items table; narrower screens scroll sideways.
  static const double _tableMinWidth = 860;

  @override
  void initState() {
    super.initState();

    _invoice = widget.invoice;
    _isLoading = widget.invoice == null;

    if (widget.invoiceId != null) {
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // Logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoice = await _invoiceService.getInvoice(widget.invoiceId!);

      if (!mounted) return;

      setState(() {
        _invoice = invoice;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (_invoice != null) {
          _isLoading = false;
        } else {
          _error = friendlyErrorMessage(context, e);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Opens a small form to settle part (or all) of an unpaid invoice.
  Future<void> _recordPayment() async {
    final invoice = _invoice;

    if (invoice == null || invoice.customerId == null) return;

    final remaining = invoice.remainingAmount;
    final amountController = TextEditingController(
      text: remaining.toStringAsFixed(2),
    );
    var method = invoice.paymentMethod ?? paymentMethodCash;

    final entry = await showDialog<_PaymentEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scheme = Theme.of(context).colorScheme;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_card_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('Record payment'))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pill(
                    context,
                    context.tr('Remaining: {0}', [money(remaining)]),
                    scheme.error,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    autofocus: true,
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
                      labelText: context.tr('Payment amount'),
                      prefixIcon: const Icon(Icons.payments_outlined),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: method,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    decoration: InputDecoration(
                      labelText: context.tr('Payment method'),
                      prefixIcon: const Icon(Icons.credit_card_outlined),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
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
                      setDialogState(() => method = value);
                    },
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('Cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              'Enter a payment amount greater than zero.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    if (amount > remaining) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              'Payment cannot exceed the remaining balance of {0}.',
                              [money(remaining)],
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _PaymentEntry(amount: amount, method: method),
                    );
                  },
                  child: Text(context.tr('Record payment')),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();

    if (entry == null || !mounted) return;

    setState(() {
      _isPaying = true;
    });

    try {
      final updated = await _invoiceService.payInvoice(
        invoiceId: invoice.id,
        amount: entry.amount,
        method: entry.method,
      );

      if (!mounted) return;

      setState(() {
        _invoice = updated;
      });

      _showMessage(context.tr('Payment recorded.'));
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyErrorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
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

  double _itemDiscountTotal(Invoice invoice) {
    return invoice.items.fold<double>(
      0,
          (total, item) => total + item.discountAmount * item.quantity,
    );
  }

  // The items total before any discount: everything still payable on the
  // invoice plus every discount that is still carried by its lines.
  double _subtotal(Invoice invoice) {
    return invoice.totalAmount +
        invoice.discountAmount +
        _itemDiscountTotal(invoice);
  }

  // ---------------------------------------------------------------------------
  // Small visual helpers
  // ---------------------------------------------------------------------------

  Widget _pill(
      BuildContext context,
      String text,
      Color color, {
        IconData? icon,
        bool onDark = false,
      }) {

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ? scheme.primaryContainer : Colors.white;

    final fg = onDark ? foregroundColor : color;
    final bg = onDark
        ? foregroundColor.withValues(alpha: 0.2)
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

  Widget _sectionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        Widget? trailing,
        required Widget child,
        bool padBody = true,
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
          Padding(
            padding: padBody
                ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
                : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
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
              ? context.tr('Sale Invoice')
              : context.tr('Sale Invoice #{0}', [invoice.id]),
        ),
        actions: [
          if (invoice != null &&
              invoice.customerId != null &&
              !invoice.isFullyPaid &&
              !_isPaying)
            IconButton(
              tooltip: context.tr('Record payment'),
              icon: const Icon(Icons.add_card_outlined),
              onPressed: _recordPayment,
            ),
          if (invoice != null)
            IconButton(
              tooltip: context.tr('Print'),
              icon: const Icon(Icons.print_outlined),
              onPressed: () => InvoicePrinter.printSaleInvoice(invoice),
            ),
        ],
      ),
      body: _buildBody(invoice),
    );
  }

  Widget _buildBody(Invoice? invoice) {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (invoice == null) {
      return EmptyState(title: context.tr('No sale invoice'));
    }

    return WideContent(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeroCard(invoice),
          const SizedBox(height: 14),
          _buildItemsCard(invoice),
          if (invoice.customerId != null) _buildCustomerPaymentCard(invoice),
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
                  context.tr('Sale Invoice #{0}', [invoice.id]),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill(
                context,
                invoice.isFullyPaid
                    ? context.tr('Paid')
                    : context.tr(
                  'Remaining: {0}',
                  [money(invoice.remainingAmount)],
                ),
                foregroundColor,
                icon: invoice.isFullyPaid
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_bottom_rounded,
                onDark: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Total Amount'),
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
              _metaChip(Icons.event_outlined, '${invoice.createdAt}'),
              _metaChip(Icons.storefront_outlined, invoice.locationName),
              _metaChip(
                Icons.badge_outlined,
                invoice.employeeName ?? context.tr('None'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Customer & payment
  // ---------------------------------------------------------------------------

  Widget _buildCustomerPaymentCard(Invoice invoice) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Each later payment carries its own method, so show the methods actually
    // used. Invoices made before payments were tracked fall back to the single
    // method stored on the invoice itself.
    final paymentMethods = <String>[];
    for (final payment in invoice.payments) {
      final label = paymentMethodLabel(context, payment.method);
      if (!paymentMethods.contains(label)) paymentMethods.add(label);
    }
    if (paymentMethods.isEmpty && invoice.paymentMethod != null) {
      paymentMethods.add(paymentMethodLabel(context, invoice.paymentMethod!));
    }
    final methodLabel = paymentMethods.isEmpty
        ? context.tr('None')
        : paymentMethods.join(' / ');

    return _sectionCard(
      context,
      icon: Icons.person_outline_rounded,
      title: context.tr('Customer & Payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTile(
            label: context.tr('Customer'),
            value: invoice.customerDisplayName ?? context.tr('None'),
          ),
          InfoTile(
            label: context.tr('Customer phone'),
            value: invoice.customerPhone ?? context.tr('None'),
          ),
          const Divider(height: 20),
          InfoTile(
            label: context.tr('Paid'),
            value: money(invoice.paidAmount),
          ),
          InfoTile(
            label: context.tr('Remaining'),
            value: money(invoice.remainingAmount),
          ),
          InfoTile(label: context.tr('Payment method'), value: methodLabel),
          const Divider(height: 20),
          InfoTile(
            label: context.tr('Customer total paid'),
            value: money(invoice.customerTotalPaid),
          ),
          InfoTile(
            label: context.tr('Customer outstanding'),
            value: money(invoice.customerTotalDebt),
          ),
          if (invoice.payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.tr('Payment history'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final payment in invoice.payments)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      paymentMethodIcon(payment.method),
                      size: 18,
                      color: _paidColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        paymentMethodLabel(context, payment.method),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      money(payment.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _paidColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!invoice.isFullyPaid && !_isPaying)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.add_card_outlined),
                  label: Text(context.tr('Record payment')),
                ),
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

  Widget _cell(
      Widget child, {
        Alignment alignment = Alignment.centerLeft,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(alignment: alignment, child: child),
    );
  }

  Widget _dash() {
    return Text(
      '-',
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    );
  }

  Widget _textOrDash(String? value) {
    if (value == null || value.trim().isEmpty) return _dash();
    return Text(value, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  TableRow _itemRow(int index, dynamic item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zebra = index.isOdd
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : Colors.transparent;

    final Widget discountCell;
    if (!item.hasDiscount) {
      discountCell = _dash();
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final Widget totalCell;
    if (!item.hasDiscount) {
      totalCell = Text(
        money(item.totalPrice),
        style: TextStyle(
          fontWeight: FontWeight.w800,
        ),
      );
    } else {
      totalCell = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            money(item.totalBeforeDiscount),
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
              color: scheme.outline,
            ),
          ),
          Text(
            money(item.totalPrice),
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        _cell(totalCell, alignment: Alignment.centerRight),
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
                1: FlexColumnWidth(3.2),
                2: FlexColumnWidth(1.8),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.4),
                5: FixedColumnWidth(72),
                6: FlexColumnWidth(1.7),
                7: FlexColumnWidth(1.9),
                8: FlexColumnWidth(1.8),
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
                    _headerCell(context.tr('Product')),
                    _headerCell(context.tr('Model')),
                    _headerCell(context.tr('Size')),
                    _headerCell(context.tr('Colour')),
                    _headerCell(
                      context.tr('Qty'),
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
                    _headerCell(
                      context.tr('Total'),
                      alignment: Alignment.centerRight,
                    ),
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

  Widget _buildItemsCard(Invoice invoice) {
    final scheme = Theme.of(context).colorScheme;

    return _sectionCard(
      context,
      icon: Icons.inventory_2_outlined,
      title: context.tr('Items'),
      subtitle: context.tr('Products sold on this invoice'),
      padBody: false,
      trailing: _pill(context, '${invoice.items.length}', scheme.primary),
      child: invoice.items.isEmpty
          ? Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: EmptyState(
          icon: Icons.assignment_return_outlined,
          title: context.tr('Fully returned'),
          message: context.tr(
            'Every item on this invoice was returned.',
          ),
        ),
      )
          : _buildItemsTable(invoice),
    );
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  Widget _buildTotalsCard(Invoice invoice) {
    final scheme = Theme.of(context).colorScheme;
    final itemDiscounts = _itemDiscountTotal(invoice);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InfoTile(
            label: context.tr('Subtotal'),
            value: money(_subtotal(invoice)),
          ),
          if (itemDiscounts > 0)
            InfoTile(
              label: context.tr('Item discounts'),
              value: moneyNegative(itemDiscounts),
              valueStyle: amountStyle(context, -itemDiscounts),
            ),
          if (invoice.discountAmount > 0)
            InfoTile(
              label: context.tr('Discount'),
              value: invoice.discountPercent == null
                  ? moneyNegative(invoice.discountAmount)
                  : '${moneyNegative(invoice.discountAmount)} '
                  '(${percentLabel(invoice.discountPercent!)})',
              valueStyle: amountStyle(context, -invoice.discountAmount),
            ),
          const Divider(height: 20),
          InfoTile(
            label: context.tr('Total Amount'),
            value: money(invoice.totalAmount),
          ),
        ],
      ),
    );
  }
}

class _PaymentEntry {
  const _PaymentEntry({required this.amount, required this.method});

  final double amount;
  final int method;
}