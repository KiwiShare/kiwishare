import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/item_model.dart';
import 'home_screen.dart'; // To reuse ItemCard and ItemCardSkeleton

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
      backgroundColor: const Color(0xFFFAFBFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final appState = Provider.of<AppState>(context);
        final activeCategory = appState.selectedCategory;
        final categories = ['All NZ', 'Camping', 'Plants', 'Furniture', 'Transport'];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Category',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2D5B),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == activeCategory;

                    return ListTile(
                      title: Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF3F6FD9) : const Color(0xFF1F2D5B),
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF3F6FD9)) : null,
                      onTap: () {
                        appState.setCategory(cat);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final activeCategory = appState.selectedCategory;

    return Scaffold(
      backgroundColor: const Color(0xFFD9E6F8), // Sky Blue background
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.arrow_back, color: Color(0xFF1F2D5B), size: 28),
                  Text(
                    'Search',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2D5B),
                    ),
                  ),
                  const Icon(Icons.tune, color: Color(0xFF1F2D5B), size: 28),
                ],
              ),
            ),

            // Search Bar Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F2D5B).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6E7FBF)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF6E7FBF)),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          )
                        : null,
                    hintText: 'Search for items or categories',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF6E7FBF)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: GoogleFonts.inter(color: const Color(0xFF1F2D5B), fontSize: 16),
                ),
              ),
            ),

            // Filters Horizontal Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All NZ', active: false),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Category: $activeCategory',
                    active: activeCategory != 'All NZ',
                    onTap: _showCategoryPicker,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Sort: Popular', active: false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Save', active: false, icon: Icons.favorite_border),
                ],
              ),
            ),

            // Grid results & Loaders via FutureBuilder
            Expanded(
              child: FutureBuilder<List<ItemModel>>(
                future: appState.searchListingItems(_currentQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.76,
                      ),
                      itemCount: 6, // Render 6 ItemCardSkeleton placeholders
                      itemBuilder: (context, index) => const ItemCardSkeleton(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Error matching results',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2D5B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {}); // Refresh Search Query Future
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F6FD9),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(120, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              const Icon(Icons.search_off, size: 64, color: Color(0xFF6E7FBF)),
                              const SizedBox(height: 16),
                              Text(
                                'No listings found',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2D5B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search filters or searching for something else.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF6E7FBF),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            '${items.length} results',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2D5B).withOpacity(0.8),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.76,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return ItemCard(item: items[index]);
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
                  color: const Color(0xFFFAFBFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6E7FBF).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F2D5B).withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF3F6FD9), size: 28),
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
                              color: const Color(0xFF1F2D5B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose public places and build trust.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6E7FBF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF6E7FBF)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool active, VoidCallback? onTap, IconData? icon}) {
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3F6FD9) : const Color(0xFFFAFBFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? const Color(0xFF3F6FD9) : const Color(0xFF6E7FBF).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: active ? Colors.white : const Color(0xFF1F2D5B)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFF1F2D5B),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: active ? Colors.white : const Color(0xFF6E7FBF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
