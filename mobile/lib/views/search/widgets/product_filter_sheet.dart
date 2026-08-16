import 'package:flutter/material.dart';

import '../../../providers/search_provider.dart';
import '../../../theme/app_theme.dart';

class ProductFilterSheet extends StatefulWidget {
  final SearchProvider filters;

  const ProductFilterSheet({super.key, required this.filters});

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late bool _sustainableOnly;

  @override
  void initState() {
    super.initState();
    _minimumController = TextEditingController(
      text: widget.filters.minimumPrice?.toStringAsFixed(0) ?? '',
    );
    _maximumController = TextEditingController(
      text: widget.filters.maximumPrice?.toStringAsFixed(0) ?? '',
    );
    _sustainableOnly = widget.filters.sustainableOnly;
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _apply() {
    final minimum = double.tryParse(_minimumController.text.trim());
    final maximum = double.tryParse(_maximumController.text.trim());
    if (minimum != null && maximum != null && minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum price must not exceed maximum price.'),
        ),
      );
      return;
    }
    widget.filters.setPriceRange(minimum: minimum, maximum: maximum);
    if (widget.filters.sustainableOnly != _sustainableOnly) {
      widget.filters.toggleSustainableOnly();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter products',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Price range (NZD)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('minimum-price-field'),
                  controller: _minimumController,
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
                  key: const Key('maximum-price-field'),
                  controller: _maximumController,
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
            contentPadding: EdgeInsets.zero,
            title: const Text('Sustainable items only'),
            subtitle: const Text(
              'Show pre-loved items with a sustainability cue',
            ),
            value: _sustainableOnly,
            onChanged: (value) =>
                setState(() => _sustainableOnly = value ?? false),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _apply,
              child: const Text('Show products'),
            ),
          ),
        ],
      ),
    ),
  );
}
