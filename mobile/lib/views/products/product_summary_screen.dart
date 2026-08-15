import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_theme.dart';

class ProductSummaryScreen extends StatelessWidget {
  final String itemId;
  final ItemModel? initialItem;

  const ProductSummaryScreen({
    super.key,
    required this.itemId,
    this.initialItem,
  });

  @override
  Widget build(BuildContext context) {
    final future = initialItem == null
        ? context.read<ListingProvider>().getItemById(itemId)
        : Future<ItemModel>.value(initialItem);
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: FutureBuilder<ItemModel>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('This listing could not be loaded.'),
            );
          }
          final item = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                        ),
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '\$${item.priceNzd} NZD',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      text: item.location,
                    ),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      text: item.category,
                    ),
                    if (item.condition != null)
                      _DetailRow(
                        icon: Icons.inventory_2_outlined,
                        text: item.condition!.replaceAll('_', ' '),
                      ),
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'About this item',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(item.description!),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
