import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/watchlist_provider.dart';
import '../../theme/app_theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final ItemModel? item;

  const ProductDetailScreen({super.key, required this.item});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _activePhotoIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product details',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: product == null
            ? null
            : [
                Consumer<WatchlistProvider>(
                  builder: (context, watchlist, _) {
                    final isWatched = watchlist.isWatched(product.id);
                    return IconButton(
                      key: const Key('detail-favorite-button'),
                      tooltip: isWatched
                          ? 'Remove from Watchlist'
                          : 'Add to Watchlist',
                      onPressed: () =>
                          watchlist.toggleWatch(product.id, item: product),
                      icon: Icon(
                        isWatched ? Icons.bookmark : Icons.bookmark_outline,
                        color: isWatched ? AppColors.brandPrimary : null,
                        size: 26,
                      ),
                    );
                  },
                ),
              ],
      ),
      bottomNavigationBar: product == null
          ? null
          : Consumer<WatchlistProvider>(
              builder: (context, watchlist, _) {
                final isWatched = watchlist.isWatched(product.id);
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('detail-watch-action-button'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isWatched
                                  ? AppColors.brandPrimaryContainer
                                  : Colors.transparent,
                              side: BorderSide(
                                color: isWatched
                                    ? AppColors.brandPrimary
                                    : AppColors.border,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                              ),
                            ),
                            onPressed: () => watchlist.toggleWatch(
                              product.id,
                              item: product,
                            ),
                            icon: Icon(
                              isWatched
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                              color: isWatched
                                  ? AppColors.brandPrimary
                                  : AppColors.textPrimary,
                            ),
                            label: Text(
                              isWatched ? 'Watching' : 'Watch Item',
                              style: TextStyle(
                                color: isWatched
                                    ? AppColors.brandPrimary
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      body: product == null
          ? const _UnavailableProduct()
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                // Swipeable Multi-Image Gallery
                _ProductImageGallery(
                  images: product.allImages,
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
                              product.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          if (product.isSustainable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.small,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.eco,
                                    size: 14,
                                    color: AppColors.brandPrimary,
                                  ),
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
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '\$${product.priceNzd} NZD',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.textBrand),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (product.seller != null) ...[
                        _SellerProfileCard(seller: product.seller!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        product.description.isEmpty
                            ? 'No description supplied.'
                            : product.description,
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
                        value: product.location,
                      ),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: product.category,
                      ),
                      _DetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Status',
                        value: _statusLabel(product.status),
                      ),
                      if (product.isSustainable)
                        const _DetailRow(
                          icon: Icons.eco_outlined,
                          label: 'Sustainability',
                          value: 'Pre-loved item',
                        ),
                    ],
                  ),
                ),
              ],
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
            itemBuilder: (context, index) {
              return ColoredBox(
                color: AppColors.surfaceMuted,
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported_outlined,
                    size: 56,
                    color: AppColors.brandPrimary,
                  ),
                ),
              );
            },
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
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${activePage + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

  const _SellerProfileCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: seller.isStudentVerified
            ? const Color(0xFFEFF6FF)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seller.isStudentVerified
              ? const Color(0xFFBFDBFE)
              : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: seller.isStudentVerified
                ? const Color(0xFFDBEAFE)
                : AppColors.brandPrimaryContainer,
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
                      color: seller.isStudentVerified
                          ? const Color(0xFF1D4ED8)
                          : AppColors.brandPrimary,
                    ),
                  )
                : null,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (seller.isStudentVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.school,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  seller.isStudentVerified
                      ? '${seller.studentInstitution ?? "University of Auckland"} Student'
                      : 'Community Member',
                  style: TextStyle(
                    fontSize: 12,
                    color: seller.isStudentVerified
                        ? const Color(0xFF1E40AF)
                        : AppColors.textSecondary,
                    fontWeight: seller.isStudentVerified
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Trust Score',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '${seller.trustScore}/100',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailableProduct extends StatelessWidget {
  const _UnavailableProduct();

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
          const Text(
            'Return to Products and choose an available item.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
