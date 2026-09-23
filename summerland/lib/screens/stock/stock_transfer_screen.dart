import 'package:flutter/material.dart';

import '../../models/stock_transfer.dart';
import '../../services/api_service.dart';
import '../../services/stock_transfer_service.dart';

import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';

import 'create_stock_transfer_screen.dart';

class StockTransfersScreen extends StatefulWidget {
  const StockTransfersScreen({super.key});

  @override
  State<StockTransfersScreen> createState() =>
      _StockTransfersScreenState();
}

class _StockTransfersScreenState
    extends State<StockTransfersScreen> {
  late final StockTransferService _service;

  List<StockTransfer> _transfers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _service = StockTransferService(ApiService());

    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transfers = await _service.getTransfers();

      if (!mounted) return;

      setState(() {
        _transfers = transfers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _variantName(StockTransfer transfer) {
    final parts = <String>[
      transfer.productName,
      if (transfer.sizeName != null) transfer.sizeName!,
      if (transfer.colourName != null) transfer.colourName!,
    ];

    return parts.join(' - ');
  }

  Future<void> _openCreateScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateStockTransferScreen(),
      ),
    );

    if (result == true) {
      _loadTransfers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Stock Transfers',
      destinationId: 'transfers',
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateScreen,
        tooltip: 'Create stock transfer',
        child: const Icon(Icons.swap_horiz),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadTransfers,
      );
    }

    return WideContent(
      child: RefreshIndicator(
        onRefresh: _loadTransfers,
        child: _transfers.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.swap_horiz_rounded,
                    title: 'No stock transfers found',
                    message:
                        'Transfer stock between locations using the + button.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _transfers.length,
                itemBuilder: (context, index) {
                  final transfer = _transfers[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _variantName(transfer),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Model: ${transfer.modelNumber}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
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
                                padding: EdgeInsets.symmetric(horizontal: 8),
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
                          Row(
                            children: [
                              _QuantityBadge(
                                label: 'Qty: ${transfer.quantity}',
                              ),
                              const Spacer(),
                              Text(
                                '${transfer.createdAt.toLocal()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                  );
                },
              ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.label,
    required this.isSource,
  });

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
            isSource ? 'FROM' : 'TO',
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
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