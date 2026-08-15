import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../models/listing_query.dart';
import '../../providers/providers.dart';
import '../../services/listing_location_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/app_theme.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/filter_chip.dart';

class SearchScreen extends StatefulWidget {
  final ListingLocationService? locationService;
  final ValueChanged<ItemModel>? onOpenItem;

  const SearchScreen({super.key, this.locationService, this.onOpenItem});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final ListingLocationService _locationService;
  Timer? _debounce;
  ListingQuery? _loadedQuery;
  Future<List<ItemModel>>? _results;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _locationService = widget.locationService ?? DeviceListingLocationService();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ItemModel>> _load(ListingProvider provider, ListingQuery query) {
    if (_results == null || _loadedQuery != query) {
      _loadedQuery = query;
      _results = provider.searchListingItems(query);
    }
    return _results!;
  }

  void _refresh() => setState(() {
    _results = null;
  });

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<SearchProvider>().setQuery(value);
    });
  }

  void _openItem(ItemModel item) {
    if (widget.onOpenItem != null) {
      widget.onOpenItem!(item);
    } else {
      context.push('/products/${item.id}', extra: item);
    }
  }

  Future<void> _chooseLocation() async {
    final search = context.read<SearchProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Browse by location',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.near_me_outlined),
              title: const Text('Items near you'),
              subtitle: const Text(
                'Uses approximate location only after you choose this option',
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final position = await _locationService
                      .getApproximatePosition();
                  if (mounted) {
                    search.setNearby(
                      latitude: position.latitude,
                      longitude: position.longitude,
                    );
                  }
                } on ListingLocationException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
            ),
            for (final location in SearchProvider.locations)
              ListTile(
                leading: Icon(
                  location == 'All NZ' ? Icons.public : Icons.location_city,
                ),
                title: Text(location),
                trailing: search.selectedLocation == location
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  search.setLocation(location);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseSort() async {
    final search = context.read<SearchProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Sort listings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final sort in ListingSortOrder.values)
              if (sort != ListingSortOrder.nearest || search.isNearby)
                RadioListTile<ListingSortOrder>(
                  value: sort,
                  groupValue: search.sortOrder,
                  title: Text(sort.label),
                  onChanged: (value) {
                    if (value != null) search.setSortOrder(value);
                    Navigator.pop(sheetContext);
                  },
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final listingProvider = context.read<ListingProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final query = search.listingQuery;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Browse'),
        actions: [
          TextButton.icon(
            key: const Key('location-button'),
            onPressed: _chooseLocation,
            icon: Icon(
              search.isNearby ? Icons.near_me : Icons.location_on_outlined,
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                search.selectedLocation,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              key: const Key('products-search-field'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: should(FeatureFlag.aiSearch)
                    ? 'Search listings with AI assistance'
                    : 'Search listings',
                hintText: 'Try “camping stove”',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          search.setQuery('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Semantics(
            label: 'Product categories',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  for (final category in SearchProvider.categories) ...[
                    SearchFilterChip(
                      label: category,
                      active: search.selectedCategory == category,
                      onTap: () => search.toggleCategory(category),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                SearchFilterChip(
                  label: 'Sort: ${search.sortOrder.label}',
                  active: search.sortOrder != ListingSortOrder.popular,
                  onTap: _chooseSort,
                  icon: Icons.sort,
                  showDropdown: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                SearchFilterChip(
                  label: 'Saved',
                  active: search.showSavedOnly,
                  onTap: search.toggleSavedOnly,
                  icon: search.showSavedOnly
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                if (search.selectedCategory != null ||
                    search.selectedLocation != 'All NZ' ||
                    search.showSavedOnly) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: search.resetFilters,
                    child: const Text('Clear filters'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ItemModel>>(
              future: _load(listingProvider, query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingGrid();
                }
                if (snapshot.hasError) {
                  return _MessageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load listings',
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  );
                }
                var items = snapshot.data ?? const <ItemModel>[];
                if (search.showSavedOnly) {
                  items = items
                      .where((item) => favorites.isFavorite(item.id))
                      .toList();
                }
                if (items.isEmpty) {
                  return _MessageState(
                    icon: search.showSavedOnly
                        ? Icons.favorite_border
                        : Icons.search_off,
                    title: search.showSavedOnly
                        ? 'No saved listings yet'
                        : 'No listings found',
                    message: 'Try another search, category, or location.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        '${items.length} listings',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => ItemCard(
                          item: items[index],
                          onTap: () => _openItem(items[index]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(AppSpacing.lg),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.72,
    ),
    itemCount: 6,
    itemBuilder: (context, index) => const ItemCardSkeleton(),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.brandPrimary),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
