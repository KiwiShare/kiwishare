import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../profile/payment_checkout_screen.dart';
import 'widgets/order_lifecycle_panel.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final OrderModel? initialOrder;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _loading = false;
  String? _error;
  bool _refunding = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null || token.isEmpty) return;
    if (_order == null) setState(() => _loading = true);
    try {
      final order = await context.read<OrderProvider>().loadOrderDetails(
        orderId: widget.orderId,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pay(OrderModel order) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentCheckoutScreen(order: order),
      ),
    );
    if (result == true && mounted) await _load();
  }

  Future<void> _refund(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(order.isSelling ? 'Refund order?' : 'Claim refund?'),
        content: Text(
          order.isSelling
              ? 'The buyer will be refunded and the listing will be relisted.'
              : 'This will request the eligible refund and relist the item when the refund completes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().jwtToken;
    if (token == null || token.isEmpty) return;
    setState(() => _refunding = true);
    try {
      final updated = await context.read<OrderProvider>().refundOrder(
        orderId: order.id,
        token: token,
        reason: 'Requested from order details',
      );
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refund processed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _refunding = false);
    }
  }

  bool _refundAvailable(OrderModel order) {
    if (!order.isPaid || order.isCompleted || order.isRefunded) return false;
    if (order.isSelling) return true;
    final paidAt = order.paidAt;
    if (paidAt == null) return false;
    return !order.isMeetupConfirmed &&
        DateTime.now().difference(paidAt).inHours >= 48;
  }

  Widget _buildActions(OrderModel order) {
    final buttons = <Widget>[
      if (order.isBuying &&
          !order.isPaid &&
          !order.isCompleted &&
          !order.isCancelled)
        FilledButton.icon(
          key: const Key('order-detail-pay'),
          onPressed: () => _pay(order),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Pay now'),
        ),
      if (order.meeting != null)
        FilledButton.tonalIcon(
          key: const Key('order-detail-meetup'),
          onPressed: () => context.push('/meetups/${order.id}/qr'),
          icon: const Icon(Icons.handshake_outlined),
          label: Text(order.isHandoverReady ? 'Meetup & QR' : 'Meetup details'),
        ),
      OutlinedButton.icon(
        key: const Key('order-detail-item'),
        onPressed: () => context.push('/items/${order.itemId}'),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('View item'),
      ),
      if (_refundAvailable(order))
        OutlinedButton.icon(
          key: const Key('order-detail-refund'),
          onPressed: _refunding ? null : () => _refund(order),
          icon: _refunding
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.undo_rounded),
          label: Text(order.isSelling ? 'Refund order' : 'Claim refund'),
        ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: buttons,
    );
  }

  Widget _buildPaymentBreakdown(OrderModel order) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = <({String label, String value})>[
      (
        label: 'Item amount',
        value: '\$${order.itemAmountNzd ?? order.item.priceNzd} NZD',
      ),
      if (order.buyerFeeAmountNzd != null)
        (label: 'Buyer protection', value: '\$${order.buyerFeeAmountNzd} NZD'),
      if (order.buyerTotalAmountNzd != null)
        (label: 'Buyer total', value: '\$${order.buyerTotalAmountNzd} NZD'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    row.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && order == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && order == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 42),
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : order == null
          ? const Center(child: Text('Order details unavailable.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: order.item.imageUrl.isEmpty
                              ? ColoredBox(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.inventory_2_outlined),
                                )
                              : Image.network(
                                  order.item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.item.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.isBuying
                                  ? 'Buying from ${order.counterparty.displayName}'
                                  : 'Selling to ${order.counterparty.displayName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              order.statusDisplay,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OrderLifecyclePanel(
                    orderId: order.orderNumber.isEmpty
                        ? order.id
                        : order.orderNumber,
                    itemTitle: order.item.title,
                    amountNzd: order.itemAmountNzd ?? order.item.priceNzd,
                    isPaid: order.isPaid,
                    isMeetupConfirmed: order.isMeetupConfirmed,
                    isCompleted: order.isCompleted,
                    scheduledAt: order.meeting?.scheduledAt,
                    locationName: order.meeting?.locationName,
                    latitude: order.meeting?.latitude,
                    longitude: order.meeting?.longitude,
                    counterpartyName: order.counterparty.displayName,
                    statusLabel: order.statusDisplay,
                    itemImageUrl: order.item.imageUrl,
                    showItemRow: false,
                    actions: _buildActions(order),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPaymentBreakdown(order),
                  if (order.paidAt != null ||
                      order.completedAt != null ||
                      order.refundedAt != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _OrderTimelineDates(order: order),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OrderTimelineDates extends StatelessWidget {
  const _OrderTimelineDates({required this.order});

  final OrderModel order;

  String _date(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = <({String label, DateTime date})>[
      (label: 'Order created', date: order.createdAt),
      if (order.paidAt != null)
        (label: 'Payment confirmed', date: order.paidAt!),
      if (order.completedAt != null)
        (label: 'Transaction completed', date: order.completedAt!),
      if (order.refundedAt != null)
        (label: 'Refunded', date: order.refundedAt!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(entry.label)),
                Text(
                  _date(context, entry.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
