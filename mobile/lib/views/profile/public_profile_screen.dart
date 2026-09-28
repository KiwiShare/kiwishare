import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../models/public_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../repositories/user_repository.dart';
import '../products/product_detail_screen.dart';
import '../shared/widgets/item_card.dart';
import '../../widgets/vip_crown_icon.dart';
import '../../utils/trust_score.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  PublicProfileModel? _profile;
  List<ItemModel> _activeItems = [];
  List<ItemModel> _soldItems = [];
  List<PublicReviewModel> _reviews = [];
  bool _isChatStarting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (widget.userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'User profile not found.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    UserRepository? repo;
    try {
      repo = context.read<UserRepository>();
    } catch (_) {
      repo = context.read<AuthProvider?>()?.userRepository;
    }

    if (repo == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load user profile service.';
        _isLoading = false;
      });
      return;
    }

    final token = context.read<AuthProvider?>()?.jwtToken;

    try {
      final results = await Future.wait([
        repo.fetchPublicProfile(widget.userId, token: token),
        repo.fetchUserPublicItems(
          widget.userId,
          status: 'active',
          token: token,
        ),
        repo.fetchUserPublicItems(widget.userId, status: 'sold', token: token),
        repo.fetchUserPublicReviews(widget.userId, token: token),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as PublicProfileModel;
        _activeItems = results[1] as List<ItemModel>;
        _soldItems = results[2] as List<ItemModel>;
        _reviews = results[3] as List<PublicReviewModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showEditBioSheet() {
    final auth = context.read<AuthProvider>();
    final currentBio = _profile?.bio ?? auth.currentUser?.bio ?? '';
    final controller = TextEditingController(text: currentBio);
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Bio / Signature',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Let buyers and campus members know about you (up to 200 characters).',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: 200,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. UoA 3rd year student. Moving sale near campus! Fast response.',
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            setSheetState(() => isSaving = true);
                            try {
                              await auth.updateBio(text);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              await _loadAll();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bio updated successfully!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                              }
                            } catch (err) {
                              setSheetState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update bio: $err'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Signature',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startChatWithUser() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to chat with this member.'),
        ),
      );
      return;
    }

    if (_activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This user has no active listings available to start chat.',
          ),
        ),
      );
      return;
    }

    setState(() => _isChatStarting = true);
    final chatProvider = context.read<ChatProvider>();
    final token = auth.jwtToken ?? '';

    try {
      final firstItem = _activeItems.first;
      final conversation = await chatProvider.startConversation(
        itemId: firstItem.id,
        token: token,
      );
      if (!mounted) return;
      setState(() => _isChatStarting = false);
      if (conversation != null) {
        context.push('/messages/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChatStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isOwnProfile =
        currentUserId != null && currentUserId == widget.userId;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member Profile'), elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF059669)),
        ),
      );
    }

    if (_errorMessage != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Failed to load user profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = _profile!;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1713)
          : const Color(0xFFF7F8F7),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── App Bar & Hero Header ──
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark
                ? const Color(0xFF13221C)
                : const Color(0xFF059669),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroProfileHeader(
                profile: p,
                isOwnProfile: isOwnProfile,
                onEditBio: _showEditBioSheet,
              ),
            ),
          ),

          // ── Trust Score Card (Xianyu Zhima Credit Style) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _ZhimaTrustScoreCard(
                trustScore: p.trustScore,
                rating: p.rating,
                isStudentVerified: p.isStudentVerified,
                studentInstitution: p.studentInstitution,
                isVerified: p.isVerified,
              ),
            ),
          ),

          // ── Stats Row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _ProfileStatsRow(
                activeCount: p.activeItemsCount,
                soldCount: p.soldItemsCount,
                reviewCount: p.reviewCount,
                rating: p.rating,
              ),
            ),
          ),

          // ── Segmented Tab Header ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF059669),
                indicatorWeight: 3,
                labelColor: isDark ? Colors.white : const Color(0xFF059669),
                unselectedLabelColor: isDark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'Selling (${_activeItems.length})'),
                  Tab(text: 'Reviews (${_reviews.length})'),
                  Tab(text: 'Sold (${_soldItems.length})'),
                ],
              ),
              isDark: isDark,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Selling Items
            _buildItemsGrid(
              _activeItems,
              emptyLabel: 'No items currently on sale',
            ),

            // Tab 2: Reviews
            _buildReviewsList(_reviews),

            // Tab 3: Sold Items
            _buildItemsGrid(
              _soldItems,
              isSoldTab: true,
              emptyLabel: 'No sold items yet',
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isOwnProfile
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18221E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isChatStarting ? null : _startChatWithUser,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isChatStarting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        'Chat with ${p.displayName.split(' ').first}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildItemsGrid(
    List<ItemModel> items, {
    bool isSoldTab = false,
    required String emptyLabel,
  }) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSoldTab
                      ? Icons.shopping_bag_outlined
                      : Icons.inventory_2_outlined,
                  size: 54,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  emptyLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Stack(
          children: [
            ItemCard(
              item: item,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ProductDetailScreen(itemId: item.id, item: item),
                ),
              ),
            ),
            if (isSoldTab)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SOLD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsList(List<PublicReviewModel> reviews) {
    if (reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 54,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No transaction reviews yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return _XianyuReviewCard(review: review);
      },
    );
  }
}

// ── Hero Profile Header Component ──
class _HeroProfileHeader extends StatelessWidget {
  final PublicProfileModel profile;
  final bool isOwnProfile;
  final VoidCallback onEditBio;

  const _HeroProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    final isVip = profile.isVip;
    final initial = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim()[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF047857), Color(0xFF065F46)],
        ),
        image: profile.coverImageUrl?.trim().isNotEmpty == true
            ? DecorationImage(
                image: NetworkImage(profile.coverImageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.28),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with VIP Golden Ring
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isVip
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFFDF00),
                            Color(0xFFF59E0B),
                            Color(0xFFFF9900),
                          ],
                        )
                      : null,
                  border: isVip
                      ? Border.all(color: const Color(0xFFFFDF00), width: 3)
                      : Border.all(color: Colors.white, width: 2.5),
                ),
                child: ClipOval(
                  child:
                      profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                      ? Image.network(
                          profile.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _fallbackAvatar(initial),
                        )
                      : _fallbackAvatar(initial),
                ),
              ),
              const SizedBox(width: 14),

              // Name & Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VipCrownIcon(size: 11),
                                const SizedBox(width: 3),
                                const Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (profile.isStudentVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  profile.studentInstitution ??
                                      'Verified Student',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                profile.locationDescription,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Xianyu Bio / Signature Banner
          GestureDetector(
            onTap: isOwnProfile ? onEditBio : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.bio.isNotEmpty
                          ? profile.bio
                          : (isOwnProfile
                                ? 'Tap to add your signature / bio...'
                                : 'This user hasn\'t set a bio yet.'),
                      style: TextStyle(
                        color: profile.bio.isNotEmpty
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 12,
                        fontStyle: profile.bio.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwnProfile)
                    const Icon(
                      Icons.edit_outlined,
                      color: Colors.white70,
                      size: 14,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String initial) {
    return Container(
      color: const Color(0xFF047857),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Zhima / Xianyu Trust Score Card ──
class _ZhimaTrustScoreCard extends StatelessWidget {
  final int trustScore;
  final double rating;
  final bool isStudentVerified;
  final String? studentInstitution;
  final bool isVerified;

  const _ZhimaTrustScoreCard({
    required this.trustScore,
    required this.rating,
    required this.isStudentVerified,
    this.studentInstitution,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = getTrustScoreInfo(trustScore);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showKiwiTrustScoreSheet(context, trustScore),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15221C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF059669).withOpacity(0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Kiwi Trust Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? info.darkBg : info.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? info.darkColor : info.lightColor)
                          .withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${formatPublicTrustScore(trustScore)} • ${info.label}',
                    style: TextStyle(
                      color: isDark ? info.darkColor : info.lightColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PerkItem(
                  icon: Icons.badge_outlined,
                  label: isVerified ? 'ID Verified' : 'Standard Member',
                  isHighlight: isVerified,
                ),
                _PerkItem(
                  icon: Icons.school_outlined,
                  label: isStudentVerified ? 'NZ Student' : 'Community',
                  isHighlight: isStudentVerified,
                ),
                _PerkItem(
                  icon: Icons.star_rounded,
                  label: '$rating Rating',
                  isHighlight: rating >= 4.5,
                ),
                const _PerkItem(
                  icon: Icons.handshake_outlined,
                  label: 'Safe Handover',
                  isHighlight: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlight;

  const _PerkItem({
    required this.icon,
    required this.label,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isHighlight
        ? const Color(0xFF059669)
        : Colors.grey[500];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: activeColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight
                ? (isDark ? Colors.green[300] : const Color(0xFF059669))
                : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

// ── Profile Stats Row ──
class _ProfileStatsRow extends StatelessWidget {
  final int activeCount;
  final int soldCount;
  final int reviewCount;
  final double rating;

  const _ProfileStatsRow({
    required this.activeCount,
    required this.soldCount,
    required this.reviewCount,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15221C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCol(number: '$activeCount', label: 'Selling'),
          _divider(isDark),
          _StatCol(number: '$soldCount', label: 'Sold'),
          _divider(isDark),
          _StatCol(number: '$reviewCount', label: 'Reviews'),
          _divider(isDark),
          _StatCol(
            number: '${(rating * 20).toInt()}%',
            label: 'Positive',
            numberColor: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }
}

class _StatCol extends StatelessWidget {
  final String number;
  final String label;
  final Color? numberColor;

  const _StatCol({required this.number, required this.label, this.numberColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: numberColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

// ── Xianyu Review Card Component ──
class _XianyuReviewCard extends StatelessWidget {
  final PublicReviewModel review;

  const _XianyuReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBuyer = review.role == 'buyer';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15221C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF059669).withOpacity(0.2),
                backgroundImage: review.reviewerAvatarUrl != null
                    ? NetworkImage(review.reviewerAvatarUrl!)
                    : null,
                child: review.reviewerAvatarUrl == null
                    ? Text(
                        review.reviewerName.isNotEmpty
                            ? review.reviewerName[0]
                            : 'K',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.reviewerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isBuyer
                                ? Colors.blue.withOpacity(0.12)
                                : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isBuyer ? 'Buyer' : 'Seller',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isBuyer
                                  ? Colors.blue[700]
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 13,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Text(
                  '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Comment
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.grey[200] : Colors.black87,
            ),
          ),

          // Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.transparent
                          : const Color(0xFFDCFCE7),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.green[300]
                          : const Color(0xFF15803D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Attached Product Snippet
          if (review.itemTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Transaction: ${review.itemTitle}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab Bar Delegate for Slivers ──
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _SliverTabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: isDark ? const Color(0xFF0F1713) : const Color(0xFFF7F8F7),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || isDark != oldDelegate.isDark;
  }
}
