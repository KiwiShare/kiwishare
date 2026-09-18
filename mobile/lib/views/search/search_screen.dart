import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../models/item_model.dart';
import '../../services/remote_config_service.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/filter_chip.dart';
import 'widgets/category_picker_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  String _currentQuery = 'Camping'; // Default query from the mockup

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _currentQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentQuery = value;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const CategoryPickerSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchProvider = Provider.of<SearchProvider>(context);
    final listingProvider = Provider.of<ListingProvider>(context);
    final activeCategory = searchProvider.selectedCategory;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: colors.primary,
                      size: 28,
                    ),
                    onPressed: () {},
                    tooltip: 'Back',
                  ),
                  Text(
                    'Search',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, color: colors.primary, size: 28),
                    onPressed: () {},
                    tooltip: 'Tune',
                  ),
                ],
              ),
            ),

            // Search Bar Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: colors.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: colors.primary),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          )
                        : null,
                    hintText: 'Search for items or categories',
                    hintStyle: GoogleFonts.inter(
                      color: colors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: GoogleFonts.inter(
                    color: colors.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // Filters Horizontal Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SearchFilterChip(
                    label: 'All NZ',
                    active: false,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  SearchFilterChip(
                    label: 'Category: $activeCategory',
                    active: activeCategory != 'All NZ',
                    onTap: _showCategoryPicker,
                  ),
                  if (should(FeatureFlag.aiSearch)) ...[
                    const SizedBox(width: 8),
                    SearchFilterChip(
                      label: '✨ AI Match',
                      active: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'AI Semantic Matching active for this search.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                  if (should(FeatureFlag.itemDelivery)) ...[
                    const SizedBox(width: 8),
                    SearchFilterChip(
                      label: '🚚 Courier Delivery',
                      active: false,
                      onTap: () {},
                    ),
                  ],
                  const SizedBox(width: 8),
                  SearchFilterChip(
                    label: 'Sort: Popular',
                    active: false,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  SearchFilterChip(
                    label: 'Save',
                    active: false,
                    onTap: () {},
                    icon: Icons.favorite_border,
                  ),
                ],
              ),
            ),

            // Grid results & Loaders via FutureBuilder
            Expanded(
              child: FutureBuilder<List<ItemModel>>(
                future: listingProvider.searchListingItems(
                  _currentQuery,
                  activeCategory,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    final textScale = MediaQuery.textScalerOf(
                      context,
                    ).scale(1).clamp(1, 2);
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.60 - (textScale - 1) * 0.20,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) => const ItemCardSkeleton(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colors.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error matching results',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5E4E),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(120, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tap to Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No listings found',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search filters or searching for something else.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: colors.onSurfaceVariant,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(
                            '${items.length} results',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1).clamp(1, 2);
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio:
                                          0.58 - (textScale - 1) * 0.20,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return ItemCard(item: items[index]);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Safe shopping banner at the bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.03,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: colors.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shop safely, meet locally.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose public places and build trust.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
