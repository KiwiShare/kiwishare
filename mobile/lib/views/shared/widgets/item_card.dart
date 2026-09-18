import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/providers.dart';
import '../../../services/notification_permission_coordinator.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;
  final NotificationPermissionCoordinator? permissionCoordinator;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(item.id);

    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, price: \$${item.priceNzd} NZD, approximate location: ${item.location}, category: ${item.category}',
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? colors.outline.withOpacity(0.18)
                : colors.outline.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Photo Section with Overlays
                AspectRatio(
                  aspectRatio: 1.38,
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
                            size: 34,
                          ),
                        ),
                      ),
                      // Top Left: Non-active Status Badge
                      if (item.status != ItemStatus.active)
                        Positioned(
                          left: 7,
                          top: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item.status == ItemStatus.reserved
                                  ? 'RESERVED'
                                  : 'SOLD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      // Top Right: Favorite Button
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Material(
                          color: Colors.black.withOpacity(0.35),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                unawaited(_toggleFavorite(context, favorites)),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: isFavorite
                                    ? const Color(0xFFEF4444)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom Left: Category & Condition Glass Pill
                      Positioned(
                        left: 7,
                        right: item.allImages.length > 1 ? 40 : 7,
                        bottom: 7,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _formatCategoryCondition(
                                item.category,
                                item.condition,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      // Bottom Right: Multi-photo Indicator
                      if (item.allImages.length > 1)
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_outlined,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  '${item.allImages.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Info & Details Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (item.isFree) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '\$0 NZD',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ] else ...[
                            Flexible(
                              child: Text(
                                '\$${item.priceNzd}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2.5),
                            Text(
                              'NZD',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: colors.primary.withOpacity(0.75),
                              ),
                            ),
                          ],
                          if (item.watchlistCount > 0) ...[
                            const Spacer(),
                            const Icon(
                              Icons.favorite,
                              size: 11,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.watchlistCount}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1.5),

                      // Location Row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.location,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Title (up to 2 lines)
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: colors.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Seller Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 7.5,
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
                                    (item.seller?.displayName.isNotEmpty ==
                                            true)
                                        ? item.seller!.displayName[0]
                                              .toUpperCase()
                                        : 'K',
                                    style: TextStyle(
                                      fontSize: 7.5,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.seller?.displayName ?? 'Kiwi Seller',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurface.withOpacity(0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.seller?.isStudentVerified == true) ...[
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.verified,
                                    size: 11,
                                    color: Color(0xFF2563EB),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Badges Under the User Row
                      if (item.isSustainable ||
                          item.seller?.isStudentVerified == true) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (item.isSustainable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF064E3B).withOpacity(0.4)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(
                                            0xFF059669,
                                          ).withOpacity(0.5)
                                        : const Color(0xFFA5D6A7),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.eco_rounded,
                                      size: 10.5,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 2.5),
                                    Flexible(
                                      child: Text(
                                        'Sustainable',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF6EE7B7)
                                              : const Color(0xFF15803D),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (item.seller?.isStudentVerified == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A).withOpacity(0.4)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(
                                            0xFF3B82F6,
                                          ).withOpacity(0.5)
                                        : const Color(0xFF93C5FD),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 10.5,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 2.5),
                                    Flexible(
                                      child: Text(
                                        'Verified Student',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFF1D4ED8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCategoryCondition(String category, String? condition) {
    final cat = _formatLabel(category);
    if (condition == null || condition.trim().isEmpty) return cat;
    final cond = _formatLabel(condition);
    return '$cat • $cond';
  }

  String _formatLabel(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'[_\s]+'))
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
