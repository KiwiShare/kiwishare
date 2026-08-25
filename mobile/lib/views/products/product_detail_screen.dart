import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../repositories/item_repository.dart';
import '../../theme/app_theme.dart';
import 'product_detail_integrations.dart';
import 'product_edit_screen.dart';

enum _DetailMenuAction { reportListing, contactSeller, viewSeller }

class ProductDetailScreen extends StatefulWidget {
  final String itemId;
  final ItemModel? initialItem;
  final ProductDetailIntegrations integrations;

  const ProductDetailScreen({
    super.key,
    required this.itemId,
    this.initialItem,
    this.integrations = const ProductDetailIntegrations(),
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _activePhotoIndex = 0;
  late final PageController _pageController;
  ItemModel? _item;
  Object? _loadError;
  bool _loading = false;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _item = widget.initialItem;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItem());
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _item = widget.initialItem;
      _activePhotoIndex = 0;
      _loadItem();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    if (!mounted) return;
    setState(() {
      _loading = _item == null;
      _loadError = null;
    });
    try {
      if (_item case final initial?) {
        context.read<ListingProvider>().seedItemDetail(initial);
      }
      final item = await context.read<ListingProvider>().getItemById(
        widget.itemId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  bool _isOwner(BuildContext context, ItemModel item) {
    final userId = context.watch<AuthProvider>().currentUser?.id;
    return userId != null && userId.isNotEmpty && userId == item.ownerId;
  }

  Future<void> _invoke(ProductDetailAction? action, ItemModel item) async {
    if (action == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await Future<void>.sync(() => action(context, item));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _editListing(ItemModel item) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final options = await context.read<ListingProvider>().getDiscoveryOptions(
        forceRefresh: true,
      );
      if (!mounted) return;
      final updated = await Navigator.of(context).push<ItemModel>(
        MaterialPageRoute<ItemModel>(
          builder: (_) => ProductEditScreen(item: item, options: options),
        ),
      );
      if (updated != null && mounted) setState(() => _item = updated);
    } on ItemRepositoryException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Editing is unavailable. Try again.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _deleteListing(ItemModel item) async {
    if (_actionBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text(
          'It will be removed from marketplace results. Related transaction, report, review, and audit records remain stored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null || token.isEmpty) {
      _showMessage('Log in again before deleting this listing.');
      return;
    }
    setState(() => _actionBusy = true);
    try {
      await context.read<ListingProvider>().deleteItem(
        itemId: item.id,
        token: token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ItemRepositoryException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('The listing could not be deleted. Try again.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleMenuAction(_DetailMenuAction action, ItemModel item) {
    switch (action) {
      case _DetailMenuAction.reportListing:
        _invoke(widget.integrations.onReportListing, item);
      case _DetailMenuAction.contactSeller:
        _invoke(widget.integrations.onContactSeller, item);
      case _DetailMenuAction.viewSeller:
        _invoke(widget.integrations.onViewSeller, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final isOwner = item != null && _isOwner(context, item);
    final menuActions = item == null || isOwner
        ? const <PopupMenuEntry<_DetailMenuAction>>[]
        : <PopupMenuEntry<_DetailMenuAction>>[
            if (widget.integrations.onViewSeller != null)
              const PopupMenuItem(
                value: _DetailMenuAction.viewSeller,
                child: Text('View seller profile'),
              ),
            if (widget.integrations.onContactSeller != null)
              const PopupMenuItem(
                value: _DetailMenuAction.contactSeller,
                child: Text('Contact seller'),
              ),
            if (widget.integrations.onReportListing != null)
              const PopupMenuItem(
                value: _DetailMenuAction.reportListing,
                child: Text('Report listing'),
              ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product details',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          if (item != null && !isOwner)
            Consumer<WatchlistProvider>(
              builder: (context, watchlist, _) {
                final isWatched = watchlist.isWatched(item.id);
                return IconButton(
                  key: const Key('detail-favorite-button'),
                  tooltip: isWatched
                      ? 'Remove from Watchlist'
                      : 'Add to Watchlist',
                  onPressed: () => watchlist.toggleWatch(item.id, item: item),
                  icon: Icon(
                    isWatched ? Icons.bookmark : Icons.bookmark_outline,
                    color: isWatched ? AppColors.brandPrimary : null,
                  ),
                );
              },
            ),
          if (menuActions.isNotEmpty)
            PopupMenuButton<_DetailMenuAction>(
              key: const Key('detail-integrations-menu'),
              tooltip: 'More listing actions',
              enabled: !_actionBusy,
              onSelected: (action) => _handleMenuAction(action, item!),
              itemBuilder: (_) => menuActions,
            ),
        ],
      ),
      bottomNavigationBar: item == null
          ? null
          : _DetailBottomActions(
              item: item,
              isOwner: isOwner,
              busy: _actionBusy,
              integrations: widget.integrations,
              onEdit: () => _editListing(item),
              onDelete: () => _deleteListing(item),
              onInvoke: (action) => _invoke(action, item),
            ),
      body: _buildBody(item, isOwner),
    );
  }

  Widget _buildBody(ItemModel? item, bool isOwner) {
    if (_loading && item == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (item == null) {
      final notFound = _loadError is ItemNotFoundException;
      return _UnavailableProduct(
        title: notFound ? 'Product unavailable' : 'Could not load product',
        message: notFound
            ? 'This listing may have been removed or is no longer visible.'
            : 'Check your connection and try again.',
        onRetry: notFound ? null : _loadItem,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadItem,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (_loadError != null)
            MaterialBanner(
              content: const Text(
                'Showing the last available listing data. Pull to refresh.',
              ),
              actions: [
                TextButton(onPressed: _loadItem, child: const Text('Retry')),
              ],
            ),
          _ProductImageGallery(
            images: item.allImages,
            activePage: _activePhotoIndex,
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() => _activePhotoIndex = index);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        key: const Key('product_detail_title'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    if (item.isSustainable) const _EcoBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _priceLabel(item),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textBrand,
                  ),
                ),
                if (item.negotiable)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Price negotiable',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (item.seller != null) ...[
                  _SellerProfileCard(
                    seller: item.seller!,
                    onTap: widget.integrations.onViewSeller == null
                        ? null
                        : () => _invoke(widget.integrations.onViewSeller, item),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.description.isEmpty
                      ? 'No description supplied.'
                      : item.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Item details',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Approximate location',
                  value: item.location.isEmpty ? 'Not supplied' : item.location,
                ),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: item.category.isEmpty ? 'Not supplied' : item.category,
                ),
                if (item.condition case final condition?)
                  if (condition.isNotEmpty)
                    _DetailRow(
                      icon: Icons.fact_check_outlined,
                      label: 'Condition',
                      value: _displayValue(condition),
                    ),
                _DetailRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Status',
                  value: _statusLabel(item.status),
                ),
                if (!isOwner &&
                    widget.integrations.onReportListing != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton.icon(
                      key: const Key('report_listing_button'),
                      onPressed: _actionBusy
                          ? null
                          : () => _invoke(
                              widget.integrations.onReportListing,
                              item,
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Report listing'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBottomActions extends StatelessWidget {
  final ItemModel item;
  final bool isOwner;
  final bool busy;
  final ProductDetailIntegrations integrations;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProductDetailAction?> onInvoke;

  const _DetailBottomActions({
    required this.item,
    required this.isOwner,
    required this.busy,
    required this.integrations,
    required this.onEdit,
    required this.onDelete,
    required this.onInvoke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: isOwner
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('edit_listing_button'),
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit listing'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('delete_listing_button'),
                      onPressed: busy ? null : onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete listing'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Consumer<WatchlistProvider>(
                      builder: (context, watchlist, _) {
                        final watched = watchlist.isWatched(item.id);
                        return OutlinedButton.icon(
                          key: const Key('detail-watch-action-button'),
                          onPressed: busy
                              ? null
                              : () =>
                                    watchlist.toggleWatch(item.id, item: item),
                          icon: Icon(
                            watched ? Icons.bookmark : Icons.bookmark_outline,
                          ),
                          label: Text(watched ? 'Watching' : 'Watch Item'),
                        );
                      },
                    ),
                  ),
                  if (integrations.onStartTrade != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('start_trade_button'),
                        onPressed: busy
                            ? null
                            : () => onInvoke(integrations.onStartTrade),
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Start trade'),
                      ),
                    ),
                  ],
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

  const _ProductImageGallery({
    required this.images,
    required this.activePage,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 56,
            color: AppColors.brandPrimary,
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
            itemBuilder: (context, index) => ColoredBox(
              color: AppColors.surfaceMuted,
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.image_not_supported_outlined,
                  size: 56,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    '${activePage + 1} / ${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EcoBadge extends StatelessWidget {
  const _EcoBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.brandPrimaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco, size: 14, color: AppColors.brandPrimary),
        SizedBox(width: 4),
        Text(
          'Eco',
          style: TextStyle(
            color: AppColors.brandPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brandPrimary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SellerProfileCard extends StatelessWidget {
  final SellerInfo seller;
  final VoidCallback? onTap;

  const _SellerProfileCard({required this.seller, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = seller.displayName.trim();
    final institution = seller.studentInstitution?.trim();
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: seller.isStudentVerified
            ? const Color(0xFFEFF6FF)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.brandPrimaryContainer,
            backgroundImage:
                seller.avatarUrl != null && seller.avatarUrl!.isNotEmpty
                ? NetworkImage(seller.avatarUrl!)
                : null,
            child: seller.avatarUrl == null || seller.avatarUrl!.isEmpty
                ? Text(
                    displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty
                      ? 'Seller information unavailable'
                      : displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (seller.isStudentVerified && institution?.isNotEmpty == true)
                  Text(
                    institution!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (seller.rating case final rating?)
                  Text(
                    seller.reviewCount == null
                        ? rating.toStringAsFixed(1)
                        : '${rating.toStringAsFixed(1)} · ${seller.reviewCount} reviews',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (seller.trustScore case final trustScore?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Trust Score',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  trustScore.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          if (onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: 'View seller profile',
      child: InkWell(onTap: onTap, child: card),
    );
  }
}

class _UnavailableProduct extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  const _UnavailableProduct({
    required this.title,
    required this.message,
    this.onRetry,
  });

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
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );
}

String _priceLabel(ItemModel item) {
  final value = item.priceNzd.isEmpty
      ? 'Price unavailable'
      : '\$${item.priceNzd}';
  return item.currency.isEmpty ? value : '$value ${item.currency}';
}

String _statusLabel(ItemStatus status) => switch (status) {
  ItemStatus.active => 'Available',
  ItemStatus.reserved => 'Reserved',
  ItemStatus.sold => 'Sold',
};

String _displayValue(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
