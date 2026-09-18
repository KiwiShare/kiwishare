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
    if (_selectedStatusFilter == 'in_progress') {
      return list.where((o) => o.isInProgress).toList();
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
                  _FilterChip(
                    label: 'All',
                    selected: _selectedStatusFilter == 'all',
                    onSelected: () => setState(() => _selectedStatusFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    selected: _selectedStatusFilter == 'in_progress',
                    onSelected: () =>
                        setState(() => _selectedStatusFilter = 'in_progress'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    selected: _selectedStatusFilter == 'completed',
                    onSelected: () =>
                        setState(() => _selectedStatusFilter = 'completed'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Order Lists
          Expanded(
            child: orderProvider.isLoading && orderProvider.orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _OrdersList(
                        orders: buyingOrders,
                        emptyMessage: 'No purchase orders found.',
                        onRefresh: _loadOrders,
                      ),
                      _OrdersList(
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.brandPrimary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.brandPrimary : AppColors.border,
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _OrdersList({
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

    // Status Badge colors
    final Color badgeBg;
    final Color badgeFg;
    if (isCompleted) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (isInProgress) {
      badgeBg = const Color(0xFFE0F2FE);
      badgeFg = const Color(0xFF0369A1);
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFB91C1C);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: isInProgress
              ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
              : colors.outline.withValues(alpha: 0.2),
          width: isInProgress ? 1.2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order Number + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.orderNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
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
                            errorBuilder: (context, error, stackTrace) => const Icon(
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
                        style: TextStyle(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.isBuying ? 'Seller' : 'Buyer'}: ${order.counterparty.displayName}',
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
            if (order.meeting != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF86EFAC).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 18,
                      color: AppColors.brandPrimary,
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
                              fontWeight: FontWeight.w600,
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
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        MapLauncherService.instance.showNavigationSheet(
                          context: context,
                          locationName: order.meeting!.locationName,
                          latitude: order.meeting!.latitude,
                          longitude: order.meeting!.longitude,
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 14),
                      label: const Text('Directions', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Pay Now — only for buyers with pending payment
                if (order.isBuying && order.status == 'pending_payment') ...[
                  FilledButton.icon(
                    key: Key('pay_now_btn_${order.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isInProgress) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      context.push('/meetups/${order.id}/qr');
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: const Text('QR Handover',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    context.push('/messages');
                  },
                  icon:
                      const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    context.push('/items/${order.itemId}');
                  },
                  child:
                      const Text('View Item', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
