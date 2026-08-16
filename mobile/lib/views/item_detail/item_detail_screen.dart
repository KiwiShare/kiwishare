import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_theme.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.isDeleting = false,
  });

  final ItemModel item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = context.watch<FavoritesProvider>();
    final isFavorite = favoriteProvider.isFavorite(item.id);
    final useAccessibleHeader = MediaQuery.textScalerOf(context).scale(16) > 24;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: useAccessibleHeader ? 88 : kToolbarHeight,
        title: const Text('Item details', maxLines: 2),
        actions: [
          IconButton(
            key: const Key('detail_favorite_button'),
            tooltip: isFavorite ? 'Remove from saved items' : 'Save item',
            onPressed: () => favoriteProvider.toggleFavorite(item.id),
            icon: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
              color: isFavorite ? AppColors.error : AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const Key('item_detail_scroll_view'),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemImageGallery(item: item),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemHeading(item: item),
                    const SizedBox(height: AppSpacing.xl),
                    _DetailSection(
                      title: 'About this item',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetadataRow(
                            icon: Icons.sell_outlined,
                            label: 'Condition',
                            value: _formatCondition(item.condition),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MetadataRow(
                            icon: Icons.category_outlined,
                            label: 'Category',
                            value: item.category,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MetadataRow(
                            icon: Icons.location_on_outlined,
                            label: 'Approximate location',
                            value: item.location,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            item.description?.trim().isNotEmpty == true
                                ? item.description!.trim()
                                : 'The seller has not added a description yet.',
                            key: const Key('detail_description'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SellerSection(item: item),
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _OwnerActions(
                        onEdit: onEdit,
                        onDelete: onDelete,
                        isDeleting: isDeleting,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCondition(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not specified';
    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) => _DetailSection(
    title: 'Manage listing',
    child: Column(
      children: [
        if (onEdit != null)
          OutlinedButton.icon(
            key: const Key('detail_edit_button'),
            onPressed: isDeleting ? null : onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit listing'),
          ),
        if (onEdit != null && onDelete != null)
          const SizedBox(height: AppSpacing.md),
        if (onDelete != null)
          OutlinedButton.icon(
            key: const Key('detail_delete_button'),
            onPressed: isDeleting ? null : onDelete,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            icon: isDeleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(isDeleting ? 'Deleting listing' : 'Delete listing'),
          ),
      ],
    ),
  );
}

class _ItemImageGallery extends StatefulWidget {
  const _ItemImageGallery({required this.item});

  final ItemModel item;

  @override
  State<_ItemImageGallery> createState() => _ItemImageGalleryState();
}

class _ItemImageGalleryState extends State<_ItemImageGallery> {
  late final PageController _controller;
  var _currentIndex = 0;

  List<String> get _images {
    final urls = widget.item.imageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (urls.isEmpty && widget.item.imageUrl.trim().isNotEmpty) {
      return [widget.item.imageUrl];
    }
    return urls;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.surfaceMuted,
            child: images.isEmpty
                ? const _ImagePlaceholder()
                : PageView.builder(
                    key: const Key('detail_image_gallery'),
                    controller: _controller,
                    itemCount: images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      semanticLabel:
                          '${widget.item.title}, image ${index + 1} of ${images.length}',
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImagePlaceholder(),
                    ),
                  ),
          ),
          if (images.length > 1)
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Semantics(
                label: 'Image ${_currentIndex + 1} of ${images.length}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${images.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.image_not_supported_outlined,
      size: 48,
      color: AppColors.brandSecondary,
      semanticLabel: 'Image unavailable',
    ),
  );
}

class _ItemHeading extends StatelessWidget {
  const _ItemHeading({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _StatusBadge(status: item.status),
            if (item.isSustainable)
              const _InformationBadge(
                icon: Icons.eco_outlined,
                label: 'Sustainable choice',
              ),
            if (item.negotiable)
              const _InformationBadge(
                icon: Icons.handshake_outlined,
                label: 'Negotiable',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            item.title,
            key: const Key('detail_title'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '\$${item.priceNzd} NZD',
          key: const Key('detail_price'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: AppColors.textBrand),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, foreground, background) = switch (status) {
      ItemStatus.active => (
        Icons.check_circle_outline,
        'Available',
        AppColors.success,
        const Color(0xFFE8F5E9),
      ),
      ItemStatus.reserved => (
        Icons.schedule_outlined,
        'Reserved',
        AppColors.warning,
        const Color(0xFFFFF2CC),
      ),
      ItemStatus.sold => (
        Icons.inventory_2_outlined,
        'Sold',
        AppColors.textSecondary,
        AppColors.surfaceMuted,
      ),
    };

    return _Badge(
      icon: icon,
      label: label,
      foreground: foreground,
      background: background,
    );
  }
}

class _InformationBadge extends StatelessWidget {
  const _InformationBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => _Badge(
    icon: icon,
    label: label,
    foreground: AppColors.textBrand,
    background: AppColors.brandPrimaryContainer,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: AppColors.brandPrimary),
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
  );
}

class _SellerSection extends StatelessWidget {
  const _SellerSection({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final sellerName = item.sellerName?.trim();
    final hasSeller = sellerName != null && sellerName.isNotEmpty;
    final avatarUrl = item.sellerAvatarUrl;

    return _DetailSection(
      title: 'Seller',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brandSecondaryContainer,
            foregroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: Text(
              hasSeller ? sellerName[0].toUpperCase() : '?',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.textBrand),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSeller ? sellerName : 'Seller information unavailable',
                  key: const Key('detail_seller_name'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (item.sellerRating != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: AppColors.brandAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '${item.sellerRating!.toStringAsFixed(1)} from ${item.sellerReviewCount ?? 0} reviews',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
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
