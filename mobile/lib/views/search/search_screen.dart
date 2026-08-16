import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../services/product_location_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/app_theme.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/filter_chip.dart';
import 'widgets/product_filter_sheet.dart';
import 'widgets/product_map_view.dart';
import 'widgets/product_preview_card.dart';

class SearchScreen extends StatefulWidget {
  final ProductLocationService? locationService;
  final ValueChanged<ItemModel>? onOpenItem;
  final bool requestNearby;
  final bool openMap;

  const SearchScreen({
    super.key,
    this.locationService,
    this.onOpenItem,
    this.requestNearby = false,
    this.openMap = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final ProductLocationService _locationService;
  Timer? _debounce;
  Future<List<ItemModel>>? _productsFuture;
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
    _initialized = true;
    final filters = context.read<SearchProvider>();
    _searchController.text = filters.query;
    if (widget.openMap) filters.setViewMode(ProductViewMode.map);
    if (widget.requestNearby) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLocationPicker();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ItemModel>> _loadProducts(ListingProvider provider) {
    return _productsFuture ??= provider.searchListingItems('', 'All');
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) context.read<SearchProvider>().setQuery(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<SearchProvider>().setQuery('');
    setState(() {});
  }

  List<ItemModel> _applyFilters(
    List<ItemModel> source,
    SearchProvider filters,
  ) {
    final query = filters.query.toLowerCase();
    final products = source.where((item) {
      final queryMatches =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      final categoryMatches =
          filters.selectedCategory == 'All' ||
          item.category.toLowerCase() ==
              filters.selectedCategory.toLowerCase() ||
          (filters.selectedCategory == 'Transport' &&
              item.category.toLowerCase() == 'vehicle');
      final locationMatches =
          filters.selectedLocation == 'All NZ' ||
          item.location.toLowerCase().contains(
            filters.selectedLocation.toLowerCase(),
          );
      final sustainabilityMatches =
          !filters.sustainableOnly || item.isSustainable;
      final minimumMatches =
          filters.minimumPrice == null ||
          item.numericPrice >= filters.minimumPrice!;
      final maximumMatches =
          filters.maximumPrice == null ||
          item.numericPrice <= filters.maximumPrice!;
      return queryMatches &&
          categoryMatches &&
          locationMatches &&
          sustainabilityMatches &&
          minimumMatches &&
          maximumMatches;
    }).toList();

    switch (filters.selectedSort) {
      case ProductSort.recommended:
        break;
      case ProductSort.priceLowToHigh:
        products.sort((a, b) => a.numericPrice.compareTo(b.numericPrice));
      case ProductSort.priceHighToLow:
        products.sort((a, b) => b.numericPrice.compareTo(a.numericPrice));
    }
    return products;
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      context.read<SearchProvider>()
        ..setLocation(
          location.city,
          nearYou: true,
          latitude: location.latitude,
          longitude: location.longitude,
        )
        ..setViewMode(ProductViewMode.map);
    } on ProductLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your location is unavailable. Choose a city to keep browsing.',
          ),
        ),
      );
    }
  }

  Future<void> _showLocationPicker() async {
    final filters = context.read<SearchProvider>();
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
                'Choose location',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('near-you-option'),
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
            for (final location in SearchProvider.locations)
              ListTile(
                leading: Icon(
                  location == 'All NZ' ? Icons.public : Icons.location_city,
                ),
                title: Text(location),
                trailing:
                    filters.selectedLocation == location && !filters.isNearYou
                    ? const Icon(Icons.check, color: AppColors.brandPrimary)
                    : null,
                onTap: () {
                  filters.setLocation(location);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSortPicker() async {
    final filters = context.read<SearchProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort products',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            for (final sort in ProductSort.values)
              RadioListTile<ProductSort>(
                value: sort,
                groupValue: filters.selectedSort,
                title: Text(sort.label),
                onChanged: (value) {
                  if (value != null) filters.setSort(value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProductFilterSheet(filters: context.read<SearchProvider>()),
  );

  void _openProduct(ItemModel item) {
    if (widget.onOpenItem != null) {
      widget.onOpenItem!(item);
      return;
    }
    context.push('/items/${item.id}', extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<SearchProvider>();
    final listingProvider = context.read<ListingProvider>();
    final aiSearchEnabled = should(FeatureFlag.aiSearch);

    return PopScope(
      canPop: filters.previewItemId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && filters.previewItemId != null) {
          filters.selectPreview(null);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Products',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('products-location-button'),
                      onPressed: _showLocationPicker,
                      icon: Icon(
                        filters.isNearYou
                            ? Icons.my_location
                            : Icons.location_on_outlined,
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 128),
                        child: Text(
                          filters.isNearYou
                              ? 'Near you · ${filters.selectedLocation}'
                              : filters.selectedLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  key: const Key('products-search-field'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search products',
                    hintText: 'Search by item name or category',
                    prefixIcon: Icon(
                      aiSearchEnabled ? Icons.auto_awesome : Icons.search,
                    ),
                    helperText: aiSearchEnabled
                        ? 'Smart search is on; regular keyword search remains available.'
                        : null,
                    suffixIcon: _searchController.text.isEmpty
                        ? IconButton(
                            key: const Key('search-filter-button'),
                            tooltip: 'Price and sustainability filters',
                            onPressed: _showFilters,
                            icon: Icon(
                              Icons.tune,
                              color: filters.hasActiveFilters
                                  ? AppColors.brandAccent
                                  : AppColors.brandPrimary,
                            ),
                          )
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    for (final category in SearchProvider.categories) ...[
                      SearchFilterChip(
                        key: Key('category-$category'),
                        label: category,
                        active: filters.selectedCategory == category,
                        onTap: () => filters.toggleCategory(category),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    SearchFilterChip(
                      key: const Key('list-view-toggle'),
                      label: 'List',
                      active: filters.viewMode == ProductViewMode.list,
                      onTap: () => filters.setViewMode(ProductViewMode.list),
                      icon: Icons.view_module_outlined,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SearchFilterChip(
                      key: const Key('map-view-toggle'),
                      label: 'Map',
                      active: filters.viewMode == ProductViewMode.map,
                      onTap: () => filters.setViewMode(ProductViewMode.map),
                      icon: Icons.map_outlined,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SearchFilterChip(
                      label: 'Sort: ${filters.selectedSort.label}',
                      active: filters.selectedSort != ProductSort.recommended,
                      onTap: _showSortPicker,
                      icon: Icons.sort,
                      showDropdown: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SearchFilterChip(
                      label: 'Filters',
                      active:
                          filters.minimumPrice != null ||
                          filters.maximumPrice != null ||
                          filters.sustainableOnly,
                      onTap: _showFilters,
                      icon: Icons.tune,
                    ),
                    if (filters.hasActiveFilters) ...[
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: filters.resetFilters,
                        child: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ItemModel>>(
                  future: _loadProducts(listingProvider),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ProductsLoadingGrid();
                    }
                    if (snapshot.hasError) {
                      return _ProductsMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load products',
                        message: 'Check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: () => setState(() => _productsFuture = null),
                      );
                    }

                    final products = _applyFilters(
                      snapshot.data ?? const [],
                      filters,
                    );
                    if (products.isEmpty) {
                      return const _ProductsMessage(
                        icon: Icons.search_off,
                        title: 'No products found',
                        message:
                            'Try another name, category, price, or location.',
                      );
                    }
                    final selectedItem = products
                        .where((item) => item.id == filters.previewItemId)
                        .firstOrNull;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: filters.viewMode == ProductViewMode.map
                              ? ProductMapView(
                                  products: products,
                                  selectedItemId: filters.previewItemId,
                                  userLatitude: filters.userLatitude,
                                  userLongitude: filters.userLongitude,
                                  onSelectProduct: (item) =>
                                      filters.selectPreview(item.id),
                                  onClearSelection: () =>
                                      filters.selectPreview(null),
                                )
                              : _ProductsGrid(
                                  products: products,
                                  nearYou: filters.isNearYou,
                                  onSelectProduct: (item) =>
                                      filters.selectPreview(item.id),
                                ),
                        ),
                        if (selectedItem != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ProductPreviewCard(
                              item: selectedItem,
                              onOpen: () => _openProduct(selectedItem),
                              onClose: () => filters.selectPreview(null),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final List<ItemModel> products;
  final bool nearYou;
  final ValueChanged<ItemModel> onSelectProduct;

  const _ProductsGrid({
    required this.products,
    required this.nearYou,
    required this.onSelectProduct,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
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
            nearYou
                ? 'Items near you · ${products.length}'
                : 'Available products · ${products.length}',
            style: Theme.of(context).textTheme.headlineMedium,
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
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.74 - (textScale - 1) * 0.18,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ItemCard(
              item: products[index],
              onTap: () => onSelectProduct(products[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductsLoadingGrid extends StatelessWidget {
  const _ProductsLoadingGrid();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(AppSpacing.lg),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.74,
    ),
    itemCount: 6,
    itemBuilder: (_, _) => const ItemCardSkeleton(),
  );
}

class _ProductsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ProductsMessage({
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
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
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
