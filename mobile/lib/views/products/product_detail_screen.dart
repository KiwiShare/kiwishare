import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_theme.dart';

class ProductDetailScreen extends StatelessWidget {
  final ItemModel? item;

  const ProductDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final product = item;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product details',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: product == null
            ? null
            : [
                Consumer<FavoritesProvider>(
                  builder: (context, favorites, _) {
                    final saved = favorites.isFavorite(product.id);
                    return IconButton(
                      key: const Key('detail-favorite-button'),
                      tooltip: saved ? 'Remove from saved items' : 'Save item',
                      onPressed: () => favorites.toggleFavorite(product.id),
                      icon: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        color: saved ? AppColors.error : null,
                      ),
                    );
                  },
                ),
              ],
      ),
      body: product == null
          ? const _UnavailableProduct()
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 56,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '\$${product.priceNzd} NZD',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.textBrand),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        product.description.isEmpty
                            ? 'No description supplied.'
                            : product.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Item details',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Approximate location',
                        value: product.location,
                      ),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: product.category,
                      ),
                      _DetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Status',
                        value: _statusLabel(product.status),
                      ),
                      if (product.isSustainable)
                        const _DetailRow(
                          icon: Icons.eco_outlined,
                          label: 'Sustainability',
                          value: 'Pre-loved item',
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

String _statusLabel(ItemStatus status) => switch (status) {
  ItemStatus.active => 'Available',
  ItemStatus.reserved => 'Reserved',
  ItemStatus.sold => 'Sold',
};

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brandPrimary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}

class _UnavailableProduct extends StatelessWidget {
  const _UnavailableProduct();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Product unavailable',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Return to Products and choose an available item.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
