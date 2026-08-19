import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../services/remote_config_service.dart';
import '../item_detail/item_detail_screen.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/category_navigation_button.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSearch;

  const HomeScreen({super.key, required this.onNavigateToSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ItemModel>> _popularItemsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _popularItemsFuture = Provider.of<ListingProvider>(
      context,
      listen: false,
    ).getPopularItems();
  }

  void _retryFetch() {
    setState(() {
      _popularItemsFuture = Provider.of<ListingProvider>(
        context,
        listen: false,
      ).getPopularItems(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _retryFetch();
            await _popularItemsFuture;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Notification Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KiwiShare',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E5E4E), // Sage Green logo
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: 28,
                        color: Color(0xFF2E5E4E), // Sage Green actions
                      ),
                      onPressed: () {},
                      tooltip: 'Notifications',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Remote Config: Dynamic Announcement Banner (Promotions, Events)
                Builder(
                  builder: (context) {
                    final banner = RemoteConfigService.instance.getJson(
                      'announcement_banner',
                    );
                    final isEnabled = banner['enabled'] == true;
                    final message = banner['message']?.toString() ?? '';

                    if (isEnabled && message.isNotEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F0D9), // Light Green
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF7BAA7A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFF2E5E4E),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                message,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E5E4E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Greeting Section - reactively bound to AppState login status
                isLoggedIn && currentUser != null
                    ? Semantics(
                        label: 'Greeting',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kia ora, ${currentUser.displayName}!',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F1F1F), // Charcoal
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find great things, close to home.',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(
                                  0xFF1F1F1F,
                                ).withOpacity(0.6), // Charcoal opacity
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kia ora, Kiwi!',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F1F1F), // Charcoal
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find great things, close to home.',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(
                                0xFF1F1F1F,
                              ).withOpacity(0.6), // Charcoal opacity
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // Search Box Redirecting to Search tab
                GestureDetector(
                  onTap: widget.onNavigateToSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2), // Off-White inside
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(
                          0xFF2E5E4E,
                        ).withOpacity(0.2), // Light green border
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F1F1F).withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(0xFF2E5E4E), // Sage Green
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search for items or categories',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1F1F1F).withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.tune,
                          color: Color(0xFF2E5E4E), // Sage Green
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Navigation Categories Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CategoryNavigationButton(
                      label: 'For You',
                      icon: Icons.home,
                      isActive: true,
                      onTap: () {},
                    ),
                    CategoryNavigationButton(
                      label: 'Categories',
                      icon: Icons.grid_view,
                      isActive: false,
                      onTap: () {},
                    ),
                    CategoryNavigationButton(
                      label: 'Nearby',
                      icon: Icons.location_on_outlined,
                      isActive: false,
                      onTap: () {},
                    ),
                    CategoryNavigationButton(
                      label: 'Saved',
                      icon: Icons.favorite_border,
                      isActive: false,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Popular Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popular near you',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onNavigateToSearch,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'See all',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E5E4E), // Sage Green
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Color(0xFF2E5E4E),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Popular Items Grid
                FutureBuilder<List<ItemModel>>(
                  future: _popularItemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.76,
                            ),
                        itemCount: 4,
                        itemBuilder: (context, index) =>
                            const ItemCardSkeleton(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off,
                                size: 48,
                                color: Color(0xFF2E5E4E),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Error loading popular listings',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F1F1F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Please check your network and try again.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(
                                    0xFF1F1F1F,
                                  ).withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _retryFetch,
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
                        return const Center(
                          child: Text('No popular items found.'),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.76,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ItemCard(
                            item: item,
                            onTap: () => openItemDetail(context, item),
                          );
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Environmental Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F0D9), // Light sustainable green
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA2D091).withOpacity(0.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {},
                    child: Row(
                      children: [
                        const Icon(
                          Icons.spa,
                          color: Color(0xFF3E8E41),
                          size: 36,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Give items a new life.',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F1F1F),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buy local. Reduce waste. Build community.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(
                                    0xFF1F1F1F,
                                  ).withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF1F1F1F),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
