import 'package:flutter/material.dart';

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

      _showError(friendlyError(e));
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

  double get _feesTotal {
    return _fees.fold(0, (total, fee) => total + fee.amount);
  }

  /// Goods after discount. Extra fees are excluded: they are a real cost but
  /// are never owed to the supplier.
  double get _payableTotal => _totalAfterDiscount;

  double get _grandTotal => _payableTotal + _feesTotal;

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

    if (item == null) return;

    final modelDuplicate = _items.any(
      (existingItem) =>
          existingItem.modelNumber.trim().toLowerCase() ==
          item.modelNumber.trim().toLowerCase(),
    );

    if (!_isEditingReplace(existing) && modelDuplicate) {
      _showError('A model number cannot appear more than once.');
      return;
    }

    final barcodeDuplicate = _items.any(
      (existingItem) =>
          existingItem.barcode.trim().toLowerCase() ==
          item.barcode.trim().toLowerCase(),
    );

    if (!_isEditingReplace(existing) && barcodeDuplicate) {
      _showError('A product barcode cannot appear more than once.');
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
    final supplierName = _supplierNameController.text.trim();

    if (supplierName.isEmpty) {
      _showError('Supplier name is required.');
      return;
    }

    if (_items.isEmpty) {
      _showError('Purchase invoice must contain at least one item.');
      return;
    }

    final totalPaid = double.tryParse(_totalPaidController.text.trim());

    if (totalPaid == null || totalPaid < 0) {
      _showError('Total paid must be a non-negative amount.');
      return;
    }

    final discountText = _discountController.text.trim();
    final discount = discountText.isEmpty ? 0.0 : double.tryParse(discountText);

    if (discount == null || discount < 0) {
      _showError('Discount must be a non-negative amount.');
      return;
    }

    if (discount > _totalCost) {
      _showError('Discount cannot exceed the total cost.');
      return;
    }

    if (totalPaid > _payableTotal) {
      _showError('Total paid cannot exceed the cost of the purchased items.');
      return;
    }

    for (final fee in _fees) {
      if (fee.description.trim().isEmpty) {
        _showError('Every extra fee needs a description.');
        return;
      }

      if (fee.amount <= 0) {
        _showError(
          'The amount for "${fee.description.trim()}" must be greater than zero.',
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

      _showError(friendlyError(e));
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
            const SectionHeader(
              title: '1. Supplier',
              subtitle: 'Who you are purchasing from',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supplierNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Supplier Name',
                prefixIcon: Icon(Icons.factory_outlined),
                helperText: 'New supplier names are registered automatically.',
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
                    decoration: const InputDecoration(
                      labelText: 'Total Paid',
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
              decoration: const InputDecoration(
                labelText: 'Discount',
                prefixText: '\u20a6 ',
                helperText: 'Subtracted from the total cost.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: '2. Items',
              subtitle: 'Products being purchased',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addItem(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const EmptyState(
                icon: Icons.production_quantity_limits_outlined,
                title: 'No items yet',
                message: 'Add at least one product to create the invoice.',
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
                                '${item.modelNumber} • ${item.barcode}\n'
                                'Qty: ',
                          ),
                          TextSpan(text: '${item.quantity}'),
                          const TextSpan(text: ' × '),
                          TextSpan(
                            text: money(item.purchasePrice),
                            style: TextStyle(
                              color: amountColor(context, item.purchasePrice),
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
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addItem(existing: item),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeItem(index),
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

  Widget _buildFeesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: '3. Extra Fees',
              subtitle: 'Shipping, customs, handling and other charges. Added to the total cost but not owed to the supplier.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addFee(),
                icon: const Icon(Icons.add),
                label: const Text('Add Fee'),
              ),
            ),
            const SizedBox(height: 12),
            if (_fees.isEmpty)
              const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No extra fees',
                message: 'Add shipping or other charges if they apply to this purchase.',
              )
            else
              ..._fees.asMap().entries.map((entry) {
                final index = entry.key;
                final fee = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.local_shipping_outlined,
                      color: Theme.of(context).colorScheme.primary,
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
                          const TextSpan(text: '  •  not payable to supplier'),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addFee(existing: fee),
                        ),
                        IconButton(
                          tooltip: 'Remove',
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
    final fees = _feesTotal;
    final totalPaidText = _totalPaidController.text.trim();
    final totalPaid = double.tryParse(totalPaidText) ?? 0;

    final debt = (payable - totalPaid).clamp(0, double.infinity);

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
                'Items: ${_items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Total (items): ${money(totalCost)}',
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
                    'Discount: ${moneyNegative(discount)}',
                    style: TextStyle(color: amountColor(context, -discount)),
                  ),
                ],
              ),
            ),
          if (fees > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    'Extra Fees: ${_fees.length}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '+${money(fees)}',
                    style: TextStyle(color: amountColor(context, fees)),
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
                  'Total Cost: ${money(_grandTotal)}',
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
                    'Remaining Debt: ${moneyNegative(debt)}',
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
              label: const Text('Create Purchase Invoice'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'New Purchase',
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
                if (_items.isNotEmpty) _buildTotalsBar(),
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

  _PurchaseFee({
    required this.id,
    required this.description,
    required this.amount,
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
      _showError('Describe what the fee is for.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('The fee amount must be greater than zero.');
      return;
    }

    navigator.pop(
      _PurchaseFee(
        id: widget.fee?.id ?? DateTime.now().microsecondsSinceEpoch,
        description: description,
        amount: amount,
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
      title: Text(widget.fee == null ? 'Add Fee' : 'Edit Fee'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Shipping, customs, handling...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₦ ',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Added to the total cost, but not owed to the supplier.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _add,
          child: Text(widget.fee == null ? 'Add' : 'Save'),
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
      _showError('Every item must have a name, model number, and barcode.');
      return;
    }

    final purchasePrice = double.tryParse(_priceController.text.trim());

    if (purchasePrice == null || purchasePrice < 0) {
      _showError('Purchase price must be a non-negative amount.');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      _showError('Quantity must be greater than zero.');
      return;
    }

    final profitMargin = double.tryParse(_marginController.text.trim());

    if (profitMargin == null || profitMargin < 0) {
      _showError('Profit margin must be a non-negative amount.');
      return;
    }

    final categoryId = _selectedCategoryId;

    if (categoryId == null || categoryId <= 0) {
      _showError('Please choose a category.');
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
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Model Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              decoration: const InputDecoration(labelText: 'Barcode'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('category-$_selectedCategoryId'),
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
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
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      prefixText: '\u20a6 ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
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
              decoration: const InputDecoration(labelText: 'Profit Margin'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _add,
          child: Text(widget.item == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
