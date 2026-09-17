import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/discovery_options_model.dart';
import '../../models/item_model.dart';
import '../../models/report_draft.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/item_repository.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../theme/app_theme.dart';
import '../auth/login_view.dart';
import '../messages/widgets/schedule_meetup_sheet.dart';
import '../profile/report_screen.dart';
import '../shared/widgets/edit_item_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  final String? itemId;
  final ItemModel? item;
  final ItemRepository? itemRepository;
  final ChatProvider? chatProvider;
  final String? authToken;
  final String? currentUserId;
  final ValueChanged<ChatConversationModel>? onConversationOpened;
  final VoidCallback? onSignInRequired;
  final ValueChanged<ItemModel>? onSimilarItemTap;
  final NotificationPermissionCoordinator? permissionCoordinator;

  const ProductDetailScreen({
    super.key,
    this.itemId,
    this.item,
    this.itemRepository,
    this.chatProvider,
    this.authToken,
    this.currentUserId,
    this.onConversationOpened,
    this.onSignInRequired,
    this.onSimilarItemTap,
    this.permissionCoordinator,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static final RegExp _objectId = RegExp(r'^[0-9a-fA-F]{24}$');
  int _activePhotoIndex = 0;
  late final PageController _pageController;
  ItemModel? _loadedItem;
  bool _isLoading = false;
  String? _errorMessage;
  List<ItemModel> _similarItems = const [];
  bool _isLoadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadedItem = widget.item;
    final id = widget.itemId?.trim() ?? widget.item?.id;
    if (_loadedItem == null) {
      if (id == null || !_objectId.hasMatch(id)) {
        _errorMessage = 'The item link is invalid.';
      } else {
        _isLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchItem(id);
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedItem != null) _loadSimilarItems(_loadedItem!);
      });
    }
  }

  Future<void> _fetchItem(String id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo =
          widget.itemRepository ??
          context.read<ItemRepository?>() ??
          RestItemRepository();
      final fetched = await repo.fetchItemById(id);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadedItem = fetched;
        if (fetched == null) {
          _errorMessage = 'Item not found or no longer available.';
        }
      });
      if (fetched != null) {
        _loadSimilarItems(fetched);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load item details. Please check your connection and try again.';
      });
    }
  }

  Future<void> _loadSimilarItems(ItemModel currentItem) async {
    if (_isLoadingSimilar) return;
    setState(() => _isLoadingSimilar = true);
    try {
      final repo =
          widget.itemRepository ??
          context.read<ItemRepository?>() ??
          RestItemRepository();

      List<ItemModel> candidates = [];
      if (currentItem.category.isNotEmpty) {
        try {
          candidates = await repo.fetchDiscoveryItems(
            DiscoveryQuery(category: currentItem.category),
          );
        } catch (_) {}
      }

      var filtered = candidates
          .where((item) => item.id != currentItem.id)
          .toList();

      if (filtered.length < 4) {
        try {
          final recommended = await repo.fetchRecommendedItems(limit: 6);
          for (final rec in recommended) {
            if (rec.id != currentItem.id &&
                !filtered.any((item) => item.id == rec.id)) {
              filtered.add(rec);
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _similarItems = filtered.take(6).toList();
        _isLoadingSimilar = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSimilar = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ChatProvider? get _chatProvider =>
      widget.chatProvider ?? context.read<ChatProvider?>();

  String? get _authToken =>
      widget.authToken ?? context.read<AuthProvider?>()?.jwtToken;

  Future<void> _messageSeller(ItemModel product) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      final callback = widget.onSignInRequired;
      if (callback != null) {
        callback();
      } else {
        _showLoginSheet(product);
      }
      return;
    }

    final provider = _chatProvider;
    if (provider == null) return;
    try {
      final conversation = await provider.startConversation(
        itemId: product.id,
        token: token,
      );
      if (!mounted || conversation == null) {
        if (mounted) {
          final message = provider.conversationStartErrorFor(product.id);
          if (message != null) _showMessage(message);
        }
        return;
      }
      final callback = widget.onConversationOpened;
      if (callback != null) {
        callback(conversation);
      } else {
        context.push('/messages/${conversation.id}', extra: conversation);
      }
    } on ChatAuthenticationException {
      await context.read<AuthProvider?>()?.clearSession();
      if (!mounted) return;
      _showMessage('Your session has expired. Please sign in again.');
      _showLoginSheet(product);
    }
  }

  Future<void> _scheduleMeetupDirectly(ItemModel product) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      final callback = widget.onSignInRequired;
      if (callback != null) {
        callback();
      } else {
        _showLoginSheet(product);
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ScheduleMeetupSheet(
        itemId: product.id,
        itemTitle: product.title,
        counterpartId: product.ownerId,
        counterpartName: product.ownerName,
        onProposed: (meetup) {
          if (mounted) {
            _messageSeller(product);
          }
        },
      ),
    );
  }

  Future<void> _toggleWatchlist(
    WatchlistProvider watchlist,
    ItemModel product,
  ) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      if (mounted) _showLoginSheet(product);
      return;
    }

    WatchlistMutationResult result;
    try {
      result = await watchlist.toggleWatch(product.id, item: product);
    } catch (error) {
      debugPrint('Watchlist update failed: $error');
      if (mounted) {
        _showMessage('Could not update Watchlist. Please try again.');
      }
      return;
    }
    if (!mounted || result == WatchlistMutationResult.failed) {
      if (mounted) {
        _showMessage('Could not update Watchlist. Please try again.');
      }
      return;
    }
    if (result != WatchlistMutationResult.added) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await offerContextualNotificationPermission(
      context,
      coordinator: widget.permissionCoordinator,
    );
  }

  void _requestWatchlistToggle(WatchlistProvider watchlist, ItemModel product) {
    unawaited(_toggleWatchlist(watchlist, product));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLoginSheet(ItemModel product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: LoginView(
                onLoginSuccess: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _messageSeller(product);
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openReportForm(ItemModel product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(
          reportContext: ReportContext(
            targetType: ReportTargetType.listing,
            targetId: product.id,
            targetLabel: product.title,
            contextType: ReportContextType.listing,
            contextId: product.id,
            contextLabel: product.title,
          ),
        ),
      ),
    );
  }

  void _shareListing(ItemModel product) {
    Clipboard.setData(
      ClipboardData(
        text:
            'Check out "${product.title}" for \$${product.priceNzd} NZD on KiwiShare!',
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Listing link copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _editListing(ItemModel product) async {
    final updated = await EditItemSheet.show(context, item: product);
    if (updated != null && mounted) {
      setState(() => _loadedItem = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final product = _loadedItem;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 1,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          product?.title ?? 'Product details',
          key: const Key('detail-appbar-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: product == null
            ? null
            : [
                Builder(builder: (context) {
                  final auth = context.watch<AuthProvider?>();
                  final userId = widget.currentUserId ?? auth?.currentUser?.id;
                  final ownsListing = userId != null &&
                      (userId == product.ownerId || userId == product.seller?.id);
                  if (!ownsListing) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: 'Edit listing',
                    onPressed: () => _editListing(product),
                    icon: const Icon(Icons.edit_outlined, size: 22),
                  );
                }),
                IconButton(
                  tooltip: 'Share listing',
                  onPressed: () => _shareListing(product),
                  icon: const Icon(Icons.share_outlined, size: 22),
                ),
                Consumer<WatchlistProvider>(
                  builder: (context, watchlist, _) {
                    final isWatched = watchlist.isWatched(product.id);
                    return IconButton(
                      key: const Key('detail-favorite-button'),
                      tooltip: isWatched
                          ? 'Remove from Watchlist'
                          : 'Add to Watchlist',
                      onPressed: () =>
                          _requestWatchlistToggle(watchlist, product),
                      icon: Icon(
                        isWatched ? Icons.favorite : Icons.favorite_border,
                        color: isWatched
                            ? const Color(0xFFEF4444)
                            : theme.colorScheme.onSurface,
                        size: 26,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
      ),
      bottomNavigationBar: product == null
          ? null
          : Consumer<WatchlistProvider>(
              builder: (context, watchlist, _) {
                final chatProvider = _chatProvider;
                if (chatProvider == null) {
                  return _ProductActions(
                    product: product,
                    watchlist: watchlist,
                    onToggleWatch: () =>
                        _requestWatchlistToggle(watchlist, product),
                    messageSellerEnabled: false,
                    isStartingConversation: false,
                    onMessageSeller: null,
                  );
                }
                return ListenableBuilder(
                  listenable: chatProvider,
                  builder: (context, _) {
                    final auth = context.watch<AuthProvider?>();
                    final userId =
                        widget.currentUserId ?? auth?.currentUser?.id;
                    final ownsListing = userId != null &&
                        (userId == product.ownerId || userId == product.seller?.id);
                    final canMessage =
                        product.status == ItemStatus.active && !ownsListing;
                    return _ProductActions(
                      product: product,
                      watchlist: watchlist,
                      ownsListing: ownsListing,
                      onEditListing: () => _editListing(product),
                      onToggleWatch: () =>
                          _requestWatchlistToggle(watchlist, product),
                      messageSellerEnabled: canMessage,
                      isStartingConversation: chatProvider
                          .isStartingConversation(product.id),
                      messageSellerLabel: ownsListing
                          ? 'Your listing'
                          : product.status != ItemStatus.active
                          ? 'Unavailable'
                          : 'Message seller',
                      onMessageSeller: canMessage
                          ? () => _messageSeller(product)
                          : null,
                      onScheduleMeetup: canMessage
                          ? () => _scheduleMeetupDirectly(product)
                          : null,
                    );
                  },
                );
              },
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                key: Key('product-detail-loading'),
              ),
            )
          : product == null
          ? _UnavailableProduct(
              message: _errorMessage,
              onRetry:
                  (widget.itemId != null &&
                      _objectId.hasMatch(widget.itemId!.trim()))
                  ? () => _fetchItem(widget.itemId!.trim())
                  : null,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                // Multi-Image Gallery
                _ProductImageGallery(
                  images: product.allImages,
                  activePage: _activePhotoIndex,
                  pageController: _pageController,
                  status: product.status,
                  onPageChanged: (index) {
                    setState(() => _activePhotoIndex = index);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags / Badges Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusBadge(context, product.status),
                          _buildCategoryBadge(context, product.category),
                          if (product.isSustainable) _buildEcoBadge(context),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Product Title
                      Text(
                        product.title,
                        key: const Key('detail-product-title'),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.3,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Price Display & Watchlist Counter
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (product.isFree) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            Text(
                              '\$0 NZD',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ] else ...[
                            Text(
                              '\$${product.priceNzd} NZD',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3A1D22)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFECDD3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.watchlistCount} watching',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Seller Profile Card (theme-adaptive)
                      if (product.seller != null) ...[
                        _SellerProfileCard(seller: product.seller!),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // Key Specifications / Info Grid
                      _ProductHighlightsGrid(product: product),
                      const SizedBox(height: AppSpacing.xl),

                      // Description Section
                      Text(
                        'Description',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.25)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.35),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          product.description.isEmpty
                              ? 'No description supplied by the seller.'
                              : product.description,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.55,
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.85,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Safe Community & Meetup Banner
                      const _KiwiShareCommunityCard(),

                      // Similar Items Section
                      if (_isLoadingSimilar || _similarItems.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _SimilarItemsSection(
                          items: _similarItems,
                          isLoading: _isLoadingSimilar,
                          onItemTap: (item) {
                            if (widget.onSimilarItemTap != null) {
                              widget.onSimilarItemTap!(item);
                            } else {
                              context.push('/items/${item.id}', extra: item);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: TextButton.icon(
                          key: const Key('detail-report-listing-button'),
                          onPressed: () => _openReportForm(product),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            textStyle: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Report listing'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

Widget _buildStatusBadge(BuildContext context, ItemStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final (bgColor, borderColor, textColor, icon) = switch (status) {
    ItemStatus.active => (
      isDark
          ? const Color(0xFF064E3B).withOpacity(0.5)
          : const Color(0xFFE8F5E9),
      isDark
          ? const Color(0xFF059669).withOpacity(0.5)
          : const Color(0xFFA5D6A7),
      isDark ? const Color(0xFFA7F3D0) : const Color(0xFF2E7D32),
      Icons.check_circle_outline,
    ),
    ItemStatus.reserved => (
      isDark
          ? const Color(0xFF78350F).withOpacity(0.5)
          : const Color(0xFFFFFBEB),
      isDark
          ? const Color(0xFFD97706).withOpacity(0.5)
          : const Color(0xFFFDE68A),
      isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
      Icons.access_time_outlined,
    ),
    ItemStatus.sold => (
      isDark
          ? const Color(0xFF374151).withOpacity(0.5)
          : const Color(0xFFF3F4F6),
      isDark
          ? const Color(0xFF6B7280).withOpacity(0.5)
          : const Color(0xFFD1D5DB),
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      Icons.remove_circle_outline,
    ),
  };

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(color: borderColor, width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          _statusLabel(status),
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _buildCategoryBadge(BuildContext context, String category) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getCategoryIcon(category),
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          category,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEcoBadge(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF065F46).withOpacity(0.4)
          : const Color(0xFFDCFCE7),
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(
        color: isDark
            ? const Color(0xFF059669).withOpacity(0.5)
            : const Color(0xFF86EFAC),
        width: 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.eco_rounded,
          size: 14,
          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
        ),
        const SizedBox(width: 4),
        Text(
          'Eco Choice',
          style: TextStyle(
            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ProductHighlightsGrid extends StatelessWidget {
  final ItemModel product;

  const _ProductHighlightsGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buildTile({
      required IconData icon,
      required String label,
      required String value,
      Color? iconColor,
    }) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withOpacity(
                  0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: product.location,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: buildTile(
                icon: _getCategoryIcon(product.category),
                label: 'Category',
                value: product.category,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: buildTile(
                icon: Icons.inventory_2_outlined,
                label: 'Status',
                value: _statusLabel(product.status),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: buildTile(
                icon: product.isSustainable
                    ? Icons.eco_outlined
                    : Icons.check_circle_outline,
                label: product.isSustainable ? 'Sustainability' : 'Condition',
                value: product.isSustainable
                    ? 'Pre-loved'
                    : (product.condition?.isNotEmpty == true
                          ? product.condition!
                          : 'Standard'),
                iconColor: product.isSustainable
                    ? (isDark
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF15803D))
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SellerProfileCard extends StatelessWidget {
  final SellerInfo seller;

  const _SellerProfileCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.25)
        : (seller.isStudentVerified
              ? const Color(0xFFF0F7FF)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.35));

    final borderColor = isDark
        ? theme.colorScheme.outline.withOpacity(0.2)
        : (seller.isStudentVerified
              ? const Color(0xFFC7DFFB)
              : theme.colorScheme.outline.withOpacity(0.25));

    final studentTextColor = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);
    final studentBadgeBg = isDark
        ? const Color(0xFF1E3A8A).withOpacity(0.5)
        : const Color(0xFFDBEAFE);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? theme.colorScheme.primaryContainer
                    : (seller.isStudentVerified
                          ? const Color(0xFFDBEAFE)
                          : theme.colorScheme.primaryContainer),
                backgroundImage:
                    seller.avatarUrl != null && seller.avatarUrl!.isNotEmpty
                    ? NetworkImage(seller.avatarUrl!)
                    : null,
                child: seller.avatarUrl == null || seller.avatarUrl!.isEmpty
                    ? Text(
                        seller.displayName.isNotEmpty
                            ? seller.displayName[0].toUpperCase()
                            : 'K',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark
                              ? theme.colorScheme.onPrimaryContainer
                              : (seller.isStudentVerified
                                    ? const Color(0xFF1D4ED8)
                                    : theme.colorScheme.primary),
                        ),
                      )
                    : null,
              ),
              if (seller.isStudentVerified || seller.isVerified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      seller.isStudentVerified ? Icons.school : Icons.verified,
                      size: 12,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        seller.displayName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (seller.isStudentVerified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: studentBadgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Verified Student',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: studentTextColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  seller.isStudentVerified
                      ? '${seller.studentInstitution ?? "University of Auckland"} Student'
                      : 'Community Member',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: seller.isStudentVerified
                        ? studentTextColor
                        : theme.colorScheme.onSurface.withOpacity(0.65),
                    fontWeight: seller.isStudentVerified
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : theme.colorScheme.primaryContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 11,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Trust Score',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${seller.trustScore}/100',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KiwiShareCommunityCard extends StatelessWidget {
  const _KiwiShareCommunityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.primaryContainer.withOpacity(0.18)
            : theme.colorScheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KiwiShare Safe & Sustainable Trade',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Meet in busy, well-lit campus or community spots. By choosing secondhand, you extend item lifecycles and reduce local waste.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({
    required this.product,
    required this.watchlist,
    required this.onToggleWatch,
    required this.messageSellerEnabled,
    required this.isStartingConversation,
    required this.onMessageSeller,
    this.onScheduleMeetup,
    this.messageSellerLabel = 'Message seller',
    this.ownsListing = false,
    this.onEditListing,
  });

  final ItemModel product;
  final WatchlistProvider watchlist;
  final VoidCallback onToggleWatch;
  final bool messageSellerEnabled;
  final bool isStartingConversation;
  final VoidCallback? onMessageSeller;
  final VoidCallback? onScheduleMeetup;
  final String messageSellerLabel;
  final bool ownsListing;
  final VoidCallback? onEditListing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWatched = watchlist.isWatched(product.id);
    final useVerticalLayout = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    final editButton = FilledButton.icon(
      key: const Key('detail-edit-listing-button'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: const Color(0xFF059669),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      onPressed: onEditListing,
      icon: const Icon(Icons.edit_outlined),
      label: Text(
        product.status != ItemStatus.active
            ? 'Re-list / Edit'
            : 'Edit Listing',
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );

    final meetupButton = IconButton.outlined(
      key: const Key('detail-schedule-meetup-button'),
      tooltip: 'Schedule Meetup',
      style: IconButton.styleFrom(
        minimumSize: const Size(50, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        side: BorderSide(
          color: onScheduleMeetup != null
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      onPressed: onScheduleMeetup,
      icon: Icon(
        Icons.handshake_outlined,
        color: onScheduleMeetup != null ? theme.colorScheme.primary : null,
      ),
    );

    final watchButton = OutlinedButton.icon(
      key: const Key('detail-watch-action-button'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        side: BorderSide(
          color: isWatched
              ? const Color(0xFFEF4444)
              : theme.colorScheme.outline.withOpacity(0.5),
        ),
        backgroundColor: isWatched
            ? theme.brightness == Brightness.dark
                  ? const Color(0xFF3A1D22)
                  : const Color(0xFFFFF1F2)
            : theme.brightness == Brightness.dark
            ? theme.colorScheme.primaryContainer.withOpacity(0.42)
            : AppColors.surfaceMuted,
        foregroundColor: isWatched
            ? const Color(0xFFEF4444)
            : theme.colorScheme.onSurface,
      ),
      onPressed: onToggleWatch,
      icon: Icon(
        isWatched ? Icons.favorite : Icons.favorite_border,
        color: isWatched
            ? const Color(0xFFEF4444)
            : theme.colorScheme.onSurface,
      ),
      label: Text(
        'Watching',
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: isWatched
              ? const Color(0xFFEF4444)
              : theme.colorScheme.onSurface,
        ),
      ),
    );

    final messageButton = FilledButton.icon(
      key: const Key('detail-message-seller-button'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      onPressed: messageSellerEnabled && !isStartingConversation
          ? onMessageSeller
          : null,
      icon: isStartingConversation
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.chat_bubble_outline),
      label: Text(
        isStartingConversation ? 'Opening chat' : messageSellerLabel,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: useVerticalLayout
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ownsListing && onEditListing != null) ...[
                    editButton,
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      if (onScheduleMeetup != null) ...[
                        meetupButton,
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(child: watchButton),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  messageButton,
                ],
              )
            : Row(
                children: [
                  if (ownsListing && onEditListing != null) ...[
                    IconButton.filledTonal(
                      key: const Key('detail-edit-listing-button'),
                      tooltip: 'Edit listing',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(50, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                      onPressed: onEditListing,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ] else if (onScheduleMeetup != null) ...[
                    meetupButton,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(flex: 3, child: watchButton),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 5, child: messageButton),
                ],
              ),
      ),
    );
  }
}

class _ProductImageGallery extends StatelessWidget {
  final List<String> images;
  final int activePage;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ItemStatus status;

  const _ProductImageGallery({
    required this.images,
    required this.activePage,
    required this.pageController,
    required this.onPageChanged,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : AppColors.surfaceMuted,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 56,
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'No photos provided',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return ColoredBox(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : AppColors.surfaceMuted,
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 56,
                      color: theme.colorScheme.primary.withOpacity(0.4),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${activePage + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (status != ItemStatus.active)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == ItemStatus.reserved
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _statusLabel(status).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _statusLabel(ItemStatus status) => switch (status) {
  ItemStatus.active => 'Available',
  ItemStatus.reserved => 'Reserved',
  ItemStatus.sold => 'Sold',
};

IconData _getCategoryIcon(String category) {
  final normalized = category.toLowerCase().trim();
  if (normalized.contains('furnitur') ||
      normalized.contains('chair') ||
      normalized.contains('table') ||
      normalized.contains('desk')) {
    return Icons.chair_outlined;
  }
  if (normalized.contains('plant') ||
      normalized.contains('garden') ||
      normalized.contains('flower') ||
      normalized.contains('tree')) {
    return Icons.yard_outlined;
  }
  if (normalized.contains('camp') ||
      normalized.contains('tent') ||
      normalized.contains('outdoor')) {
    return Icons.terrain_outlined;
  }
  if (normalized.contains('book') ||
      normalized.contains('study') ||
      normalized.contains('note')) {
    return Icons.menu_book_outlined;
  }
  if (normalized.contains('electr') ||
      normalized.contains('phone') ||
      normalized.contains('tech') ||
      normalized.contains('laptop')) {
    return Icons.devices_outlined;
  }
  if (normalized.contains('cloth') ||
      normalized.contains('apparel') ||
      normalized.contains('wear')) {
    return Icons.checkroom_outlined;
  }
  return Icons.category_outlined;
}

class _UnavailableProduct extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const _UnavailableProduct({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Product unavailable',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? 'Return to Products and choose an available item.',
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              key: const Key('product-detail-retry-button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SimilarItemsSection extends StatelessWidget {
  final List<ItemModel> items;
  final bool isLoading;
  final ValueChanged<ItemModel> onItemTap;

  const _SimilarItemsSection({
    required this.items,
    required this.isLoading,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Similar Items',
              key: const Key('detail-similar-items-header'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (!isLoading && items.isNotEmpty)
              Text(
                '${items.length} recommended',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 215,
          child: isLoading && items.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, index) =>
                      _SimilarItemSkeletonCard(isDark: isDark),
                )
              : ListView.separated(
                  key: const Key('detail-similar-items-list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _SimilarItemCard(
                      item: item,
                      onTap: () => onItemTap(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SimilarItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _SimilarItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: colors.outline.withOpacity(isDark ? 0.2 : 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('similar-item-${item.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 105,
                width: double.infinity,
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
                          size: 28,
                        ),
                      ),
                    ),
                    if (item.isSustainable)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: Icon(
                            Icons.eco_outlined,
                            size: 11,
                            color: colors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '\$${item.priceNzd} NZD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (item.seller?.isStudentVerified == true) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.verified,
                            size: 11,
                            color: Color(0xFF2563EB),
                          ),
                        ],
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

class _SimilarItemSkeletonCard extends StatelessWidget {
  final bool isDark;

  const _SimilarItemSkeletonCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);

    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 105, width: double.infinity, color: shimmerColor),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  width: 60,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
