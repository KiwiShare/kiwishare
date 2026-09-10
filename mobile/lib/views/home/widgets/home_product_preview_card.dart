import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/watchlist_provider.dart';
import '../../../services/notification_permission_coordinator.dart';
import '../../../theme/app_theme.dart';

class HomeProductPreviewCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final NotificationPermissionCoordinator? permissionCoordinator;

  const HomeProductPreviewCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onClose,
    this.permissionCoordinator,
  });

  Future<void> _toggleFavorite(
    BuildContext context,
    FavoritesProvider favorites,
  ) async {
    WatchlistMutationResult result;
    try {
      result = await favorites.toggleFavorite(item.id);
    } catch (error) {
      debugPrint('Watchlist update failed: $error');
      return;
    }
    if (!context.mounted || result != WatchlistMutationResult.added) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await offerContextualNotificationPermission(
      context,
      coordinator: permissionCoordinator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(item.id);
    return Material(
      key: const Key('home-product-preview-card'),
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('home-preview-open'),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: SizedBox(
                  width: 88,
                  height: 88,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description.isEmpty
                          ? 'Tap to view product details.'
                          : item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Close product preview',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    key: const Key('home-preview-favorite-button'),
                    tooltip: isFavorite
                        ? 'Remove from saved items'
                        : 'Save item',
                    onPressed: () =>
                        unawaited(_toggleFavorite(context, favorites)),
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
    );
  }
}
