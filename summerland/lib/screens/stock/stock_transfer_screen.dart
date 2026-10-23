import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/stock_transfer.dart';
import '../../services/api_service.dart';
import '../../services/stock_transfer_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/reconnect_reloader.dart';

import 'create_stock_transfer_screen.dart';

class StockTransfersScreen extends StatefulWidget {
  const StockTransfersScreen({super.key});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen>
    with ReconnectReloader<StockTransfersScreen> {
  late final StockTransferService _service;

  List<StockTransfer> _transfers = [];
  bool _isLoading = true;
  String? _error;

  DateTime? _from;
  DateTime? _to;

  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _service = StockTransferService(ApiService());

    _from = defaultFilterFromDate();
    _to = defaultFilterToDate();

    _loadTransfers();
  }

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

  Future<void> _loadTransfers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transfers = await _service.getTransfers(from: _from, to: _to);

      if (!mounted) return;

      setState(() {
        _transfers = transfers;
        _currentPage = 0;
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

  @override
  void onReconnected() {
    _loadTransfers();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });

    await _loadTransfers();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _itemCountLabel(BuildContext context, StockTransfer transfer) {
    final count = transfer.items.length;

    return count == 1
        ? context.tr('1 variant')
        : context.tr('{0} variants', [count]);
  }

  Future<void> _openCreateScreen() async {
    if (!ensureOnlineForWrite(context)) return;

    final result = await pushScreen<bool>(
      context,
      (_) => const CreateStockTransferScreen(),
    );

    if (result == true) {
      _loadTransfers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Stock Transfers'),
      destinationId: 'transfers',
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateScreen,
        tooltip: context.tr('Create stock transfer'),
        child: const Icon(Icons.swap_horiz),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: WideContent(
        child: DateFilterBar(
          fromLabel: _formatDate(_from!),
          toLabel: _formatDate(_to!),
          onFrom: () => _pickDate(true),
          onTo: () => _pickDate(false),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadTransfers);
    }

    final pageItems = _pageSlice(_transfers);

    return WideContent(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransfers,
              child: _transfers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.swap_horiz_rounded,
                          title: context.tr('No stock transfers found'),
                          message: context.tr(
                            'Transfer stock between locations using the + '
                            'button.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final transfer = pageItems[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _itemCountLabel(context, transfer),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    _QuantityBadge(
                                      label: context.tr('Total: {0}', [
                                        transfer.totalQuantity,
                                      ]),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _LocationChip(
                                        label: transfer.fromLocationName,
                                        isSource: true,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: _LocationChip(
                                        label: transfer.toLocationName,
                                        isSource: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...transfer.items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.tr('× {0}', [item.quantity]),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${transfer.createdAt.toLocal()}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          PaginationBar(
            page: _currentPage,
            pageSize: _pageSize,
            totalItems: _transfers.length,
            onPageChanged: _goToPage,
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label, required this.isSource});

  final String label;
  final bool isSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSource
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSource ? context.tr('FROM') : context.tr('TO'),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
