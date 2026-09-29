import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kiwigold_coin_icon.dart';
import '../../widgets/vip_crown_icon.dart';
import '../products/product_detail_screen.dart';
import '../shared/widgets/edit_item_sheet.dart';
import 'kiwigold_topup_sheet.dart';

enum UserListingsMode { selling, sold }

class UserListingsScreen extends StatefulWidget {
  const UserListingsScreen({super.key, required this.mode});
  final UserListingsMode mode;

  @override
  State<UserListingsScreen> createState() => _UserListingsScreenState();
}

class _UserListingsScreenState extends State<UserListingsScreen> {
  String? _token;
  Future<List<ItemModel>>? _itemsFuture;
  int _selectedFilterIndex = 0; // 0: Active, 1: Delisted, 2: All

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthProvider>().jwtToken;
    if (token != _token) {
      _token = token;
      _load();
    }
  }

  void _load() {
    final token = _token;
    if (token == null) {
      _itemsFuture = null;
      return;
    }
    _itemsFuture = context.read<ListingProvider>().getMyItems(
      sold: widget.mode == UserListingsMode.sold,
      token: token,
    );
  }

  Future<void> _handlePromote(ItemModel item) async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    final user = auth.currentUser;
    if (token == null || user == null) return;

    final isVip = user.isVip;
    final currentGold = user.kiwiGold;

    if (!isVip && currentGold < 5) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              KiwiGoldCoinIcon(size: 20),
              SizedBox(width: 8),
              Text('Insufficient KiwiGold'),
            ],
          ),
          content: Text(
            'You have $currentGold KiwiGold, but 5 KiwiGold is required to promote a listing.\n\nTop up KiwiGold or get VIP for Unlimited Promotions!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                KiwiGoldTopUpSheet.show(context);
              },
              child: const Text('Top Up / Get VIP'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (isVip) ...[
              const VipCrownIcon(size: 20),
              const SizedBox(width: 8),
            ] else
              const Text('🚀 '),
            Text(isVip ? 'VIP Boost Listing' : 'Promote Listing'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promote "${item.title}" to the top of searches and recommendations?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isVip ? const Color(0xFFF5F3FF) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isVip
                      ? const Color(0xFFC4B5FD)
                      : Colors.amber.shade300,
                ),
              ),
              child: Row(
                children: [
                  isVip
                      ? const VipCrownIcon(size: 24)
                      : const KiwiGoldCoinIcon(size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVip ? 'VIP Free Promotion' : 'Cost: 5 KiwiGold',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isVip
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFF78350F),
                          ),
                        ),
                        Text(
                          isVip
                              ? 'Unlimited listing boosts active (0 KiwiGold used)'
                              : 'Your balance: $currentGold KiwiGold → ${currentGold - 5} KiwiGold',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isVip
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isVip ? 'Boost Listing (VIP Free)' : 'Promote (5 KiwiGold)',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final listingProvider = context.read<ListingProvider>();
      final result = await listingProvider.promoteItem(
        id: item.id,
        token: token,
      );
      final newGold = result['kiwiGold'] as int?;
      if (newGold != null) {
        auth.updateKiwiGold(newGold);
      } else if (!isVip) {
        auth.updateKiwiGold(currentGold - 5);
      }
      setState(_load);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVip
                  ? '👑 Listing boosted to top ranking with VIP Unlimited Boost!'
                  : '🚀 Listing boosted to top ranking! (-5 KiwiGold)',
            ),
            backgroundColor: isVip
                ? const Color(0xFF7C3AED)
                : const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to promote: $e')));
      }
    }
  }

  Future<void> _handleToggleListing(ItemModel item, bool publish) async {
    final token = _token;
    if (token == null) return;
    if (item.status == ItemStatus.sold) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sold listings are locked. Refund or cancel the paid order first.',
          ),
        ),
      );
      return;
    }

    final actionLabel = publish ? 'Relist' : 'Delist';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionLabel?'),
        content: Text(
          publish
              ? 'This item will become visible again to all buyers in discovery and search.'
              : 'Taking this item off the market will hide it from search and discovery. You can relist it at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: publish
                  ? const Color(0xFF059669)
                  : Colors.grey.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final listingProvider = context.read<ListingProvider>();
      await listingProvider.toggleListingStatus(
        id: item.id,
        publish: publish,
        token: token,
      );
      setState(_load);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish
                  ? 'Item relisted and live on KiwiShare!'
                  : 'Item delisted and hidden from search.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update listing: $e')));
      }
    }
  }

  Widget _buildKiwiGoldBanner(
    BuildContext context,
    int goldBalance, {
    bool isVip = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? const [Color(0xFFFAF5FF), Color(0xFFEDE9FE)]
              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVip ? const Color(0xFFC4B5FD) : const Color(0xFFFCD34D),
        ),
        boxShadow: [
          BoxShadow(
            color: (isVip ? const Color(0xFF8B5CF6) : Colors.amber).withOpacity(
              0.12,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isVip ? const Color(0xFF8B5CF6) : Colors.amber)
                      .withOpacity(0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            child: isVip
                ? const Center(child: VipCrownIcon(size: 22))
                : const KiwiGoldCoinIcon(size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isVip ? 'VIP Member' : '$goldBalance KiwiGold',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isVip
                            ? const Color(0xFF5B21B6)
                            : const Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isVip
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isVip ? 'Unlimited Boosts' : 'Boost Credits',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isVip
                      ? 'Promote all your listings to top ranking for free'
                      : 'Promote listings to top ranking · 5 KiwiGold per boost',
                  style: TextStyle(
                    fontSize: 12,
                    color: isVip
                        ? const Color(0xFF6D28D9)
                        : Colors.brown.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: isVip
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => KiwiGoldTopUpSheet.show(context),
            child: Text(
              isVip ? 'VIP Perks' : 'Top Up',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(List<ItemModel> allItems) {
    final colors = Theme.of(context).colorScheme;
    final activeCount = allItems.where((i) => i.isActive).length;
    final delistedCount = allItems.where((i) => i.isDelisted).length;
    final filters = <(int, String)>[
      (0, 'Active ($activeCount)'),
      (1, 'Delisted ($delistedCount)'),
      (2, 'All (${allItems.length})'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              key: Key('listing-filter-${filter.$1}'),
              label: Text(filter.$2),
              selected: _selectedFilterIndex == filter.$1,
              onSelected: (_) {
                setState(() => _selectedFilterIndex = filter.$1);
              },
              showCheckmark: false,
              side: BorderSide.none,
              backgroundColor: colors.surfaceContainerLow,
              selectedColor: colors.primaryContainer,
              labelStyle: TextStyle(
                color: _selectedFilterIndex == filter.$1
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, ItemModel item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDelisted = item.isDelisted;
    final isActive = item.isActive;
    final isReserved = item.status == ItemStatus.reserved;
    final isSold = item.status == ItemStatus.sold;
    final isVipUser = context.watch<AuthProvider>().currentUser?.isVip == true;

    final statusLabel = isSold
        ? 'Sold'
        : isDelisted
        ? 'Delisted'
        : isReserved
        ? 'Reserved'
        : 'Active';
    final statusForeground = isSold
        ? colors.onSurfaceVariant
        : isDelisted
        ? const Color(0xFFB45309)
        : isReserved
        ? const Color(0xFF9A6700)
        : colors.primary;
    final statusBackground = isSold
        ? colors.surfaceContainerHighest
        : isDelisted
        ? const Color(0xFFFFF7ED)
        : isReserved
        ? const Color(0xFFFFF8E1)
        : colors.primaryContainer.withValues(alpha: isDark ? 0.7 : 0.6);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: isDark ? colors.surfaceContainerLow : colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(itemId: item.id, item: item),
                ),
              )
              .then((_) => setState(_load));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.imageUrl.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: colors.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colors.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                          if (isDelisted || isSold)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.18),
                            ),
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (item.isPromoted) ...[
                                const SizedBox(width: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.rocket_launch_rounded,
                                          size: 11,
                                          color: Color(0xFFD97706),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Boosted',
                                          style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item.isFree ? 'Free' : '\$${item.priceNzd} NZD',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: statusBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusForeground,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.favorite_border_rounded,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.watchlistCount}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.mode == UserListingsMode.selling) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isActive)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => _handlePromote(item),
                        icon: isVipUser
                            ? const VipCrownIcon(size: 14)
                            : const Icon(
                                Icons.rocket_launch_outlined,
                                size: 14,
                              ),
                        label: Text(
                          isVipUser
                              ? item.isPromoted
                                    ? 'VIP Boosted'
                                    : 'VIP Boost (Free)'
                              : item.isPromoted
                              ? 'Boost again'
                              : 'Promote · 5',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isActive)
                      TextButton.icon(
                        onPressed: () => _handleToggleListing(item, false),
                        icon: const Icon(Icons.archive_outlined, size: 15),
                        label: const Text('Delist'),
                      )
                    else if (isDelisted)
                      FilledButton.tonalIcon(
                        onPressed: () => _handleToggleListing(item, true),
                        icon: const Icon(Icons.unarchive_outlined, size: 15),
                        label: const Text('Relist'),
                      ),
                    if (isSold)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Locked after sale',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () async {
                          final updated = await EditItemSheet.show(
                            context,
                            item: item,
                          );
                          if (updated != null) {
                            setState(_load);
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.mode == UserListingsMode.sold;
    final token = _token;
    final user = context.watch<AuthProvider>().currentUser;
    final goldBalance = user?.kiwiGold ?? 10;
    final isVip = user?.isVip == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(sold ? 'Sold' : 'Selling'),
        actions: [
          if (token != null)
            IconButton(
              tooltip: 'Refresh listings',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: token == null
          ? const _ListingsMessage(
              icon: Icons.lock_outline,
              title: 'Please log in',
              message: 'Log in to view your listings.',
            )
          : FutureBuilder<List<ItemModel>>(
              key: ValueKey(token),
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _ListingsMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load your listings',
                    message: 'Check your connection and try again.',
                  );
                }
                final allItems = snapshot.data ?? const <ItemModel>[];
                if (allItems.isEmpty) {
                  return Column(
                    children: [
                      if (!sold)
                        _buildKiwiGoldBanner(
                          context,
                          goldBalance,
                          isVip: isVip,
                        ),
                      Expanded(
                        child: _ListingsMessage(
                          icon: sold
                              ? Icons.inventory_2_outlined
                              : Icons.sell_outlined,
                          title: sold
                              ? 'You haven’t sold anything yet'
                              : 'You have no listings',
                          message: sold
                              ? 'Completed sales will appear here.'
                              : 'Items you list for sale will appear here.',
                        ),
                      ),
                    ],
                  );
                }

                // Filter in selling mode
                List<ItemModel> displayItems = allItems;
                if (!sold) {
                  if (_selectedFilterIndex == 0) {
                    displayItems = allItems.where((i) => i.isActive).toList();
                  } else if (_selectedFilterIndex == 1) {
                    displayItems = allItems.where((i) => i.isDelisted).toList();
                  }
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (!sold) ...[
                      _buildKiwiGoldBanner(context, goldBalance, isVip: isVip),
                      _buildFilterTabs(allItems),
                    ],
                    if (displayItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            _selectedFilterIndex == 0
                                ? 'No active listings currently.'
                                : 'No delisted items.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ...displayItems.map(
                        (item) => _buildItemCard(context, item),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _ListingsMessage extends StatelessWidget {
  const _ListingsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
