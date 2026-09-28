import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/map_launcher_service.dart';
import '../../theme/app_theme.dart';
import 'payment_checkout_screen.dart';

class UserOrdersScreen extends StatefulWidget {
  final int initialTabIndex;
  const UserOrdersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatusFilter = 'all'; // 'all', 'in_progress', 'completed'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;
    await context.read<OrderProvider>().loadMyOrders(token);
  }

  List<OrderModel> _filterOrders(List<OrderModel> list) {
    if (_selectedStatusFilter == 'to_pay') {
      return list
          .where((o) => !o.isPaid && o.status == 'pending_payment')
          .toList();
    }
    if (_selectedStatusFilter == 'paid_pickup') {
      return list
          .where((o) => o.isPaid && !o.isCompleted && !o.isCancelled)
          .toList();
    }
    if (_selectedStatusFilter == 'completed') {
      return list.where((o) => o.isCompleted).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final orderProvider = context.watch<OrderProvider>();

    final buyingOrders = _filterOrders(orderProvider.buyingOrders);
    final sellingOrders = _filterOrders(orderProvider.sellingOrders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorColor: colors.primary,
          tabs: [
            Tab(text: 'Purchases (${orderProvider.buyingOrders.length})'),
            Tab(text: 'Sales Orders (${orderProvider.sellingOrders.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    key: const Key('filter_chip_all'),
                    label: 'All',
                    value: 'all',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    key: const Key('filter_chip_to_pay'),
                    label: 'To Pay',
                    value: 'to_pay',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    key: const Key('filter_chip_paid_pickup'),
                    label: 'Paid (Pickup Pending)',
                    value: 'paid_pickup',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    key: const Key('filter_chip_completed'),
                    label: 'Completed',
                    value: 'completed',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Order Lists
          Expanded(
            child: orderProvider.isLoading && orderProvider.orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _OrdersList(
                        key: ValueKey('buying_$_selectedStatusFilter'),
                        orders: buyingOrders,
                        emptyMessage: 'No purchase orders found.',
                        onRefresh: _loadOrders,
                      ),
                      _OrdersList(
                        key: ValueKey('selling_$_selectedStatusFilter'),
                        orders: sellingOrders,
                        emptyMessage: 'No sales orders found.',
                        onRefresh: _loadOrders,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required Key key,
    required String label,
    required String value,
  }) {
    final isSelected = _selectedStatusFilter == value;
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      key: key,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatusFilter = value;
          });
        }
      },
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.primaryContainer,
      checkmarkColor: colors.onPrimaryContainer,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _OrdersList({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return _OrderItemCard(order: orders[index]);
        },
      ),
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  final OrderModel order;

  const _OrderItemCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCompleted = order.isCompleted;
    final isInProgress = order.isInProgress;
    final isPaid = order.isPaid;

    // Status Badge colors: green for completed, emerald for paid & awaiting pickup, amber for to-pay, red for cancelled
    final Color badgeBg;
    final Color badgeFg;
    if (isCompleted) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (isPaid) {
      badgeBg = const Color(0xFFD1FAE5);
      badgeFg = const Color(0xFF047857);
    } else if (order.status == 'pending_payment') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFB45309);
    } else if (order.isCancelled) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFB91C1C);
    } else {
      badgeBg = const Color(0xFFE0F2FE);
      badgeFg = const Color(0xFF0369A1);
    }

    return Card(
      elevation: 0,
      color: isDark ? colors.surfaceContainerLow : colors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.push('/items/${order.itemId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order Number + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        order.statusDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Item snapshot & price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: colors.surfaceContainerHighest,
                      child: order.item.imageUrl.isNotEmpty
                          ? Image.network(
                              order.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.brandPrimary,
                                  ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.brandPrimary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${order.item.priceNzd} NZD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.isBuying ? 'Seller' : 'Buyer'}: ${order.counterparty.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Meetup info banner if present
              if (order.meeting?.scheduledAt != null &&
                  order.meeting?.locationName != null &&
                  order.meeting!.locationName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.55 : 0.72,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.meeting!.locationName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${order.meeting!.scheduledAt.day}/${order.meeting!.scheduledAt.month}/${order.meeting!.scheduledAt.year} • ${order.meeting!.scheduledAt.hour.toString().padLeft(2, '0')}:${order.meeting!.scheduledAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          MapLauncherService.instance.showNavigationSheet(
                            context: context,
                            locationName: order.meeting!.locationName,
                            latitude: order.meeting!.latitude,
                            longitude: order.meeting!.longitude,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.navigation_rounded,
                                size: 13,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Directions',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 48-Hour reminder banner if paid and no confirmed meetup
              if (isPaid &&
                  !isCompleted &&
                  !order.isRefunded &&
                  !(order.meeting?.proposalStatus == 'confirmed' ||
                      order.meeting?.proposalStatus == 'accepted') &&
                  (order.paidAt != null &&
                      DateTime.now().difference(order.paidAt!).inHours >=
                          48)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFFEF3C7,
                    ).withValues(alpha: isDark ? 0.16 : 0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.isSelling
                              ? 'No meetup agreed after 2 days. You can issue a refund to the buyer now.'
                              : '2 days without a confirmed meetup. You can claim a full refund now.',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons row wrapped to avoid overflow on narrow screens or multi-actions
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Pay Now — only for buyers with pending payment that is not yet paid
                    if (order.isBuying &&
                        order.status == 'pending_payment' &&
                        !isPaid)
                      FilledButton.icon(
                        key: Key('pay_now_btn_${order.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PaymentCheckoutScreen(
                                order: order,
                                onSuccess: () {
                                  // orders already refreshed inside checkout screen
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_outline, size: 14),
                        label: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                    // Invoice button for paid or completed orders
                    if (isPaid || isCompleted)
                      TextButton.icon(
                        key: Key('invoice_btn_${order.id}'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showInvoiceSheet(context, order),
                        icon: const Icon(Icons.receipt_long_outlined, size: 15),
                        label: const Text(
                          'Invoice',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),

                    // Refund button for Seller (anytime before completed/refunded) or Buyer (after 48 hours without meetup)
                    if (!isCompleted &&
                        !order.isRefunded &&
                        isPaid &&
                        (order.isSelling ||
                            (order.isBuying &&
                                !(order.meeting?.proposalStatus ==
                                        'confirmed' ||
                                    order.meeting?.proposalStatus ==
                                        'accepted') &&
                                order.paidAt != null &&
                                DateTime.now()
                                        .difference(order.paidAt!)
                                        .inHours >=
                                    48)))
                      TextButton.icon(
                        key: Key('refund_btn_${order.id}'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            _showRefundConfirmation(context, order),
                        icon: const Icon(Icons.restart_alt_rounded, size: 15),
                        label: Text(
                          order.isSelling ? 'Refund Order' : 'Claim Refund',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    if ((isInProgress || isPaid) && !order.isRefunded)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          context.push('/meetups/${order.id}/qr');
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                        label: const Text(
                          'QR Handover',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        context.push('/messages');
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                      ),
                      label: const Text('Chat', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRefundConfirmation(
    BuildContext context,
    OrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Flexible(child: Text('Confirm Refund')),
          ],
        ),
        content: Text(
          order.isSelling
              ? 'Are you sure you want to refund Order #${order.orderNumber}? The payment will be returned to the buyer, and your listing will be automatically relisted back to active.'
              : 'Claim a full refund for Order #${order.orderNumber}? As no meetup was agreed within 2 days, funds will be refunded and the item will be relisted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Process Refund'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final auth = context.read<AuthProvider>();
      final token = auth.jwtToken;
      if (token == null) return;
      try {
        await context.read<OrderProvider>().refundOrder(
          orderId: order.id,
          token: token,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Refund processed successfully. Listing has been relisted.',
              ),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to refund: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showInvoiceSheet(BuildContext context, OrderModel order) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final itemPrice = order.itemAmountNzd ?? order.item.priceNzd;
    final buyerFee = order.buyerFeeAmountNzd ?? '0.00';
    final totalAmount = order.buyerTotalAmountNzd ?? itemPrice;
    final dateStr = order.paidAt != null
        ? '${order.paidAt!.day}/${order.paidAt!.month}/${order.paidAt!.year} ${order.paidAt!.hour.toString().padLeft(2, '0')}:${order.paidAt!.minute.toString().padLeft(2, '0')}'
        : '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131D19) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFF059669),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Payment Invoice',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'KiwiShare NZ Marketplace',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order.isRefunded
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: order.isRefunded
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          order.isRefunded ? 'REFUNDED' : 'PAID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: order.isRefunded
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInvoiceRow(
                    'Invoice Number',
                    'INV-${order.orderNumber}',
                  ),
                  const SizedBox(height: 6),
                  _buildInvoiceRow('Order ID', '#${order.orderNumber}'),
                  const SizedBox(height: 6),
                  _buildInvoiceRow('Date & Time', dateStr),
                  const SizedBox(height: 6),
                  _buildInvoiceRow('Role', order.isBuying ? 'Buyer' : 'Seller'),
                  const SizedBox(height: 6),
                  _buildInvoiceRow(
                    order.isBuying ? 'Seller' : 'Buyer',
                    order.counterparty.displayName,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A2622)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.outline.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (order.item.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              order.item.imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image, size: 48),
                            ),
                          )
                        else
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 24,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.item.category} · ${order.item.condition ?? 'Good'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$$itemPrice',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInvoiceRow(
                    'Item Subtotal (Private Sale)',
                    '\$$itemPrice NZD',
                  ),
                  const SizedBox(height: 6),
                  _buildInvoiceRow(
                    'Buyer Escrow & Protection',
                    '\$$buyerFee NZD',
                  ),
                  const SizedBox(height: 4),
                  _buildInvoiceRow(
                    '  └ Includes 15% NZ GST',
                    '\$${((double.tryParse(buyerFee) ?? 0.0) * 3 / 23).toStringAsFixed(2)} NZD',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Paid',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '\$$totalAmount NZD',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Paid via Stripe Secure Payment. KiwiShare Escrow Protection Guarantee active until item handover.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Close Invoice',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildInvoiceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
