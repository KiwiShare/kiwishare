import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/watchlist_provider.dart';
import '../../theme/app_theme.dart';

class WatchlistScreen extends StatefulWidget {
  final ValueChanged<ItemModel>? onOpenItem;

  const WatchlistScreen({super.key, this.onOpenItem});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final TextEditingController _searchController = TextEditingController();
  ItemStatus? _selectedStatus; // null means 'All'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchlistProvider>().loadWatchlist();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openItem(ItemModel item) {
    if (widget.onOpenItem != null) {
      widget.onOpenItem!(item);
    } else {
      context.push('/items/${item.id}', extra: item);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistProvider>();
    final items = watchlist.watchlistItems;

    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = items.where((item) {
      if (_selectedStatus != null && item.status != _selectedStatus) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesDesc = item.description.toLowerCase().contains(query);
        final matchesCategory = item.category.toLowerCase().contains(query);
        final matchesLoc = item.location.toLowerCase().contains(query);
        if (!matchesTitle && !matchesDesc && !matchesCategory && !matchesLoc) {
          return false;
        }
      }
      return true;
    }).toList();

    final isFiltered = query.isNotEmpty || _selectedStatus != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => watchlist.loadWatchlist(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: _WatchlistHeader(
                    itemCount: items.length,
                    filteredCount: isFiltered ? filteredItems.length : null,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            key: const Key('watchlist-search-field'),
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search in watchlist...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              suffixIcon: query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _StatusFilterChip(
                                key: const Key('watchlist-filter-all'),
                                label: 'All',
                                isSelected: _selectedStatus == null,
                                count: items.length,
                                onSelected: () {
                                  setState(() => _selectedStatus = null);
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusFilterChip(
                                key: const Key('watchlist-filter-available'),
                                label: 'Available',
                                isSelected: _selectedStatus == ItemStatus.active,
                                count: items
                                    .where((i) => i.status == ItemStatus.active)
                                    .length,
                                onSelected: () {
                                  setState(
                                    () => _selectedStatus = ItemStatus.active,
                                  );
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusFilterChip(
                                key: const Key('watchlist-filter-reserved'),
                                label: 'Reserved',
                                isSelected:
                                    _selectedStatus == ItemStatus.reserved,
                                count: items
                                    .where(
                                      (i) => i.status == ItemStatus.reserved,
                                    )
                                    .length,
                                onSelected: () {
                                  setState(
                                    () => _selectedStatus = ItemStatus.reserved,
                                  );
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusFilterChip(
                                key: const Key('watchlist-filter-sold'),
                                label: 'Sold',
                                isSelected: _selectedStatus == ItemStatus.sold,
                                count: items
                                    .where((i) => i.status == ItemStatus.sold)
                                    .length,
                                onSelected: () {
                                  setState(
                                    () => _selectedStatus = ItemStatus.sold,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ),
                  ),
                ),
              if (watchlist.isLoading && items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyWatchlistView(
                    onDiscoverPressed: () => context.go('/home'),
                  ),
                )
              else if (filteredItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoMatchingWatchlistView(
                    onResetPressed: _clearFilters,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _WatchlistCard(
                          item: item,
                          onTap: () => _openItem(item),
                          onRemove: () =>
                              watchlist.removeFromWatchlist(item.id),
                        ),
                      );
                    }, childCount: filteredItems.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistHeader extends StatelessWidget {
  final int itemCount;
  final int? filteredCount;

  const _WatchlistHeader({required this.itemCount, this.filteredCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: AppColors.brandPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Watchlist',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                filteredCount != null
                    ? '$filteredCount of $itemCount'
                    : '$itemCount items',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.brandPrimaryAlt,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Keep track of pre-loved items you love and watch for updates',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _WatchlistCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WatchlistCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Item Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.surfaceMuted,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.brandSecondary,
                                      ),
                                    ),
                              )
                            : Container(
                                color: AppColors.surfaceMuted,
                                child: const Icon(
                                  Icons.eco_outlined,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                        if (item.isSustainable)
                          const Positioned(
                            top: 4,
                            left: 4,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: AppColors.brandPrimaryContainer,
                              child: Icon(
                                Icons.eco,
                                size: 11,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${item.priceNzd} NZD',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBgColor(item.status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusText(item.status),
                              style: TextStyle(
                                color: _statusTextColor(item.status),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Unwatch button
                IconButton(
                  key: Key('watchlist-remove-${item.id}'),
                  icon: const Icon(
                    Icons.bookmark_remove_outlined,
                    color: AppColors.error,
                    size: 22,
                  ),
                  tooltip: 'Remove from Watchlist',
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusBgColor(ItemStatus status) => switch (status) {
    ItemStatus.active => AppColors.brandPrimaryContainer,
    ItemStatus.reserved => Colors.amber.shade100,
    ItemStatus.sold => Colors.grey.shade200,
  };

  Color _statusTextColor(ItemStatus status) => switch (status) {
    ItemStatus.active => AppColors.brandPrimary,
    ItemStatus.reserved => Colors.amber.shade900,
    ItemStatus.sold => Colors.grey.shade700,
  };

  String _statusText(ItemStatus status) => switch (status) {
    ItemStatus.active => 'Available',
    ItemStatus.reserved => 'Reserved',
    ItemStatus.sold => 'Sold',
  };
}

class _EmptyWatchlistView extends StatelessWidget {
  final VoidCallback onDiscoverPressed;

  const _EmptyWatchlistView({required this.onDiscoverPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_outline,
                size: 48,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your watchlist is empty',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Discover eco-friendly pre-loved items and tap the Watch button to keep track of them here.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              key: const Key('watchlist-explore-button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 0,
              ),
              onPressed: onDiscoverPressed,
              icon: const Icon(Icons.explore_outlined, size: 20),
              label: const Text(
                'Explore Products',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int count;
  final VoidCallback onSelected;

  const _StatusFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.count,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.brandPrimaryAlt : AppColors.textPrimary,
      ),
      selectedColor: AppColors.brandSecondaryContainer,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.brandPrimary : AppColors.border,
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _NoMatchingWatchlistView extends StatelessWidget {
  final VoidCallback onResetPressed;

  const _NoMatchingWatchlistView({required this.onResetPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No matching items found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try adjusting your search terms or filter selection.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: const Key('watchlist-reset-filters-button'),
              onPressed: onResetPressed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset filters'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
