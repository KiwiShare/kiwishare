import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
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
    final activeCount = allItems.where((i) => i.isActive).length;
    final delistedCount = allItems.where((i) => i.isDelisted).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(
            value: 0,
            label: Text('Active ($activeCount)'),
            icon: const Icon(Icons.check_circle_outline, size: 16),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Delisted ($delistedCount)'),
            icon: const Icon(Icons.archive_outlined, size: 16),
          ),
          ButtonSegment(value: 2, label: Text('All (${allItems.length})')),
        ],
        selected: {_selectedFilterIndex},
        onSelectionChanged: (set) {
          setState(() => _selectedFilterIndex = set.first);
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, ItemModel item) {
    final isDelisted = item.isDelisted;
    final isActive = item.isActive;
    final isReserved = item.status == ItemStatus.reserved;
    final isSold = item.status == ItemStatus.sold;
    final isVipUser = context.watch<AuthProvider>().currentUser?.isVip == true;

    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDelisted
              ? Colors.orange.shade200
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail with Status Badges
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.imageUrl.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                  ),
                                ),
                          if (isDelisted)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Text(
                                  'DELISTED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            )
                          else if (isReserved)
                            Container(
                              color: Colors.amber.withOpacity(0.7),
                              child: const Center(
                                child: Text(
                                  'RESERVED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          else if (isSold)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: Text(
                                  'SOLD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (item.isPromoted) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '🚀 TOP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.isFree ? 'FREE' : '\$${item.priceNzd} NZD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDelisted
                                    ? Colors.orange.shade50
                                    : isReserved
                                    ? Colors.amber.shade50
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isDelisted
                                    ? 'Delisted'
                                    : isReserved
                                    ? 'Reserved'
                                    : 'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDelisted
                                      ? Colors.orange.shade800
                                      : isReserved
                                      ? Colors.amber.shade900
                                      : const Color(0xFF047857),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.favorite_outline,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.watchlistCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Action Buttons Row (only in Selling mode)
              if (widget.mode == UserListingsMode.selling) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Promote Button (enabled on active items)
                    if (isActive) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: BorderSide(
                            color: isVipUser
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFFD97706),
                          ),
                          foregroundColor: isVipUser
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFB45309),
                        ),
                        onPressed: () => _handlePromote(item),
                        icon: isVipUser
                            ? const VipCrownIcon(size: 14)
                            : const Icon(
                                Icons.rocket_launch_outlined,
                                size: 13,
                              ),
                        label: isVipUser
                            ? Text(
                                item.isPromoted
                                    ? 'VIP Boosted'
                                    : 'VIP Boost (Free)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.isPromoted
                                        ? 'Boost Again ('
                                        : 'Promote (',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const KiwiGoldCoinIcon(size: 12),
                                  const Text(
                                    ' 5)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Delist / Relist Button
                    if (isActive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                          foregroundColor: Colors.grey.shade800,
                        ),
                        onPressed: () => _handleToggleListing(item, false),
                        icon: const Icon(Icons.archive_outlined, size: 14),
                        label: const Text(
                          'Delist',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    else if (isDelisted)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _handleToggleListing(item, true),
                        icon: const Icon(Icons.unarchive_outlined, size: 14),
                        label: const Text(
                          'Relist',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Edit Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      onPressed: () async {
                        final updated = await EditItemSheet.show(
                          context,
                          item: item,
                        );
                        if (updated != null) {
                          setState(_load);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
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
