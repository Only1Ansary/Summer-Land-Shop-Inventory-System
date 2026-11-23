import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../models/customer.dart';
import '../../models/customer_details.dart';
import '../../services/api_service.dart';
import '../../services/customer_service.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../utils/payment_method.dart';
import '../invoices/show_sale_invoice_screen.dart';
import '../../ui/text_input_helpers.dart';

/// Customer lookup screen. Nothing is loaded until the user types a name or
/// phone number; selecting a result opens its invoices, balance and payments.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerService _customerService = CustomerService(ApiService());

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Timer? _searchDebounce;
  int _searchGeneration = 0;

  List<Customer> _results = [];
  Customer? _selectedCustomer;
  CustomerDetails? _details;

  String? _error;
  bool _isSearching = false;
  bool _isLoadingDetails = false;
  bool _isPaying = false;
  int _paymentMethod = paymentMethodCash;

  static const int _pageSize = 4;
  int _invoicePage = 0;
  int _paymentPage = 0;

  static const Color _paidColor = Color(0xFF2E9E6B);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic (unchanged)
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    if (value.trim().isEmpty) {
      _searchGeneration++;
      setState(() {
        _results = [];
        _selectedCustomer = null;
        _details = null;
        _error = null;
        _isSearching = false;
      });
      return;
    }

    // Rebuild so the clear button appears immediately.
    setState(() {});

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;

    setState(() {
      _isSearching = true;
      _error = null;
      _details = null;
      _selectedCustomer = null;
    });

    try {
      final results = await _customerService.searchCustomers(query);

      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _results = results;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _openCustomer(Customer customer) async {
    setState(() {
      _selectedCustomer = customer;
      _details = null;
      _error = null;
      _isLoadingDetails = true;
      _invoicePage = 0;
      _paymentPage = 0;
      _amountController.clear();
      _paymentMethod = paymentMethodCash;
    });

    try {
      final details = await _customerService.getCustomerDetails(customer.id);

      if (!mounted) return;

      setState(() {
        _details = details;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyErrorMessage(context, e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _backToSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchController.clear();
    _amountController.clear();

    setState(() {
      _results = [];
      _selectedCustomer = null;
      _details = null;
      _error = null;
      _isSearching = false;
      _paymentMethod = paymentMethodCash;
      _invoicePage = 0;
      _paymentPage = 0;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _recordPayment() async {
    final details = _details;

    if (details == null || !ensureOnlineForWrite(context)) return;

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage(context.tr('Enter a payment amount greater than zero.'));
      return;
    }

    if (amount > details.totalDebt + 0.005) {
      _showMessage(
        context.tr(
          "Payment cannot exceed the customer's total debt of {0}.",
          [money(details.totalDebt)],
        ),
      );
      return;
    }

    setState(() {
      _isPaying = true;
    });

    try {
      final updated = await _customerService.payCustomer(
        customerId: details.id,
        amount: amount,
        method: _paymentMethod,
      );

      if (!mounted) return;

      setState(() {
        _details = updated;
        _invoicePage = 0;
        _paymentPage = 0;
        _amountController.clear();
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

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  // ---------------------------------------------------------------------------
  // Small visual helpers
  // ---------------------------------------------------------------------------

  Color _debtColor(BuildContext context, double debt) {
    return debt > 0.005 ? Theme.of(context).colorScheme.error : _paidColor;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first.characters.first.toUpperCase();
    return (list.first.characters.first + list[1].characters.first)
        .toUpperCase();
  }

  Widget _avatar(BuildContext context, String name, {double radius = 24}) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
      }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  int _safePage(int page, int total) {
    final pages = (total / _pageSize).ceil();
    if (pages <= 1) return 0;
    return page.clamp(0, pages - 1);
  }

  List<T> _pageItems<T>(List<T> items, int page) {
    final start = _safePage(page, items.length) * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  Widget _pager(
      BuildContext context, {
        required int total,
        required int page,
        required ValueChanged<int> onChanged,
      }) {
    final pages = (total / _pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();

    final current = _safePage(page, total);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: current > 0 ? () => onChanged(current - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${current + 1} / $pages',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed:
            current < pages - 1 ? () => onChanged(current + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _emptyLine(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Customers'),
      destinationId: 'customers',
      actions: [
        if (_selectedCustomer != null)
          IconButton(
            key: const Key('customer-back-to-search'),
            tooltip: context.tr('Back to search'),
            onPressed: _backToSearch,
            icon: const Icon(Icons.arrow_back),
          ),
      ],
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: WideContent(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selectedCustomer?.id ?? 'search'),
                  child: _selectedCustomer == null
                      ? _buildSearchResults()
                      : _buildDetails(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        key: const Key('customer-search'),
        autofocus: textFieldAutofocus(true),
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: context.tr('Search name or phone'),
          hintText: context.tr('Start typing to find a customer'),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          suffixIcon: _isSearching
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
              : _searchController.text.isEmpty
              ? null
              : IconButton(
            onPressed: _clearSearch,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.trim().isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: context.tr('Search for a customer'),
        message: context.tr('Enter a phone number or name to begin.'),
      );
    }

    if (_isSearching) return const LoadingState();

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () => _search(_searchController.text.trim()),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: context.tr('No customers found'),
        message: context.tr('Try a different phone number or name.'),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final customer = _results[index];
        final hasDebt = customer.totalDebt > 0.005;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: ListTile(
            key: ValueKey('customer-result-${customer.id}'),
            onTap: () => _openCustomer(customer),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: _avatar(context, customer.displayName),
            title: Text(
              customer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      customer.phoneNumber,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(customer.totalDebt),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _debtColor(context, customer.totalDebt),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  hasDebt
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: _debtColor(context, customer.totalDebt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetails() {
    if (_error != null && _details == null) {
      final customer = _selectedCustomer;

      return ErrorState(
        message: _error!,
        onRetry: customer == null ? null : () => _openCustomer(customer),
      );
    }

    if (_isLoadingDetails || _details == null) return const LoadingState();

    final details = _details!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _buildHeroCard(details),
        const SizedBox(height: 14),
        _buildStatsGrid(details),
        const SizedBox(height: 14),
        _buildPaymentCard(details),
        _buildInvoicesCard(details),
        _buildPaymentHistoryCard(details),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detail sections
  // ---------------------------------------------------------------------------

  Widget _buildHeroCard(CustomerDetails details) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDebt = details.totalDebt > 0.005;
    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = isDark ? scheme.primaryContainer : Colors.white;
    final secondaryColor = isDark ? scheme.primaryContainer : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.primary,
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
              CircleAvatar(
                radius: 28,
                backgroundColor: foregroundColor.withValues(alpha: 0.2),
                child: Text(
                  _initials(details.displayName),
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 14, color: secondaryColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            details.phoneNumber,
                            style: TextStyle(color: secondaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: foregroundColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Total debt'),
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          money(details.totalDebt),
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasDebt
                      ? Icons.account_balance_wallet_outlined
                      : Icons.verified_outlined,
                  color: foregroundColor,
                  size: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        required Color color,
      }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(CustomerDetails details) {
    final scheme = Theme.of(context).colorScheme;

    final tiles = [
      _statTile(
        context,
        icon: Icons.receipt_long_outlined,
        label: context.tr('Total invoices'),
        value: '${details.invoiceCount}',
        color: scheme.primary,
      ),
      _statTile(
        context,
        icon: Icons.pending_actions_outlined,
        label: context.tr('Unpaid invoices'),
        value: '${details.unpaidInvoiceCount}',
        color: details.unpaidInvoiceCount > 0 ? scheme.error : _paidColor,
      ),
      _statTile(
        context,
        icon: Icons.savings_outlined,
        label: context.tr('Total paid'),
        value: money(details.totalPaid),
        color: _paidColor,
      ),
      _statTile(
        context,
        icon: Icons.money_off_csred_outlined,
        label: context.tr('Total debt'),
        value: money(details.totalDebt),
        color: _debtColor(context, details.totalDebt),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _buildPaymentCard(CustomerDetails details) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPay = details.totalDebt > 0;

    return _sectionCard(
      context,
      icon: Icons.payments_outlined,
      title: context.tr('Record a payment'),
      subtitle: context.tr('Applied to the oldest unpaid invoices first.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: textFieldAutofocus(false),
            key: const Key('customer-payment-amount'),
            controller: _amountController,
            enabled: !_isPaying && canPay,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: context.tr('Payment amount'),
              prefixIcon: const Icon(Icons.attach_money_rounded),
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
            ),
          ),
          if (canPay) ...[
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(
                '${context.tr('Total debt')}: ${money(details.totalDebt)}',
              ),
              onPressed: _isPaying
                  ? null
                  : () {
                _amountController.text =
                    details.totalDebt.toStringAsFixed(2);
              },
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('customer-payment-method'),
            initialValue: _paymentMethod,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(
              labelText: context.tr('Payment method'),
              prefixIcon: const Icon(Icons.credit_card_outlined),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: paymentMethodValues
                .map(
                  (method) => DropdownMenuItem<int>(
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
              ),
            )
                .toList(),
            onChanged: _isPaying
                ? null
                : (value) {
              if (value != null) {
                setState(() {
                  _paymentMethod = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const Key('customer-pay-button'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: (_isPaying || !canPay) ? null : _recordPayment,
              icon: _isPaying
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isPaying
                    ? context.tr('Recording...')
                    : context.tr('Pay amount'),
              ),
            ),
          ),
          if (!canPay) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: _paidColor),
                const SizedBox(width: 6),
                Text(
                  context.tr('No outstanding balance.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoicesCard(CustomerDetails details) {
    final scheme = Theme.of(context).colorScheme;

    return _sectionCard(
      context,
      icon: Icons.receipt_long_outlined,
      title: context.tr('Invoices'),
      trailing: _pill(
        context,
        '${details.invoices.length}',
        scheme.primary,
      ),
      child: Column(
        children: [
          if (details.invoices.isEmpty)
            _emptyLine(context, context.tr('No invoices yet.')),
          for (final invoice in _pageItems(details.invoices, _invoicePage))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey('customer-invoice-${invoice.id}'),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  onTap: () {
                    pushScreen<void>(
                      context,
                          (_) => ShowSaleInvoiceScreen(invoiceId: invoice.id),
                    );
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (invoice.isFullyPaid
                          ? _paidColor
                          : scheme.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      invoice.isFullyPaid
                          ? Icons.task_alt_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 20,
                      color: invoice.isFullyPaid ? _paidColor : scheme.error,
                    ),
                  ),
                  title: Text(
                    context.tr('Sale Invoice #{0}', [invoice.id]),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${_formatDate(invoice.createdAt)} · ${invoice.locationName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(invoice.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      invoice.isFullyPaid
                          ? _pill(context, context.tr('Paid'), _paidColor)
                          : _pill(
                        context,
                        context.tr(
                          'Remaining: {0}',
                          [money(invoice.remainingAmount)],
                        ),
                        scheme.error,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _pager(
            context,
            total: details.invoices.length,
            page: _invoicePage,
            onChanged: (p) => setState(() => _invoicePage = p),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(CustomerDetails details) {
    final scheme = Theme.of(context).colorScheme;

    return _sectionCard(
      context,
      icon: Icons.history_rounded,
      title: context.tr('Payment history'),
      trailing: _pill(
        context,
        '${details.payments.length}',
        scheme.primary,
      ),
      child: Column(
        children: [
          if (details.payments.isEmpty)
            _emptyLine(context, context.tr('No payments recorded yet')),
          for (final payment in _pageItems(details.payments, _paymentPage))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  key: ValueKey('customer-payment-${payment.id}'),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _paidColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      paymentMethodIcon(payment.method),
                      size: 20,
                      color: _paidColor,
                    ),
                  ),
                  title: Text(
                    context.tr('Sale Invoice #{0}', [payment.saleInvoiceId]),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${paymentMethodLabel(context, payment.method)} · '
                        '${_formatDate(payment.paidAt)}',
                  ),
                  trailing: Text(
                    money(payment.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _paidColor,
                    ),
                  ),
                ),
              ),
            ),
          _pager(
            context,
            total: details.payments.length,
            page: _paymentPage,
            onChanged: (p) => setState(() => _paymentPage = p),
          ),
        ],
      ),
    );
  }
}