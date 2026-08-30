import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorites_provider.dart';
import '../../../theme/app_theme.dart';
import '../../auth/login_view.dart';

class HomeProductPreviewCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const HomeProductPreviewCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onClose,
  });

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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceMuted,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
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
                    onPressed: () {
                      final auth = context.read<AuthProvider?>();
                      if (auth != null && !auth.isLoggedIn) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const LoginView(),
                        );
                        return;
                      }
                      favorites.toggleFavorite(item.id, item);
                    },
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
