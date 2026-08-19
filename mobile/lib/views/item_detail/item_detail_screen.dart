import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../models/report_draft.dart';
import '../../theme/app_theme.dart';
import '../profile/report_screen.dart';

Future<void> openItemDetail(BuildContext context, ItemModel item) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(item: item)),
    );

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.item});

  final ItemModel item;

  void _reportListing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(
          reportContext: ReportContext(
            targetType: ReportTargetType.listing,
            targetId: item.id,
            targetLabel: item.title,
            contextType: ReportContextType.listing,
            contextId: item.id,
            contextLabel: 'Listing in ${item.location}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Hero(
              tag: 'listing-image-${item.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.large),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    key: const Key('item_detail_title'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '\$${item.priceNzd}',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item.location)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _DetailChip(
                  icon: Icons.category_outlined,
                  label: item.category,
                ),
                _DetailChip(
                  icon: Icons.inventory_2_outlined,
                  label: _statusLabel(item.status),
                ),
                if (item.isSustainable)
                  const _DetailChip(
                    icon: Icons.eco_outlined,
                    label: 'Sustainable',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton(
                key: const Key('report_listing_button'),
                onPressed: () => _reportListing(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                child: const Text('Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(ItemStatus status) => switch (status) {
    ItemStatus.active => 'Available',
    ItemStatus.reserved => 'Reserved',
    ItemStatus.sold => 'Sold',
  };
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
