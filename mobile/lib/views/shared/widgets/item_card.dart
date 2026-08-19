import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/item_model.dart';
import '../../../providers/providers.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(item.id);
    final colors = Theme.of(context).colorScheme;

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('item_card_${item.id}'),
            onTap: onTap,
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
                        color: colors.surfaceContainerHighest,
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: colors.primary,
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
                              color: colors.onSurface,
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
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.location,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: colors.onSurface.withOpacity(0.6),
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
                        color: colors.primaryContainer.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.primary),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.eco, size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Sustainable',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.onPrimaryContainer,
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surface.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedScale(
                          scale: isFav ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : colors.primary,
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
