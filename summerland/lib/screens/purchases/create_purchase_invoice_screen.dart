import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../services/purchase_invoice_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_theme.dart';
import '../../ui/app_widgets.dart';
import 'show_purchase_invoice_screen.dart';

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
  late final PurchaseInvoiceService _purchaseInvoiceService;

  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _totalPaidController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  List<Category> _categories = [];
  final List<_PurchaseItem> _items = [];
  final List<_PurchaseFee> _fees = [];

  DateTime _date = DateTime.now();

  bool _isLoading = true;
  bool _isCreating = false;
  bool _itemsExpanded = true;

  @override
  void initState() {
    super.initState();

    _categoryService = CategoryService(_apiService);
    _purchaseInvoiceService = PurchaseInvoiceService(_apiService);

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
    }
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
    final item = await showDialog<_PurchaseItem>(
      context: context,
      builder: (context) =>
          _PurchaseItemDialog(categories: _categories, item: existing),
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
      if (fee.description.trim().isEmpty) {
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

    try {
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
            (fee) => {
              'description': fee.description.trim(),
              'amount': fee.amount,
              'isPaid': fee.isPaid,
            },
          )
          .toList();

      final invoice = await _purchaseInvoiceService.createPurchaseInvoice(
        supplierName: supplierName,
        date: _date,
        totalPaid: totalPaid,
        discount: discount,
        items: items,
        fees: fees,
      );

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      await pushScreen(
        context,
        (_) =>
            ShowPurchaseInvoiceScreen(invoice: invoice, invoiceId: invoice.id),
      );

      if (!mounted) return;

      setState(() {
        _items.clear();
        _fees.clear();
        _totalPaidController.clear();
        _discountController.clear();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      _showError(friendlyErrorMessage(context, e));
    }
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

  Widget _buildSupplierSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.tr('1. Supplier'),
              subtitle: context.tr('Who you are purchasing from'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supplierNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.tr('Supplier Name'),
                prefixIcon: const Icon(Icons.factory_outlined),
                helperText: context.tr(
                  'New supplier names are registered automatically.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_formatDate(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _totalPaidController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Total Paid'),
                      prefixText: '\u20a6 ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Discount'),
                prefixText: '\u20a6 ',
                helperText: context.tr('Subtracted from the total cost.'),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _itemsExpanded = !_itemsExpanded;
                });
              },
              child: SectionHeader(
                title: context.tr('2. Items'),
                subtitle: context.tr('Products being purchased'),
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
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _itemsExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _addItem(),
                            icon: const Icon(Icons.add),
                            label: Text(context.tr('Add Item')),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.production_quantity_limits_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(item.name),
                                subtitle: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${item.modelNumber} • '
                                            '${item.barcode}\n'
                                            '${context.tr('Qty: ')}',
                                      ),
                                      TextSpan(text: '${item.quantity}'),
                                      const TextSpan(text: ' × '),
                                      TextSpan(
                                        text: money(item.purchasePrice),
                                        style: TextStyle(
                                          color: amountColor(
                                            context,
                                            item.purchasePrice,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: context.tr('Edit'),
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _addItem(existing: item),
                                    ),
                                    IconButton(
                                      tooltip: context.tr('Remove'),
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _removeItem(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.tr('3. Extra Fees'),
              subtitle: context.tr(
                'Shipping, customs, handling and other charges. Mark a fee '
                'as paid to add it to the total cost, or leave it unpaid to '
                'add it to the supplier debt.',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addFee(),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add Fee')),
              ),
            ),
            const SizedBox(height: 12),
            if (_fees.isEmpty)
              EmptyState(
                icon: Icons.local_shipping_outlined,
                title: context.tr('No extra fees'),
                message: context.tr(
                  'Add shipping or other charges if they apply to this purchase.',
                ),
              )
            else
              ..._fees.asMap().entries.map((entry) {
                final index = entry.key;
                final fee = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      fee.isPaid
                          ? Icons.check_circle_outline
                          : Icons.local_shipping_outlined,
                      color: fee.isPaid
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(fee.description),
                    subtitle: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: money(fee.amount),
                            style: TextStyle(
                              color: amountColor(context, fee.amount),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: fee.isPaid
                                ? context.tr('  •  paid (total cost)')
                                : context.tr('  •  unpaid (debt)'),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.tr('Edit'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addFee(existing: fee),
                        ),
                        IconButton(
                          tooltip: context.tr('Remove'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeFee(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsBar() {
    final theme = Theme.of(context);
    final totalCost = _totalCost;
    final discount = _discount;
    final payable = _payableTotal;
    final paidFees = _paidFeesTotal;
    final unpaidFees = _unpaidFeesTotal;
    final totalPaidText = _totalPaidController.text.trim();
    final totalPaid = double.tryParse(totalPaidText) ?? 0;

    final goodsDebt = (payable - totalPaid).clamp(0, double.infinity);
    final debt = goodsDebt + unpaidFees;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                context.tr('Items: {0}', [_items.length]),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                context.tr('Total (items): {0}', [money(totalCost)]),
                style: TextStyle(color: amountColor(context, totalCost)),
              ),
            ],
          ),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    context.tr('Discount: {0}', [moneyNegative(discount)]),
                    style: TextStyle(color: amountColor(context, -discount)),
                  ),
                ],
              ),
            ),
          if (paidFees > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    context.tr('Fees paid: {0}', [
                      _fees.where((f) => f.isPaid).length,
                    ]),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '+${money(paidFees)}',
                    style: TextStyle(color: amountColor(context, paidFees)),
                  ),
                ],
              ),
            ),
          if (unpaidFees > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    context.tr('Fees unpaid: {0}', [
                      _fees.where((f) => !f.isPaid).length,
                    ]),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    context.tr('+{0} (debt)', [money(unpaidFees)]),
                    style: TextStyle(color: amountColor(context, unpaidFees)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  context.tr('Total Cost: {0}', [money(_grandTotal)]),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: amountColor(context, _grandTotal),
                  ),
                ),
              ],
            ),
          ),
          if (debt > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    context.tr('Remaining Debt: {0}', [moneyNegative(debt)]),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: amountColor(context, -debt),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
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
          ),
        ],
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
          : Column(
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
                if (_items.isNotEmpty || _fees.isNotEmpty) _buildTotalsBar(),
              ],
            ),
    );
  }
}

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
        id: widget.fee?.id ?? DateTime.now().microsecondsSinceEpoch,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.fee == null ? context.tr('Add Fee') : context.tr('Edit Fee'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.tr('Description'),
              hintText: context.tr('Shipping, customs, handling...'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              prefixText: '₦ ',
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            value: _isPaid,
            onChanged: (value) {
              setState(() {
                _isPaid = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.tr('Already paid')),
            subtitle: Text(
              _isPaid
                  ? context.tr('Added to the total cost.')
                  : context.tr('Added to the supplier debt.'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
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

class _PurchaseItemDialog extends StatefulWidget {
  const _PurchaseItemDialog({required this.categories, this.item});

  final List<Category> categories;
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
        id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.item == null ? context.tr('Add Item') : context.tr('Edit Item'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.tr('Product Name'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: context.tr('Model Number'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(labelText: context.tr('Barcode')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('category-$_selectedCategoryId'),
              initialValue: _selectedCategoryId,
              decoration: InputDecoration(labelText: context.tr('Category')),
              items: widget.categories.map((category) {
                return DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Purchase Price'),
                      prefixText: '\u20a6 ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Quantity'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marginController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Profit Margin'),
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
