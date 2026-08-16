import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/favorites_provider.dart';
import '../../../theme/app_theme.dart';

class ProductPreviewCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const ProductPreviewCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(item.id);
    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        key: const Key('product-preview-card'),
        color: AppColors.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(AppRadius.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '\$${item.priceNzd} NZD · ${item.location}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.description.isEmpty
                            ? 'Tap for the full product details.'
                            : item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Close product preview',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      key: const Key('preview-favorite-button'),
                      tooltip: isFavorite
                          ? 'Remove from saved items'
                          : 'Save item',
                      onPressed: () => favorites.toggleFavorite(item.id),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? AppColors.error
                            : AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
