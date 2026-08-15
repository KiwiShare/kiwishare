import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/item_model.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(item.id);

    // Seed mock ratings based on item titles to match screenshots
    String rating = '4.9';
    if (item.title.contains('Desk')) rating = '4.9';
    if (item.title.contains('Chair')) rating = '4.8';
    if (item.title.contains('Lamp')) rating = '4.9';
    if (item.title.contains('Bookcase')) rating = '4.7';

    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, price: \$${item.priceNzd} NZD, location: ${item.location}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF1F1F1F,
                  ).withOpacity(0.06), // Charcoal shadow
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Item details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: const Color(
                          0xFFF2E8DB,
                        ), // Warm Beige image background
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(
                                  0xFF2E5E4E,
                                ), // Sage Green placeholder icon
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Text detail section
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1F1F1F), // Charcoal
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${item.priceNzd}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF1F1F1F), // Charcoal
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.distanceKm == null
                                ? item.location
                                : '${item.distanceKm!.toStringAsFixed(1)} km away - ${item.location}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(
                                0xFF1F1F1F,
                              ).withOpacity(0.6), // Charcoal opacity
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Color(0xFFD4A24A), // Muted Gold
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rating,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD4A24A), // Muted Gold
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Sustainable Badge (Bottom-left of image area)
                if (item.isSustainable)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFE2F0D9,
                        ).withOpacity(0.95), // Light Green
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF7BAA7A),
                        ), // Leaf Green border
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco,
                            size: 12,
                            color: Color(0xFF2E5E4E),
                          ), // Sage Green icon
                          const SizedBox(width: 4),
                          Text(
                            'Sustainable',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E5E4E), // Sage Green text
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Favorite Button (Top right of image area)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        favoritesProvider.toggleFavorite(item.id);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedScale(
                          scale: isFav ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav
                                ? Colors.red
                                : const Color(0xFF2E5E4E), // Sage Green outline
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
