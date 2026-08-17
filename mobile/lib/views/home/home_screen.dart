import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../services/product_location_service.dart';
import '../../theme/app_theme.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/home_filter_sheet.dart';
import 'widgets/home_product_map.dart';

class HomeScreen extends StatefulWidget {
  final ProductLocationService? locationService;
  final ValueChanged<ItemModel>? onOpenItem;

  const HomeScreen({super.key, this.locationService, this.onOpenItem});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;
  late final ProductLocationService _locationService;
  Future<List<ItemModel>>? _itemsFuture;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _locationService = widget.locationService ?? DeviceProductLocationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final discovery = context.read<HomeDiscoveryProvider>();
    _searchController.text = discovery.query;
    _itemsFuture = context.read<ListingProvider>().getDiscoveryItems();
    _initialized = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _retryFetch() async {
    setState(() {
      _itemsFuture = context.read<ListingProvider>().getDiscoveryItems(
        forceRefresh: true,
      );
    });
    await _itemsFuture;
  }

  void _openProduct(ItemModel item) {
    final callback = widget.onOpenItem;
    if (callback != null) {
      callback(item);
      return;
    }
    context.push('/items/${item.id}', extra: item);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<HomeDiscoveryProvider>().setQuery('');
  }

  void _resetFilters() {
    _searchController.clear();
    context.read<HomeDiscoveryProvider>().resetFilters();
  }

  void _showFilters() {
    final filters = context.read<HomeDiscoveryProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (_) => HomeFilterSheet(filters: filters, onReset: _resetFilters),
    );
  }

  void _showLocationPicker() {
    final filters = context.read<HomeDiscoveryProvider>()
      ..setView(HomeProductView.map);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose location',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Location is used only to show approximate nearby listings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                key: const Key('home-near-you-option'),
                minTileHeight: 56,
                leading: const Icon(Icons.my_location),
                title: const Text('Use my current location'),
                subtitle: const Text(
                  'Uses an approximate location once; background tracking is off',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _useCurrentLocation();
                },
              ),
              const Divider(),
              for (final location in HomeDiscoveryProvider.locations)
                ListTile(
                  key: Key('home-location-$location'),
                  minTileHeight: 52,
                  leading: Icon(
                    location == 'All NZ'
                        ? Icons.public
                        : Icons.location_city_outlined,
                  ),
                  title: Text(location),
                  trailing:
                      filters.selectedLocation == location && !filters.isNearYou
                      ? const Icon(Icons.check, color: AppColors.brandPrimary)
                      : null,
                  onTap: () {
                    filters
                      ..setLocation(location)
                      ..setView(HomeProductView.map);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      context.read<HomeDiscoveryProvider>()
        ..setLocation(
          location.city,
          nearYou: true,
          latitude: location.latitude,
          longitude: location.longitude,
        )
        ..setView(HomeProductView.map);
    } on ProductLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<HomeDiscoveryProvider>();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _retryFetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _HomeHeader(
                location: filters.selectedLocation,
                nearYou: filters.isNearYou,
                onChooseLocation: _showLocationPicker,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('home-search-field'),
                controller: _searchController,
                onChanged: filters.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by item name or category',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.brandPrimary,
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 48),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        key: const Key('home-filter-button'),
                        tooltip: 'Sort and filter products',
                        onPressed: _showFilters,
                        color: AppColors.brandPrimary,
                        icon: Badge(
                          isLabelVisible: filters.activeFilterCount > 0,
                          label: Text('${filters.activeFilterCount}'),
                          child: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category
                        in HomeDiscoveryProvider.categories) ...[
                      _HomeCategoryChip(
                        key: Key('home-category-$category'),
                        label: category,
                        selected: filters.selectedCategory == category,
                        onTap: () => filters.toggleCategory(category),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FutureBuilder<List<ItemModel>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _HomeLoadingState();
                  }
                  if (snapshot.hasError) {
                    return _HomeErrorState(onRetry: _retryFetch);
                  }
                  final products = filters.filterAndSort(
                    snapshot.data ?? const <ItemModel>[],
                  );
                  ItemModel? selectedItem;
                  for (final product in products) {
                    if (product.id == filters.previewItemId) {
                      selectedItem = product;
                      break;
                    }
                  }
                  return _HomeDiscoveryResults(
                    products: products,
                    selectedItem: selectedItem,
                    filters: filters,
                    onShowFilters: _showFilters,
                    onOpenProduct: _openProduct,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SustainabilityBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String location;
  final bool nearYou;
  final VoidCallback onChooseLocation;

  const _HomeHeader({
    required this.location,
    required this.nearYou,
    required this.onChooseLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'KiwiShare',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: AppColors.textBrand),
          ),
        ),
        TextButton.icon(
          key: const Key('home-location-button'),
          onPressed: onChooseLocation,
          icon: Icon(nearYou ? Icons.my_location : Icons.location_on_outlined),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              nearYou ? 'Near you' : location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HomeCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brandPrimaryContainer,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.brandPrimary : AppColors.border,
      ),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
    );
  }
}

class _HomeDiscoveryResults extends StatelessWidget {
  final List<ItemModel> products;
  final ItemModel? selectedItem;
  final HomeDiscoveryProvider filters;
  final VoidCallback onShowFilters;
  final ValueChanged<ItemModel> onOpenProduct;

  const _HomeDiscoveryResults({
    required this.products,
    required this.selectedItem,
    required this.filters,
    required this.onShowFilters,
    required this.onOpenProduct,
  });

  String get _heading {
    if (filters.selectedCategory != 'All') {
      return filters.selectedCategory;
    }
    if (filters.selectedLocation != 'All NZ') {
      return 'Products in ${filters.selectedLocation}';
    }
    return 'Products across NZ';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_heading, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${products.length} items',
              key: const Key('home-results-count'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            OutlinedButton.icon(
              onPressed: onShowFilters,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                filters.activeFilterCount == 0
                    ? 'Sort & filter'
                    : 'Sort & filter (${filters.activeFilterCount})',
              ),
            ),
            _HomeViewToggle(filters: filters),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (filters.view == HomeProductView.map)
          SizedBox(
            height: 400,
            child: HomeProductMap(
              products: products,
              selectedItem: selectedItem,
              userLatitude: filters.userLatitude,
              userLongitude: filters.userLongitude,
              onSelectProduct: (item) => filters.selectPreview(item.id),
              onClearSelection: () => filters.selectPreview(null),
              onOpenProduct: onOpenProduct,
            ),
          )
        else if (products.isEmpty)
          const _HomeEmptyState()
        else
          _HomeProductsGrid(products: products, onOpen: onOpenProduct),
      ],
    );
  }
}

class _HomeViewToggle extends StatelessWidget {
  final HomeDiscoveryProvider filters;

  const _HomeViewToggle({required this.filters});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HomeViewButton(
            key: const Key('home-grid-view-toggle'),
            tooltip: 'Show product grid',
            icon: Icons.grid_view_outlined,
            selected: filters.view == HomeProductView.grid,
            onPressed: () => filters.setView(HomeProductView.grid),
          ),
          _HomeViewButton(
            key: const Key('home-map-view-toggle'),
            tooltip: 'Show product map',
            icon: Icons.map_outlined,
            selected: filters.view == HomeProductView.map,
            onPressed: () => filters.setView(HomeProductView.map),
          ),
        ],
      ),
    );
  }
}

class _HomeViewButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _HomeViewButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: selected
            ? AppColors.brandPrimaryContainer
            : Colors.transparent,
        foregroundColor: AppColors.brandPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _HomeProductsGrid extends StatelessWidget {
  final List<ItemModel> products;
  final ValueChanged<ItemModel> onOpen;

  const _HomeProductsGrid({required this.products, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.74 - (textScale - 1) * 0.18,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return ItemCard(item: item, onTap: () => onOpen(item));
      },
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products across NZ',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.74,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const ItemCardSkeleton(),
        ),
      ],
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _HomeErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: AppSpacing.sm),
          const Text('Could not load products.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: AppColors.brandSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No products match these filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try another category, price range, name, or location.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SustainabilityBanner extends StatelessWidget {
  const _SustainabilityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.eco_outlined,
            color: AppColors.brandPrimary,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Give items a new life.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('Buy local. Reduce waste. Build community.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
