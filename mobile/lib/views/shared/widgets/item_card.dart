import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/item_model.dart';
import '../../../services/notification_permission_coordinator.dart';
import '../../../widgets/resilient_network_image.dart';
import 'watchlist_heart_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, price: \$${item.priceNzd} NZD, approximate location: ${item.location}, category: ${item.category}',
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE5E7EB),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : const Color(0x0C000000),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: colors.primary.withOpacity(0.08),
            highlightColor: colors.primary.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Photo Section with Overlays
                AspectRatio(
                  aspectRatio: 1.20,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base Image with Gradient Fallback
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF282E39),
                                    const Color(0xFF1F242D),
                                  ]
                                : [
                                    const Color(0xFFF3F4F6),
                                    const Color(0xFFE5E7EB),
                                  ],
                          ),
                        ),
                        child: item.imageUrl.isNotEmpty
                            ? ResilientNetworkImage(
                                url: item.imageUrl,
                                logicalCacheWidth: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: colors.onSurfaceVariant
                                            .withOpacity(0.4),
                                        size: 28,
                                      ),
                                    ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: colors.onSurfaceVariant.withOpacity(
                                    0.4,
                                  ),
                                  size: 28,
                                ),
                              ),
                      ),

                      // Top Scrim for pill contrast
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.38),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom Scrim for pill contrast
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.42),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Top Left: Status Badge or Promoted TOP Badge
                      if (item.status != ItemStatus.active)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE6111827),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              item.status == ItemStatus.reserved
                                  ? 'RESERVED'
                                  : 'SOLD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      else if (item.isPromoted)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFD97706,
                                  ).withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.rocket_launch_rounded,
                                  size: 10.5,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 3.5),
                                Text(
                                  'TOP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Top Right: Favorite Button
                      Positioned(
                        right: 8,
                        top: 8,
                        child: WatchlistHeartButton(
                          item: item,
                          permissionCoordinator: permissionCoordinator,
                        ),
                      ),

                      // Bottom Left: Category & Condition Glass Pill
                      Positioned(
                        left: 8,
                        right: item.allImages.length > 1 ? 44 : 8,
                        bottom: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.5,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x99000000),
                              borderRadius: BorderRadius.circular(6),
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
                                letterSpacing: 0.1,
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
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x99000000),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_outlined,
                                  size: 10.5,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
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
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
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
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
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
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'NZD',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Location Row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: colors.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 2.5),
                          Expanded(
                            child: Text(
                              item.location,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.5),

                      // Title (up to 2 lines)
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Seller Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 7.5,
                            backgroundColor:
                                item.seller?.isStudentVerified == true
                                ? const Color(0xFFDBEAFE)
                                : (isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFF1F5F9)),
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
                                          : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF475569)),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4.5),
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
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.seller?.isStudentVerified == true) ...[
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.verified,
                                    size: 11.5,
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
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.isSustainable)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF064E3B,
                                          ).withOpacity(0.4)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(
                                              0xFF059669,
                                            ).withOpacity(0.4)
                                          : const Color(0xFFA7F3D0),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.eco_rounded,
                                        size: 10,
                                        color: Color(0xFF059669),
                                      ),
                                      SizedBox(width: 2.5),
                                      Text(
                                        'Sustainable',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (item.isSustainable &&
                                  item.seller?.isStudentVerified == true)
                                const SizedBox(width: 4),
                              if (item.seller?.isStudentVerified == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF1E3A8A,
                                          ).withOpacity(0.4)
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(
                                              0xFF2563EB,
                                            ).withOpacity(0.4)
                                          : const Color(0xFFBFDBFE),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        size: 10,
                                        color: Color(0xFF2563EB),
                                      ),
                                      SizedBox(width: 2.5),
                                      Text(
                                        'Verified Student',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
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
