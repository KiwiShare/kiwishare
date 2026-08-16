import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(item.id);

    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, \$${item.priceNzd} NZD, ${item.location}, ${item.category}',
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.surfaceMuted,
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.brandPrimary,
                              size: 40,
                            ),
                      ),
                    ),
                    if (item.isSustainable)
                      Positioned(
                        left: AppSpacing.sm,
                        top: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text('Sustainable'),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      right: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: IconButton.filledTonal(
                        tooltip: isFavorite
                            ? 'Remove from saved items'
                            : 'Save item',
                        onPressed: () => favorites.toggleFavorite(item.id),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '\$${item.priceNzd} NZD',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item.location,
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
