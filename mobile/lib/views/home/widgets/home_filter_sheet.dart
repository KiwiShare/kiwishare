import 'package:flutter/material.dart';

import '../../../providers/home_discovery_provider.dart';
import '../../../theme/app_theme.dart';

class HomeFilterSheet extends StatefulWidget {
  final HomeDiscoveryProvider filters;
  final VoidCallback onReset;

  const HomeFilterSheet({
    super.key,
    required this.filters,
    required this.onReset,
  });

  @override
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  late HomeProductSort _sort;
  late HomePriceRange _priceRange;
  late bool _sustainableOnly;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;

  @override
  void initState() {
    super.initState();
    _sort = widget.filters.selectedSort;
    _priceRange = widget.filters.selectedPriceRange;
    _sustainableOnly = widget.filters.sustainableOnly;
    _minimumController = TextEditingController(
      text: widget.filters.minimumPrice?.toStringAsFixed(0) ?? '',
    );
    _maximumController = TextEditingController(
      text: widget.filters.maximumPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _selectPriceRange(HomePriceRange range) {
    setState(() {
      _priceRange = range;
      switch (range) {
        case HomePriceRange.any:
          _minimumController.clear();
          _maximumController.clear();
        case HomePriceRange.under25:
          _minimumController.clear();
          _maximumController.text = '25';
        case HomePriceRange.from25To50:
          _minimumController.text = '25';
          _maximumController.text = '50';
        case HomePriceRange.from50To100:
          _minimumController.text = '50';
          _maximumController.text = '100';
        case HomePriceRange.over100:
          _minimumController.text = '100';
          _maximumController.clear();
        case HomePriceRange.custom:
          break;
      }
    });
  }

  void _markCustomRange(String _) {
    if (_priceRange != HomePriceRange.custom) {
      setState(() => _priceRange = HomePriceRange.custom);
    }
  }

  void _apply() {
    final minimum = double.tryParse(_minimumController.text.trim());
    final maximum = double.tryParse(_maximumController.text.trim());
    if ((minimum != null && minimum < 0) || (maximum != null && maximum < 0)) {
      _showValidation('Prices cannot be negative.');
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      _showValidation('Minimum price must not exceed maximum price.');
      return;
    }

    widget.filters.setSort(_sort);
    if (_priceRange == HomePriceRange.custom) {
      widget.filters.setCustomPriceRange(minimum: minimum, maximum: maximum);
    } else {
      widget.filters.setPriceRange(_priceRange);
    }
    widget.filters.setSustainableOnly(_sustainableOnly);
    Navigator.pop(context);
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _reset() {
    widget.onReset();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sort and filter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Sort by', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final sort in HomeProductSort.values)
              RadioListTile<HomeProductSort>(
                key: Key('home-sort-${sort.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(sort.label),
                value: sort,
                groupValue: _sort,
                onChanged: (value) => setState(() => _sort = value ?? _sort),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Price range (NZD)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final range in HomePriceRange.values)
                  ChoiceChip(
                    key: Key('home-price-range-${range.name}'),
                    label: Text(range.label),
                    selected: _priceRange == range,
                    onSelected: (_) => _selectPriceRange(range),
                    selectedColor: AppColors.brandPrimaryContainer,
                    side: BorderSide(
                      color: _priceRange == range
                          ? AppColors.brandPrimary
                          : AppColors.border,
                    ),
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('home-minimum-price-field'),
                    controller: _minimumController,
                    onChanged: _markCustomRange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minimum',
                      prefixText: r'$',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    key: const Key('home-maximum-price-field'),
                    controller: _maximumController,
                    onChanged: _markCustomRange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Maximum',
                      prefixText: r'$',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: const Key('home-sustainable-filter'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Sustainable items only'),
              subtitle: const Text('Show pre-loved items with an eco cue'),
              value: _sustainableOnly,
              onChanged: (value) =>
                  setState(() => _sustainableOnly = value ?? false),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('home-apply-filters'),
                onPressed: _apply,
                child: const Text('Show products'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
