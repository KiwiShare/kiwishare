import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/item_model.dart';
import '../../../providers/app_state.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isFav = appState.isFavorite(item.id);

    return Semantics(
      label: '${item.title}, price: \$${item.priceNzd} NZD, location: ${item.location}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFF), // Cream Surface
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2D5B).withOpacity(0.06),
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
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF6E7FBF).withOpacity(0.15),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF6E7FBF),
                              size: 32,
                            ),
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
                          color: const Color(0xFF1F2D5B),
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
                          color: const Color(0xFF3F6FD9), // Cobalt Blue
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Color(0xFF6E7FBF)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.location,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF6E7FBF),
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

            // Sustainable Badge (Bottom-left of image area)
            if (item.isSustainable)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F0D9).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA2D091)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco, size: 12, color: Color(0xFF3E8E41)),
                      const SizedBox(width: 4),
                      Text(
                        'Sustainable',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3E8E41),
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
                    appState.toggleFavorite(item.id);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedScale(
                      scale: isFav ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : const Color(0xFF6E7FBF),
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
    );
  }
}
