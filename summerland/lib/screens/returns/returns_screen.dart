import 'package:flutter/material.dart';

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
            return AlertDialog(
              title: Text(context.tr('Return Created')),
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        color: Theme.of(context).colorScheme.outline,
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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                  InfoTile(
                    label: context.tr('Location'),
                    value: record.locationName,
                  ),
                  InfoTile(
                    label: context.tr('Total'),
                    value: money(record.totalAmount),
                    valueStyle: amountStyle(context, record.totalAmount),
                  ),
                ],
              ),
              actions: [
                FilledButton(
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: WideContent(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _invoiceIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Invoice ID'),
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                ),
                onSubmitted: (_) => _loadInvoice(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
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
          ],
        ),
      ),
    );
  }

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
                const Divider(height: 1),
                if (_invoice == null)
                  Expanded(
                    child: EmptyState(
                      icon: Icons.assignment_return_outlined,
                      title: context.tr(
                        'Enter an invoice ID to start a return.',
                      ),
                      message: context.tr(
                        'Load an invoice to return sold items.',
                      ),
                    ),
                  )
                else
                  Expanded(child: _buildInvoice()),
              ],
            ),
    );
  }

  Widget _buildInvoice() {
    final invoice = _invoice!;

    return WideContent(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Invoice #{0}', [invoice.id]),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 22),
                  InfoTile(
                    label: context.tr('Cashier Location'),
                    value: invoice.locationName,
                  ),
                  InfoTile(
                    label: context.tr('Date'),
                    value: '${invoice.createdAt}',
                  ),
                  InfoTile(
                    label: context.tr('Invoice Total'),
                    value: money(invoice.totalAmount),
                    valueStyle: amountStyle(context, invoice.totalAmount),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: context.tr('Invoice Items'),
            subtitle: context.tr('Return an item with the Return button'),
          ),
          const SizedBox(height: 8),
          ...invoice.items.map((item) {
            final details = [
              if (item.sizeName != null)
                context.tr('Size: {0}', [item.sizeName]),
              if (item.colourName != null)
                context.tr('Colour: {0}', [item.colourName]),
            ].join(' • ');

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(item.productName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.modelNumber),
                    if (details.isNotEmpty) Text(details),
                    Text(context.tr('Sold: {0}', [item.quantity])),
                    if (!item.hasDiscount)
                      Text(
                        context.tr('Unit Price: {0}', [money(item.unitPrice)]),
                        style: TextStyle(
                          color: amountColor(context, item.unitPrice),
                        ),
                      )
                    else ...[
                      Text(
                        context.tr('Unit Price: {0} → {1}', [
                          money(item.unitPrice),
                          money(item.unitPriceAfterDiscount),
                        ]),
                        style: TextStyle(
                          color: amountColor(
                            context,
                            item.unitPriceAfterDiscount,
                          ),
                          fontWeight: FontWeight.w600,
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
                          fontSize: 12,
                          color: amountColor(context, -item.discountAmount),
                        ),
                      ),
                    ],
                  ],
                ),
                isThreeLine: true,
                trailing: FilledButton.icon(
                  onPressed: () => _showReturnDialog(item),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: Text(context.tr('Return')),
                ),
              ),
            );
          }),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AlertDialog(
      title: Text(context.tr('Create Return')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(context.tr('Model: {0}', [item.modelNumber])),
            if (item.sizeName != null)
              Text(context.tr('Size: {0}', [item.sizeName])),
            if (item.colourName != null)
              Text(context.tr('Colour: {0}', [item.colourName])),
            const SizedBox(height: 12),
            Text(context.tr('Sold Quantity: {0}', [item.quantity])),
            if (!item.hasDiscount)
              Text(
                context.tr('Unit Price: {0}', [money(item.unitPrice)]),
                style: TextStyle(color: amountColor(context, item.unitPrice)),
              )
            else ...[
              Text(
                context.tr('Unit price before discount: {0}', [
                  money(item.unitPrice),
                ]),
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              Text(
                context.tr('Unit price after discount: {0}', [
                  money(item.unitPriceAfterDiscount),
                ]),
                style: TextStyle(
                  color: amountColor(context, item.unitPriceAfterDiscount),
                  fontWeight: FontWeight.w600,
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
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('location-${_selectedLocation?.id}'),
              initialValue: _selectedLocation?.id,
              decoration: InputDecoration(
                labelText: context.tr('Return Stock Location'),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              items: widget.locations.map((location) {
                return DropdownMenuItem<int>(
                  value: location.id,
                  child: Text(location.name),
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
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Return Quantity'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('Reason'),
                hintText: context.tr('Enter return reason'),
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
        FilledButton(onPressed: _submit, child: Text(context.tr('Return'))),
      ],
    );
  }
}
