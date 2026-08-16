import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../search/widgets/filter_chip.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSearch;

  const HomeScreen({super.key, required this.onNavigateToSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<ItemModel>>? _popularItemsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _popularItemsFuture ??= context.read<ListingProvider>().getPopularItems();
  }

  Future<void> _retryFetch() async {
    setState(() {
      _popularItemsFuture = context.read<ListingProvider>().getPopularItems(
        forceRefresh: true,
      );
    });
    await _popularItemsFuture;
  }

  void _openCategory(String category) {
    context.read<SearchProvider>()
      ..setCategory(category)
      ..selectPreview(null);
    widget.onNavigateToSearch();
  }

  void _openLocation() {
    context.read<SearchProvider>().setViewMode(ProductViewMode.map);
    context.go('/search?map=true&nearby=true');
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<SearchProvider>();
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'KiwiShare',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(color: AppColors.textBrand),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('home-location-button'),
                    onPressed: _openLocation,
                    icon: Icon(
                      filters.isNearYou
                          ? Icons.my_location
                          : Icons.location_on_outlined,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        filters.selectedLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                button: true,
                label: 'Search products and open filters',
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: InkWell(
                    key: const Key('home-search-bar'),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    onTap: widget.onNavigateToSearch,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: AppColors.brandPrimary),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text('Search by item name or category'),
                          ),
                          Icon(Icons.tune, color: AppColors.brandPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in SearchProvider.categories) ...[
                      SearchFilterChip(
                        key: Key('home-category-$category'),
                        label: category,
                        active: filters.selectedCategory == category,
                        onTap: () => _openCategory(category),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Popular near you',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToSearch,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See all'),
                        SizedBox(width: AppSpacing.xs),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<ItemModel>>(
                future: _popularItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _HomeProductsGrid.loading();
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48),
                          const SizedBox(height: AppSpacing.sm),
                          const Text('Could not load popular products.'),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: _retryFetch,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final products = snapshot.data ?? const <ItemModel>[];
                  if (products.isEmpty) {
                    return const Text('No popular products yet.');
                  }
                  return _HomeProductsGrid(
                    products: products,
                    onOpen: (item) =>
                        context.push('/items/${item.id}', extra: item),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      color: AppColors.brandPrimary,
                      size: 36,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Give items a new life.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text('Buy local. Reduce waste. Build community.'),
                        ],
                      ),
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
}

class _HomeProductsGrid extends StatelessWidget {
  final List<ItemModel>? products;
  final ValueChanged<ItemModel>? onOpen;
  final bool isLoading;

  const _HomeProductsGrid({required this.products, required this.onOpen})
    : isLoading = false;

  const _HomeProductsGrid.loading()
    : products = null,
      onOpen = null,
      isLoading = true;

  @override
  Widget build(BuildContext context) {
    final count = isLoading ? 4 : products!.length;
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
      itemCount: count,
      itemBuilder: (context, index) {
        if (isLoading) return const ItemCardSkeleton();
        final item = products![index];
        return ItemCard(item: item, onTap: () => onOpen!(item));
      },
    );
  }
}
