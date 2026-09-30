import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/listing_category_config.dart';
import '../../../theme/app_theme.dart';

const Map<String, String> _categoryAssetByName = {
  'Furniture': 'assets/categories/furniture.svg',
  'Electronics': 'assets/categories/electronics.svg',
  'Books': 'assets/categories/books.svg',
  'Home': 'assets/categories/home.svg',
  'Sports': 'assets/categories/sports.svg',
  'Kids': 'assets/categories/kids.svg',
  'Fashion': 'assets/categories/fashion.svg',
  'Cars & Vehicles': 'assets/categories/vehicles.svg',
  'Other': 'assets/categories/other.svg',
};

String listingCategoryAsset(String category) =>
    _categoryAssetByName[category] ?? _categoryAssetByName['Other']!;

class ListingCategoryGridSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? selectedValue;

  const ListingCategoryGridSheet({
    super.key,
    this.title = 'What are you listing?',
    this.subtitle,
    this.selectedValue,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'What are you listing?',
    String? subtitle,
    String? selectedValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ListingCategoryGridSheet(
        title: title,
        subtitle: subtitle,
        selectedValue: selectedValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.78),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: listingCategoryDefinitions.length,
              itemBuilder: (context, index) {
                final category = listingCategoryDefinitions[index];
                final selected = category.name == selectedValue;
                return _ListingCategoryTile(
                  key: Key('post-entry-category-${category.name}'),
                  category: category,
                  selected: selected,
                  onTap: () => Navigator.of(context).pop(category.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCategoryTile extends StatelessWidget {
  final ListingCategoryDefinition category;
  final bool selected;
  final VoidCallback onTap;

  const _ListingCategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tileColor = selected
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final borderColor = selected
        ? colors.primary
        : colors.outlineVariant.withValues(alpha: 0.7);

    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 11, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    heightFactor: 0.58,
                    child: SvgPicture.asset(
                      listingCategoryAsset(category.name),
                      colorFilter: ColorFilter.mode(
                        selected ? colors.onPrimaryContainer : colors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
