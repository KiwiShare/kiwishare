import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../../auth/login_view.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(item.id);

    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, price: \$${item.priceNzd} NZD, approximate location: ${item.location}, category: ${item.category}',
      child: Material(
        color: colors.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.primary,
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
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                            border: Border.all(color: colors.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Sustainable',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '\$${item.priceNzd} NZD',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.seller?.isStudentVerified == true) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: 'Student Verified',
                            child: Icon(
                              Icons.school,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 7,
                          backgroundColor:
                              item.seller?.isStudentVerified == true
                              ? const Color(0xFFDBEAFE)
                              : colors.primaryContainer,
                          backgroundImage:
                              item.seller?.avatarUrl != null &&
                                  item.seller!.avatarUrl!.isNotEmpty
                              ? NetworkImage(item.seller!.avatarUrl!)
                              : null,
                          child:
                              item.seller?.avatarUrl == null ||
                                  item.seller!.avatarUrl!.isEmpty
                              ? Text(
                                  (item.seller?.displayName.isNotEmpty == true)
                                      ? item.seller!.displayName[0]
                                            .toUpperCase()
                                      : 'K',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        item.seller?.isStudentVerified == true
                                        ? const Color(0xFF1D4ED8)
                                        : colors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.seller?.displayName ?? item.location,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
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
