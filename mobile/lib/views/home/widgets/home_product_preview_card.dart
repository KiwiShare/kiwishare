import 'package:flutter/material.dart';

import '../../../models/item_model.dart';
import '../../../services/notification_permission_coordinator.dart';
import '../../../theme/app_theme.dart';
import '../../shared/widgets/watchlist_heart_button.dart';

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

  @override
  Widget build(BuildContext context) {
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
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: WatchlistHeartButton(
                        key: const Key('home-preview-favorite-button'),
                        item: item,
                        permissionCoordinator: permissionCoordinator,
                        diameter: 28,
                        iconSize: 15,
                      ),
                    ),
                  ],
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
