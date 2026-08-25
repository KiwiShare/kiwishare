import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discovery_options_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../repositories/item_repository.dart';
import '../../theme/app_theme.dart';

class ProductEditScreen extends StatefulWidget {
  final ItemModel item;
  final DiscoveryOptionsModel options;

  const ProductEditScreen({
    super.key,
    required this.item,
    required this.options,
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _location;
  late final TextEditingController _condition;
  late String _category;
  late bool _negotiable;
  late bool _sustainable;
  bool _saving = false;
  String? _error;

  List<String> get _categories => _withCurrentValue(
    widget.options.categories.map((option) => option.value),
    _category,
  );

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _description = TextEditingController(text: widget.item.description);
    _price = TextEditingController(text: widget.item.priceNzd);
    _location = TextEditingController(text: widget.item.location);
    _condition = TextEditingController(text: widget.item.condition ?? '');
    _category = widget.item.category;
    _negotiable = widget.item.negotiable;
    _sustainable = widget.item.isSustainable;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _location.dispose();
    _condition.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Log in again before editing this listing.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<ListingProvider>().updateItem(
        itemId: widget.item.id,
        token: token,
        draft: ItemUpdateDraft(
          title: _title.text,
          description: _description.text,
          category: _category,
          condition: _condition.text,
          priceNzd: _price.text,
          location: _location.text,
          negotiable: _negotiable,
          isSustainable: _sustainable,
        ),
      );
      if (mounted) Navigator.pop(context, updated);
    } on ItemRepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The listing could not be updated. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit listing')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                key: const Key('edit_listing_title'),
                controller: _title,
                enabled: !_saving,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  return length < 3 ? 'Enter at least 3 characters.' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('edit_listing_description'),
                controller: _description,
                enabled: !_saving,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('edit_listing_price'),
                controller: _price,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.item.currency.isEmpty
                      ? 'Price'
                      : 'Price (${widget.item.currency})',
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  return price == null || price < 0
                      ? 'Enter a valid non-negative price.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: const Key('edit_listing_category'),
                initialValue: _category,
                items: _categories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value ?? _category),
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Choose a category.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('edit_listing_condition'),
                controller: _condition,
                enabled: !_saving,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Condition',
                  helperText: widget.options.conditions.isEmpty
                      ? null
                      : 'Existing values: ${widget.options.conditions.map((option) => _displayValue(option.value)).join(', ')}',
                  helperMaxLines: 2,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Choose a condition.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('edit_listing_location'),
                controller: _location,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Approximate location',
                  helperText: 'Use a suburb and city, not a street address.',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter an approximate location.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                key: const Key('edit_listing_negotiable'),
                contentPadding: EdgeInsets.zero,
                value: _negotiable,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _negotiable = value),
                title: const Text('Price is negotiable'),
              ),
              SwitchListTile.adaptive(
                key: const Key('edit_listing_sustainable'),
                contentPadding: EdgeInsets.zero,
                value: _sustainable,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _sustainable = value),
                title: const Text('Sustainable choice'),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error,
                  key: const Key('edit_listing_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const Key('save_listing_button'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _withCurrentValue(Iterable<String> values, String current) {
  final result = <String>{
    ...values.where((value) => value.trim().isNotEmpty),
    if (current.trim().isNotEmpty) current,
  }.toList(growable: false);
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

String _displayValue(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
