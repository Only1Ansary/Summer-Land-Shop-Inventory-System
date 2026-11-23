import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/invoice_printer.dart';
import '../../services/product_service.dart';
import '../../services/purchase_invoice_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/payment_method.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'show_purchase_invoice_screen.dart';
import '../../ui/text_input_helpers.dart';

/// Width from which the screen switches to the two-pane desktop layout.
const double _kWideBreakpoint = 900;

class CreatePurchaseInvoiceScreen extends StatefulWidget {
  const CreatePurchaseInvoiceScreen({super.key});

  @override
  State<CreatePurchaseInvoiceScreen> createState() =>
      _CreatePurchaseInvoiceScreenState();
}

class _CreatePurchaseInvoiceScreenState
    extends State<CreatePurchaseInvoiceScreen> {
  final ApiService _apiService = ApiService();

  late final CategoryService _categoryService;
  late final ProductService _productService;
  late final PurchaseInvoiceService _purchaseInvoiceService;
  late final SupplierService _supplierService;

  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _totalPaidController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _products = [];
  final List<_PurchaseItem> _items = [];
  final List<_PurchaseFee> _fees = [];

  /// Names of suppliers that already exist, used to offer matches while the
  /// supplier name is being typed.
  List<String> _supplierNames = [];

  /// Existing supplier names matching what has been typed so far.
  List<String> _supplierSuggestions = [];

  DateTime _date = DateTime.now();

  /// Cash is preselected, but the field is still validated so the method is
  /// always part of the created invoice.
  int? _paymentMethod = paymentMethodCash;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _itemsExpanded = true;

  /// Whether the compact bottom summary (phones) shows its breakdown.
  bool _summaryExpanded = false;

  @override
  void initState() {
    super.initState();

    _categoryService = CategoryService(_apiService);
    _productService = ProductService(_apiService);
    _purchaseInvoiceService = PurchaseInvoiceService(_apiService);
    _supplierService = SupplierService(_apiService);

    _loadData();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _totalPaidController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _categoryService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(friendlyErrorMessage(context, e));
      return;
    }

    await _loadProducts();
    await _loadSuppliers();
  }

  /// Loads the product catalogue used to offer matches while an item is being
  /// entered. This is a convenience only, so failures are ignored: the user can
  /// still type a brand new product.
  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
      });
    } catch (_) {
      // Ignore: matching existing products is optional.
    }
  }

  /// Loads existing supplier names used to offer matches while the supplier
  /// name is being typed. This is a convenience only, so failures are ignored:
  /// the user can still type a brand new supplier.
  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _supplierService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _supplierNames = suppliers
            .map((supplier) => supplier.supplierName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
      });
    } catch (_) {
      // Ignore: matching existing suppliers is optional.
    }
  }

  /// Recomputes the matching-supplier list as the name is typed. Matching is
  /// case-insensitive. An exact match is not suggested since there is nothing
  /// left to complete.
  void _onSupplierChanged(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _supplierSuggestions = [];
        return;
      }

      _supplierSuggestions = _supplierNames
          .where((name) {
        final lower = name.toLowerCase();
        return lower.contains(query) && lower != query;
      })
          .take(6)
          .toList();
    });
  }

  /// Fills the supplier field from a suggestion and hides the list.
  void _applySupplier(String name) {
    setState(() {
      _supplierNameController.text = name;
      _supplierNameController.selection = TextSelection.collapsed(
        offset: name.length,
      );
      _supplierSuggestions = [];
    });
  }

  /// True when the typed name exactly matches an existing supplier.
  bool get _isKnownSupplier {
    final typed = _supplierNameController.text.trim().toLowerCase();

    if (typed.isEmpty) return false;

    return _supplierNames.any((name) => name.toLowerCase() == typed);
  }

  double get _totalCost {
    return _items.fold(
      0,
          (total, item) => total + (item.purchasePrice * item.quantity),
    );
  }

  double get _discount {
    return double.tryParse(_discountController.text.trim()) ?? 0;
  }

  double get _totalAfterDiscount =>
      (_totalCost - _discount).clamp(0, double.infinity);

  double get _paidFeesTotal {
    return _fees
        .where((fee) => fee.isPaid)
        .fold(0, (total, fee) => total + fee.amount);
  }

  double get _unpaidFeesTotal {
    return _fees
        .where((fee) => !fee.isPaid)
        .fold(0, (total, fee) => total + fee.amount);
  }

  /// The goods after discount plus the fees that were already paid. Unpaid fees
  /// are not part of the cost: they show up as debt instead.
  double get _grandTotal => _totalAfterDiscount + _paidFeesTotal;

  /// What the supplier can be paid against: the goods only. Unpaid fees are
  /// settled through the debt balance, not the "total paid" field.
  double get _payableTotal => _totalAfterDiscount;

  double get _totalPaidValue {
    return double.tryParse(_totalPaidController.text.trim()) ?? 0;
  }

  /// What is still owed to the supplier: unpaid goods plus unpaid fees.
  double get _debt {
    final goodsDebt = (_payableTotal - _totalPaidValue).clamp(
      0,
      double.infinity,
    );

    return goodsDebt + _unpaidFeesTotal;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;

    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );
    });
  }

  Future<void> _addItem({_PurchaseItem? existing}) async {
    // Barcodes already in use, so an auto-assigned one never collides with an
    // existing product or another item on this invoice.
    final reservedBarcodes = <String>{
      ..._products
          .map((product) => product.barcode.trim())
          .where((barcode) => barcode.isNotEmpty),
      ..._items
          .map((item) => item.barcode.trim())
          .where((barcode) => barcode.isNotEmpty),
    };

    final item = await showDialog<_PurchaseItem>(
      context: context,
      builder: (context) =>
          _PurchaseItemDialog(
            categories: _categories,
            products: _products,
            reservedBarcodes: reservedBarcodes,
            item: existing,
          ),
    );

    if (!mounted) return;

    if (item == null) return;

    final modelDuplicate = _items.any(
          (existingItem) =>
      existingItem.modelNumber.trim().toLowerCase() ==
          item.modelNumber.trim().toLowerCase(),
    );

    if (!_isEditingReplace(existing) && modelDuplicate) {
      _showError(context.tr('A model number cannot appear more than once.'));
      return;
    }

    final barcodeDuplicate = _items.any(
          (existingItem) =>
      existingItem.barcode.trim().toLowerCase() ==
          item.barcode.trim().toLowerCase(),
    );

    if (!_isEditingReplace(existing) && barcodeDuplicate) {
      _showError(context.tr('A product barcode cannot appear more than once.'));
      return;
    }

    setState(() {
      if (existing == null) {
        _items.add(item);
        return;
      }

      final index = _items.indexWhere(
            (existingItem) => existingItem.id == existing.id,
      );

      if (index != -1) {
        _items[index] = item;
      }
    });
  }

  bool _isEditingReplace(_PurchaseItem? existing) {
    if (existing == null) return false;

    return _items.any((existingItem) => existingItem.id == existing.id);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _addFee({_PurchaseFee? existing}) async {
    final fee = await showDialog<_PurchaseFee>(
      context: context,
      builder: (context) => _PurchaseFeeDialog(fee: existing),
    );

    if (fee == null) return;

    setState(() {
      if (existing == null) {
        _fees.add(fee);
        return;
      }

      final index = _fees.indexWhere((f) => f.id == existing.id);

      if (index != -1) {
        _fees[index] = fee;
      }
    });
  }

  void _removeFee(int index) {
    setState(() {
      _fees.removeAt(index);
    });
  }

  Future<void> _createPurchaseInvoice() async {
    if (!ensureOnlineForWrite(context)) return;
    final supplierName = _supplierNameController.text.trim();

    if (supplierName.isEmpty) {
      _showError(context.tr('Supplier name is required.'));
      return;
    }

    if (_paymentMethod == null ||
        !paymentMethodValues.contains(_paymentMethod!)) {
      _showError(context.tr('Choose a payment method.'));
      return;
    }

    if (_items.isEmpty && _fees.isEmpty) {
      _showError(
        context.tr(
          'A purchase invoice needs at least one item or one extra fee.',
        ),
      );
      return;
    }

    final totalPaid = double.tryParse(_totalPaidController.text.trim());

    if (totalPaid == null || totalPaid < 0) {
      _showError(context.tr('Total paid must be a non-negative amount.'));
      return;
    }

    final discountText = _discountController.text.trim();
    final discount = discountText.isEmpty ? 0.0 : double.tryParse(discountText);

    if (discount == null || discount < 0) {
      _showError(context.tr('Discount must be a non-negative amount.'));
      return;
    }

    if (discount > _totalCost) {
      _showError(context.tr('Discount cannot exceed the total cost.'));
      return;
    }

    if (totalPaid > _payableTotal) {
      _showError(
        _items.isEmpty
            ? context.tr('Total paid cannot exceed the extra fees.')
            : context.tr(
          'Total paid cannot exceed the cost of the purchased items.',
        ),
      );
      return;
    }

    for (final fee in _fees) {
      if (fee.description
          .trim()
          .isEmpty) {
        _showError(context.tr('Every extra fee needs a description.'));
        return;
      }

      if (fee.amount <= 0) {
        _showError(
          context.tr('The amount for "{0}" must be greater than zero.', [
            fee.description.trim(),
          ]),
        );
        return;
      }
    }

    setState(() {
      _isCreating = true;
    });

    final items = _items.map((item) {
      return {
        'name': item.name,
        'modelNumber': item.modelNumber,
        'barcode': item.barcode,
        'purchasePrice': item.purchasePrice,
        'quantity': item.quantity,
        'categoryId': item.categoryId,
        'profitMargin': item.profitMargin,
      };
    }).toList();

    final fees = _fees
        .map(
          (fee) =>
      {
        'description': fee.description.trim(),
        'amount': fee.amount,
        'isPaid': fee.isPaid,
      },
    )
        .toList();

    final date = _date;

    PurchaseInvoice? createdInvoice;

    scheduleUndoable(
      context,
      message: context.tr(
        'Purchase invoice will be created. Tap Undo to cancel.',
      ),
      operation: () async {
        try {
          createdInvoice = await _purchaseInvoiceService.createPurchaseInvoice(
            supplierName: supplierName,
            date: date,
            totalPaid: totalPaid,
            paymentMethod: _paymentMethod!,
            discount: discount,
            items: items,
            fees: fees,
          );
        } finally {
          if (mounted) {
            setState(() {
              _isCreating = false;
            });
          }
        }
      },
      onCommitted: () async {
        if (!mounted) return;

        setState(() {
          _items.clear();
          _fees.clear();
          _totalPaidController.clear();
          _discountController.clear();
          _paymentMethod = paymentMethodCash;
        });

        final invoice = createdInvoice;

        if (invoice == null) return;

        if (ModalRoute
            .of(context)
            ?.isCurrent == true) {
          final shouldPrint = await showDialog<bool>(
            context: context,
            builder: (ctx) =>
                AlertDialog(
                  title: Text(ctx.tr('Print invoice?')),
                  content: Text(
                    ctx.tr('Purchase invoice #{0} created.', [invoice.id]),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(ctx.tr('Cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(ctx.tr('Print')),
                    ),
                  ],
                ),
          );

          if (shouldPrint == true) {
            await InvoicePrinter.printPurchaseInvoice(invoice);
          }

          if (!mounted) return;

          await pushScreen(
            context,
                (_) =>
                ShowPurchaseInvoiceScreen(
                  invoice: invoice,
                  invoiceId: invoice.id,
                ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Purchase invoice #{0} created.', [invoice.id]),
              ),
            ),
          );
        }
      },
      onUndone: () {
        if (mounted) {
          setState(() {
            _isCreating = false;
          });
        }
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  // ---------------------------------------------------------------------------
  // Supplier section
  // ---------------------------------------------------------------------------

  /// The list of existing suppliers offered under the supplier name field.
  Widget _buildSupplierSuggestions() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              context.tr('Matching suppliers'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final name in _supplierSuggestions)
            InkWell(
              onTap: () => _applySupplier(name),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _supplierStatusIcon() {
    final theme = Theme.of(context);

    if (_supplierNameController.text
        .trim()
        .isEmpty) return null;

    if (_isKnownSupplier) {
      return Tooltip(
        message: context.tr('Existing supplier'),
        child: Icon(Icons.check_circle, color: theme.colorScheme.primary),
      );
    }

    if (_supplierNames.isEmpty) return null;

    return Tooltip(
      message: context.tr('New supplier'),
      child: Icon(
        Icons.add_circle_outline,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSupplierSection() {
    final theme = Theme.of(context);

    final totalPaidField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _totalPaidController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: context.tr('Total Paid'),
        prefixText: '\u20a6 ',
      ),
      onChanged: (_) => setState(() {}),
    );

    final discountField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _discountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: context.tr('Discount'),
        prefixText: '\u20a6 ',
        helperText: context.tr('Subtracted from the total cost.'),
      ),
      onChanged: (_) => setState(() {}),
    );

    final paymentMethodField = DropdownButtonFormField<int>(
      key: const ValueKey('purchase-payment-method'),
      initialValue: _paymentMethod,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr('Payment method'),
        prefixIcon: const Icon(Icons.credit_card_outlined),
      ),
      items: paymentMethodValues.map((method) {
        return DropdownMenuItem<int>(
          value: method,
          child: Row(
            children: [
              Icon(paymentMethodIcon(method), size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  paymentMethodLabel(context, method),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: _isCreating
          ? null
          : (value) {
        if (value == null) return;
        setState(() {
          _paymentMethod = value;
        });
      },
    );

    return _SectionCard(
      icon: Icons.factory_outlined,
      title: context.tr('1. Supplier'),
      subtitle: context.tr('Who you are purchasing from'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: textFieldAutofocus(false),
            controller: _supplierNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: _onSupplierChanged,
            decoration: InputDecoration(
              labelText: context.tr('Supplier Name'),
              prefixIcon: const Icon(Icons.factory_outlined),
              suffixIcon: _supplierStatusIcon(),
              helperText: context.tr(
                'New supplier names are registered automatically.',
              ),
            ),
          ),
          if (_supplierSuggestions.isNotEmpty) _buildSupplierSuggestions(),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('Date'),
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(_formatDate(_date)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('Payment'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 440) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: totalPaidField),
                    const SizedBox(width: 12),
                    Expanded(child: discountField),
                  ],
                );
              }

              return Column(
                children: [
                  totalPaidField,
                  const SizedBox(height: 12),
                  discountField,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          paymentMethodField,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items section
  // ---------------------------------------------------------------------------

  Widget _buildItemTile(int index, _PurchaseItem item) {
    final theme = Theme.of(context);
    final lineTotal = item.purchasePrice * item.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _addItem(existing: item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(
                icon: Icons.inventory_2_outlined,
                background: theme.colorScheme.primaryContainer,
                foreground: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        AppPill(text: item.modelNumber),
                        if (item.barcode.isNotEmpty)
                          AppPill(text: item.barcode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(lineTotal),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} \u00d7 ${money(item.purchasePrice)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _addItem(existing: item);
                  } else {
                    _removeItem(index);
                  }
                },
                itemBuilder: (context) =>
                [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(context.tr('Edit')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('Remove'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final theme = Theme.of(context);

    return _SectionCard(
      icon: Icons.shopping_cart_outlined,
      title: context.tr('2. Items'),
      subtitle: context.tr('Products being purchased'),
      onHeaderTap: () {
        setState(() {
          _itemsExpanded = !_itemsExpanded;
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: '${_items.length}',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: _itemsExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Icon(
              Icons.expand_more_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _itemsExpanded
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isEmpty)
              EmptyState(
                icon: Icons.production_quantity_limits_outlined,
                title: context.tr('No items yet'),
                message: _fees.isEmpty
                    ? context.tr(
                  'Add at least one product, or an extra fee below.',
                )
                    : context.tr(
                  'No products on this invoice. It has extra fees only.',
                ),
              )
            else
              ..._items
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildItemTile(entry.key, entry.value),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _addItem(),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add Item')),
              ),
            ),
          ],
        )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fees section
  // ---------------------------------------------------------------------------

  Widget _buildFeeTile(int index, _PurchaseFee fee) {
    final theme = Theme.of(context);

    final accent = fee.isPaid
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _addFee(existing: fee),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(
                icon: fee.isPaid
                    ? Icons.check_circle_outline
                    : Icons.local_shipping_outlined,
                background: fee.isPaid
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                foreground: fee.isPaid
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    _InfoChip(
                      icon: fee.isPaid
                          ? Icons.check_rounded
                          : Icons.schedule_rounded,
                      label: fee.isPaid
                          ? context.tr('Paid (total cost)')
                          : context.tr('Unpaid (debt)'),
                      color: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money(fee.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _addFee(existing: fee);
                  } else {
                    _removeFee(index);
                  }
                },
                itemBuilder: (context) =>
                [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(context.tr('Edit')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('Remove'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeesSection() {
    final theme = Theme.of(context);

    return _SectionCard(
      icon: Icons.local_shipping_outlined,
      title: context.tr('3. Extra Fees'),
      subtitle: context.tr(
        'Shipping, customs, handling and other charges. Mark a fee '
            'as paid to add it to the total cost, or leave it unpaid to '
            'add it to the supplier debt.',
      ),
      trailing: StatusBadge(
        label: '${_fees.length}',
        color: theme.colorScheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_fees.isEmpty)
            EmptyState(
              icon: Icons.local_shipping_outlined,
              title: context.tr('No extra fees'),
              message: context.tr(
                'Add shipping or other charges if they apply to this purchase.',
              ),
            )
          else
            ..._fees
                .asMap()
                .entries
                .map(
                  (entry) => _buildFeeTile(entry.key, entry.value),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _addFee(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add Fee')),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary (bottom bar on phones, side panel on desktop)
  // ---------------------------------------------------------------------------

  /// The line-by-line breakdown shown in both summary layouts.
  List<Widget> _buildBreakdownRows() {
    final theme = Theme.of(context);
    final discount = _discount;
    final paidFees = _paidFeesTotal;
    final unpaidFees = _unpaidFeesTotal;
    final totalPaid = _totalPaidValue;

    return [
      _SummaryRow(
        label: context.tr('Items: {0}', [_items.length]),
        value: money(_totalCost),
      ),
      if (discount > 0)
        _SummaryRow(
          label: context.tr('Discount'),
          value: money(discount),
          valueColor: amountColor(context, discount),
        ),
      if (paidFees > 0)
        _SummaryRow(
          label: context.tr('Fees paid: {0}', [
            _fees
                .where((f) => f.isPaid)
                .length,
          ]),
          value: '${money(paidFees)}',
        ),
      if (unpaidFees > 0)
        _SummaryRow(
          label: context.tr('Fees unpaid: {0}', [
            _fees
                .where((f) => !f.isPaid)
                .length,
          ]),
          value: context.tr('+{0} (debt)', [money(unpaidFees)]),
          valueColor: amountColor(context, unpaidFees),
        ),
      if (totalPaid > 0)
        _SummaryRow(
          label: context.tr('Total Paid'),
          value: money(totalPaid),
          valueColor: theme.colorScheme.onSurface,
        ),
    ];
  }

  Widget _buildDebtBox() {
    final theme = Theme.of(context);
    final debt = _debt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('Remaining Debt'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              moneyNegative(debt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _isCreating ? null : _createPurchaseInvoice,
        icon: _isCreating
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.shopping_bag_outlined),
        label: Text(context.tr('Create Purchase Invoice')),
      ),
    );
  }

  /// Compact, collapsible summary pinned to the bottom on narrow screens.
  Widget _buildTotalsBar() {
    final theme = Theme.of(context);
    final debt = _debt;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _summaryExpanded = !_summaryExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Total Cost'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                money(_grandTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (debt > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  context.tr('Remaining Debt'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                Text(
                                  moneyNegative(debt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _summaryExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_less_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _summaryExpanded
                    ? Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Column(children: _buildBreakdownRows()),
                )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 8),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Always-visible summary panel used next to the form on wide screens.
  Widget _buildSummaryPanel() {
    final theme = Theme.of(context);
    final debt = _debt;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LeadingIcon(
                  icon: Icons.receipt_long_outlined,
                  background: theme.colorScheme.primaryContainer,
                  foreground: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Summary'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildBreakdownRows(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Total Cost'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      money(_grandTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (debt > 0) ...[const SizedBox(height: 12), _buildDebtBox()],
            const SizedBox(height: 20),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('New Purchase'),
      destinationId: 'add-purchase',
      body: _isLoading
          ? const LoadingState()
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kWideBreakpoint) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          24,
                          12,
                          24,
                        ),
                        children: [
                          _buildSupplierSection(),
                          const SizedBox(height: 16),
                          _buildItemsSection(),
                          const SizedBox(height: 16),
                          _buildFeesSection(),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          24,
                          24,
                          24,
                        ),
                        children: [_buildSummaryPanel()],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSupplierSection(),
                    const SizedBox(height: 16),
                    _buildItemsSection(),
                    const SizedBox(height: 16),
                    _buildFeesSection(),
                  ],
                ),
              ),
              if (_items.isNotEmpty || _fees.isNotEmpty)
                _buildTotalsBar(),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small reusable widgets
// -----------------------------------------------------------------------------

/// A bordered card with an icon header, used for each step of the form.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.onHeaderTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeadingIcon(
          icon: icon,
          background: theme.colorScheme.primaryContainer,
          foreground: theme.colorScheme.onPrimaryContainer,
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          onHeaderTap == null
              ? Padding(padding: const EdgeInsets.all(16), child: header)
              : InkWell(
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: header,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A rounded square holding an icon, used as the leading visual of cards/rows.
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: foreground),
    );
  }
}

/// A small tinted status chip with an icon and a label.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One label/value line of the summary breakdown.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small coloured heading used to group fields inside dialogs.
class _FormGroupLabel extends StatelessWidget {
  const _FormGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The title row used by both dialogs: a tinted icon followed by the title.
class _DialogTitle extends StatelessWidget {
  const _DialogTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _LeadingIcon(
          icon: icon,
          background: theme.colorScheme.primaryContainer,
          foreground: theme.colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Data holders
// -----------------------------------------------------------------------------

class _PurchaseItem {
  final int id;
  final String name;
  final String modelNumber;
  final String barcode;
  final double purchasePrice;
  final int quantity;
  final int categoryId;
  final double profitMargin;

  _PurchaseItem({
    required this.id,
    required this.name,
    required this.modelNumber,
    required this.barcode,
    required this.purchasePrice,
    required this.quantity,
    required this.categoryId,
    required this.profitMargin,
  });
}

class _PurchaseFee {
  final int id;
  final String description;
  final double amount;
  final bool isPaid;

  _PurchaseFee({
    required this.id,
    required this.description,
    required this.amount,
    this.isPaid = false,
  });
}

// -----------------------------------------------------------------------------
// Fee dialog
// -----------------------------------------------------------------------------

class _PurchaseFeeDialog extends StatefulWidget {
  const _PurchaseFeeDialog({this.fee});

  final _PurchaseFee? fee;

  @override
  State<_PurchaseFeeDialog> createState() => _PurchaseFeeDialogState();
}

class _PurchaseFeeDialogState extends State<_PurchaseFeeDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;

  bool _isPaid = false;

  @override
  void initState() {
    super.initState();

    final fee = widget.fee;

    _descriptionController = TextEditingController(
      text: fee?.description ?? '',
    );
    _amountController = TextEditingController(
      text: fee == null ? '' : fee.amount.toStringAsFixed(2),
    );
    _isPaid = fee?.isPaid ?? false;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _add() {
    final navigator = Navigator.of(context);

    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      _showError(context.tr('Describe what the fee is for.'));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError(context.tr('The fee amount must be greater than zero.'));
      return;
    }

    navigator.pop(
      _PurchaseFee(
        id: widget.fee?.id ?? DateTime
            .now()
            .microsecondsSinceEpoch,
        description: description,
        amount: amount,
        isPaid: _isPaid,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _useSuggestion(String text) {
    setState(() {
      _descriptionController.text = text;
      _descriptionController.selection = TextSelection.collapsed(
        offset: text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final suggestions = [
      context.tr('Shipping'),
      context.tr('Customs'),
      context.tr('Handling'),
    ];

    return AlertDialog(
      scrollable: true,
      title: _DialogTitle(
        icon: Icons.local_shipping_outlined,
        title: widget.fee == null
            ? context.tr('Add Fee')
            : context.tr('Edit Fee'),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TextField(
              autofocus: textFieldAutofocus(false),
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr('Description'),
                hintText: context.tr('Shipping, customs, handling...'),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _useSuggestion(suggestion),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: textFieldAutofocus(false),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Amount'),
                prefixText: '\u20a6 ',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      context.tr('Unpaid (debt)'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      context.tr('Already paid'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {_isPaid},
                onSelectionChanged: (selection) {
                  setState(() => _isPaid = selection.first);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPaid
                        ? context.tr('Added to the total cost.')
                        : context.tr('Added to the supplier debt.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: _add,
          child: Text(
            widget.fee == null ? context.tr('Add') : context.tr('Save'),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Item dialog
// -----------------------------------------------------------------------------

class _PurchaseItemDialog extends StatefulWidget {
  const _PurchaseItemDialog({
    required this.categories,
    required this.products,
    required this.reservedBarcodes,
    this.item,
  });

  final List<Category> categories;
  final List<Product> products;

  /// Barcodes already taken by existing products or other items on the
  /// invoice. Used to keep an auto-assigned barcode unique.
  final Set<String> reservedBarcodes;

  final _PurchaseItem? item;

  @override
  State<_PurchaseItemDialog> createState() => _PurchaseItemDialogState();
}

class _PurchaseItemDialogState extends State<_PurchaseItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _marginController;

  int? _selectedCategoryId;

  /// The existing product the user picked from the suggestions, if any. While
  /// this is null the item is a new product and gets a generated barcode.
  Product? _selectedProduct;

  /// Existing products whose name, model number, or barcode match what has
  /// been typed so far. Empty once a suggestion is picked or nothing matches.
  List<Product> _suggestions = [];

  /// A brand new product (or one whose name was edited after a suggestion was
  /// picked) has its barcode assigned by the system rather than typed.
  bool get _autoAssignBarcode =>
      widget.item == null && _selectedProduct == null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _nameController = TextEditingController(text: item?.name ?? '');
    _modelController = TextEditingController(text: item?.modelNumber ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _priceController = TextEditingController(
      text: item == null ? '' : item.purchasePrice.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: item == null ? '1' : '${item.quantity}',
    );
    _marginController = TextEditingController(
      text: item?.profitMargin.toStringAsFixed(2) ?? '',
    );
    _selectedCategoryId = item?.categoryId;

    if (item == null) {
      _barcodeController.text = _generateBarcode();
    }
  }

  /// Builds a unique numeric internal barcode. The leading zeros are part of
  /// the code, so the value stays digits-only and scannable.
  String _generateBarcode() {
    var number = DateTime
        .now()
        .microsecondsSinceEpoch % 100000000;

    while (true) {
      final candidate = number.toString().padLeft(8, '0');

      if (!widget.reservedBarcodes.contains(candidate)) return candidate;

      number = (number + 1) % 100000000;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  /// Recomputes the matching-product list as the name is typed. Matching is
  /// case-insensitive and checks the name, model number, and barcode.
  void _onNameChanged(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      // Typing over a picked product makes it a new product again, so the
      // barcode goes back to being system-assigned.
      if (widget.item == null && _selectedProduct != null) {
        _selectedProduct = null;
        _barcodeController.text = _generateBarcode();
      }

      if (query.isEmpty) {
        _suggestions = [];
        return;
      }

      _suggestions = widget.products
          .where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.modelNumber.toLowerCase().contains(query) ||
            product.barcode.toLowerCase().contains(query);
      })
          .take(6)
          .toList();
    });
  }

  /// Fills the form from an existing product and hides the suggestion list.
  void _applyProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _nameController.text = product.name;
      _modelController.text = product.modelNumber;
      _barcodeController.text = product.barcode;
      _priceController.text = product.purchasePrice.toStringAsFixed(2);
      _marginController.text = product.profitMargin.toStringAsFixed(2);

      final hasCategory = widget.categories.any(
            (category) => category.id == product.categoryId,
      );
      _selectedCategoryId = hasCategory ? product.categoryId : null;

      _suggestions = [];
    });
  }

  void _add() {
    final navigator = Navigator.of(context);

    final name = _nameController.text.trim();
    final modelNumber = _modelController.text.trim();
    final barcode = _barcodeController.text.trim();

    if (name.isEmpty || modelNumber.isEmpty || barcode.isEmpty) {
      _showError(
        context.tr('Every item must have a name, model number, and barcode.'),
      );
      return;
    }

    final purchasePrice = double.tryParse(_priceController.text.trim());

    if (purchasePrice == null || purchasePrice < 0) {
      _showError(context.tr('Purchase price must be a non-negative amount.'));
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      _showError(context.tr('Quantity must be greater than zero.'));
      return;
    }

    final profitMargin = double.tryParse(_marginController.text.trim());

    if (profitMargin == null || profitMargin < 0) {
      _showError(context.tr('Profit margin must be a non-negative amount.'));
      return;
    }

    final categoryId = _selectedCategoryId;

    if (categoryId == null || categoryId <= 0) {
      _showError(context.tr('Please choose a category.'));
      return;
    }

    navigator.pop(
      _PurchaseItem(
        id: widget.item?.id ?? DateTime
            .now()
            .microsecondsSinceEpoch,
        name: name,
        modelNumber: modelNumber,
        barcode: barcode,
        purchasePrice: purchasePrice,
        quantity: quantity,
        categoryId: categoryId,
        profitMargin: profitMargin,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// The list of existing products offered under the name field.
  Widget _buildSuggestions() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              context.tr('Matching products'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final product in _suggestions) _buildSuggestionTile(product),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(Product product) {
    final theme = Theme.of(context);

    final subtitle = [
      if (product.modelNumber
          .trim()
          .isNotEmpty) product.modelNumber.trim(),
      if (product.barcode
          .trim()
          .isNotEmpty) product.barcode.trim(),
    ].join('  •  ');

    return InkWell(
      onTap: () => _applyProduct(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(product.purchasePrice),
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the product being entered is new or an existing one picked from
  /// the suggestions. Not shown when editing an item already on the invoice.
  Widget _buildProductStatus() {
    final theme = Theme.of(context);

    if (widget.item != null) return const SizedBox.shrink();

    final existing = _selectedProduct != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _InfoChip(
          icon: existing ? Icons.link_rounded : Icons.fiber_new_rounded,
          label: existing
              ? context.tr('Existing product')
              : context.tr('New product'),
          color: existing
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildBarcodeField({required bool singleColumn}) {
    if (_autoAssignBarcode) {
      return TextField(
        autofocus: textFieldAutofocus(false),
        controller: _barcodeController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: context.tr('Barcode'),
          prefixIcon: const Icon(Icons.qr_code_2),
          suffixIcon: const Icon(Icons.auto_awesome),
          helperText: singleColumn
              ? context.tr(
            'The internal barcode will be generated automatically.',
          )
              : null,
          helperMaxLines: 2,
        ),
      );
    }

    return TextField(
      autofocus: textFieldAutofocus(false),
      controller: _barcodeController,
      decoration: InputDecoration(
        labelText: context.tr('Barcode'),
        prefixIcon: const Icon(Icons.qr_code_2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screenWidth = MediaQuery
        .sizeOf(context)
        .width;
    final contentWidth = (screenWidth - 128).clamp(0.0, 520.0);
    final wide = contentWidth >= 420;

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final lineTotal = price * quantity;

    final modelField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _modelController,
      decoration: InputDecoration(
        labelText: context.tr('Model Number'),
        prefixIcon: const Icon(Icons.tag),
      ),
    );

    final priceField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _priceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: context.tr('Purchase Price'),
        prefixText: '\u20a6 ',
      ),
    );

    final quantityField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _quantityController,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: context.tr('Quantity')),
    );

    final marginField = TextField(
      autofocus: textFieldAutofocus(false),
      controller: _marginController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: context.tr('Profit Margin')),
    );

    return AlertDialog(
        scrollable: true,
        title: _DialogTitle(
          icon: Icons.inventory_2_outlined,
          title: widget.item == null
              ? context.tr('Add Item')
              : context.tr('Edit Item'),
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _FormGroupLabel(context.tr('Product')),
              const SizedBox(height: 12),
              TextField(
                autofocus: textFieldAutofocus(false),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                onChanged: _onNameChanged,
                decoration: InputDecoration(
                  labelText: context.tr('Product Name'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              if (_suggestions.isNotEmpty) _buildSuggestions(),
              _buildProductStatus(),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: modelField),
                    const SizedBox(width: 12),
                    Expanded(child: _buildBarcodeField(singleColumn: false)),
                  ],
                )
              else
                ...[
                  modelField,
                  const SizedBox(height: 12),
                  _buildBarcodeField(singleColumn: true),
                ],
              if (wide && _autoAssignBarcode)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    context.tr(
                      'The internal barcode will be generated automatically.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('category-$_selectedCategoryId'),
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('Category'),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _FormGroupLabel(context.tr('Pricing')),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: priceField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: quantityField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: marginField),
                  ],
                )
              else
                ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: priceField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: quantityField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  marginField,
                ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('Line total'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          money(lineTotal),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: _add,
              child: Text(
                widget.item == null ? context.tr('Add') : context.tr('Save'),
              ),
            ),
          ],
        );
    }
}
