import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../repositories/item_repository.dart';
import '../../theme/app_theme.dart';

class ItemEditScreen extends StatefulWidget {
  const ItemEditScreen({super.key, required this.item});

  final ItemModel item;

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  static const _baseCategories = <String>[
    'Furniture',
    'Electronics',
    'Home & Garden',
    'Books',
    'Sports',
    'Kids',
    'Fashion',
    'Camping',
    'Plants',
    'Transport',
    'Other',
  ];
  static const _conditions = <String, String>{
    'new': 'New',
    'like_new': 'Like new',
    'good': 'Good',
    'fair': 'Fair',
    'poor': 'Poor',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late String _category;
  late String _condition;
  late bool _negotiable;
  late bool _isSustainable;
  var _isSaving = false;
  String? _errorMessage;

  List<String> get _categories => _baseCategories.contains(_category)
      ? _baseCategories
      : [_category, ..._baseCategories];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _priceController = TextEditingController(text: widget.item.priceNzd);
    _locationController = TextEditingController(text: widget.item.location);
    _descriptionController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _category = widget.item.category;
    _condition = _conditions.containsKey(widget.item.condition)
        ? widget.item.condition!
        : 'good';
    _negotiable = widget.item.negotiable;
    _isSustainable = widget.item.isSustainable;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().length < 3) {
      return 'Enter at least 3 characters.';
    }
    return null;
  }

  String? _priceValidator(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a valid price.';
    return null;
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) {
      setState(() => _errorMessage = 'Please log in again to edit this item.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await context.read<ListingProvider>().updateItem(
        item: widget.item.copyWith(
          title: _titleController.text.trim(),
          priceNzd: _priceController.text.trim(),
          location: _locationController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          condition: _condition,
          negotiable: _negotiable,
          isSustainable: _isSustainable,
        ),
        token: token,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ItemRepositoryException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Your changes could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit listing'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('edit_listing_form'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Listing details',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                key: const Key('edit_title_field'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('edit_price_field'),
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$ ',
                  suffixText: 'NZD',
                ),
                validator: _priceValidator,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                key: const Key('edit_category_field'),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                key: const Key('edit_condition_field'),
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: _conditions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _condition = value!),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('edit_location_field'),
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Approximate location',
                  helperText:
                      'Suburb and city only. Do not enter a street address.',
                  helperMaxLines: 2,
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('edit_description_field'),
                controller: _descriptionController,
                minLines: 5,
                maxLines: 8,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                key: const Key('edit_negotiable_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Price is negotiable'),
                value: _negotiable,
                onChanged: (value) => setState(() => _negotiable = value),
              ),
              SwitchListTile(
                key: const Key('edit_sustainable_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Sustainable choice'),
                subtitle: const Text(
                  'This item supports reuse or waste reduction.',
                ),
                value: _isSustainable,
                onChanged: (value) => setState(() => _isSustainable = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorMessage!,
                    key: const Key('edit_error_message'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const Key('edit_save_button'),
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
