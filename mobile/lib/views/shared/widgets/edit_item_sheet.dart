import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/listing_provider.dart';

class EditItemSheet extends StatefulWidget {
  final ItemModel item;
  final ValueChanged<ItemModel>? onUpdated;

  const EditItemSheet({super.key, required this.item, this.onUpdated});

  static Future<ItemModel?> show(
    BuildContext context, {
    required ItemModel item,
  }) {
    return showModalBottomSheet<ItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditItemSheet(item: item),
    );
  }

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;

  static const _categories = <String>[
    'Furniture',
    'Electronics',
    'Books',
    'Home',
    'Sports',
    'Kids',
    'Fashion',
    'Other',
  ];

  static const _conditions = <String>['New', 'Like new', 'Good', 'Fair'];

  late String _category;
  late String _condition;
  late ItemStatus _status;
  bool _isFree = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descController = TextEditingController(text: widget.item.description);
    _priceController = TextEditingController(text: widget.item.priceNzd);
    _imageUrlController = TextEditingController(text: widget.item.imageUrl);
    _category = _categories.contains(widget.item.category)
        ? widget.item.category
        : 'Other';
    final condStr = widget.item.condition?.toLowerCase() ?? 'good';
    _condition = _conditions.firstWhere(
      (c) => c.toLowerCase() == condStr,
      orElse: () => 'Good',
    );
    _status = widget.item.status;
    _isFree = widget.item.priceNzd == '0' || widget.item.priceNzd.isEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final token = context.read<AuthProvider?>()?.jwtToken;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Please log in to edit this item.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final finalPrice = _isFree ? '0' : _priceController.text.trim();
    final statusStr = _status == ItemStatus.active
        ? 'active'
        : _status == ItemStatus.reserved
        ? 'reserved'
        : 'sold';

    final updates = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'category': _category,
      'condition': _condition,
      'priceNzd': finalPrice,
      'status': statusStr,
      if (_imageUrlController.text.trim().isNotEmpty)
        'imageUrl': _imageUrlController.text.trim(),
    };

    try {
      final updated = await context.read<ListingProvider>().updateItem(
        id: widget.item.id,
        token: token,
        updates: updates,
      );
      if (!mounted) return;
      widget.onUpdated?.call(updated);
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar & header
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Listing',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),

                // Status & Quick Re-list
                Text(
                  'Listing Status',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _status == ItemStatus.active
                      ? '🟢 Available: Visible & searchable by all students on campus.'
                      : _status == ItemStatus.reserved
                      ? '🟡 Reserved: Held for a buyer (e.g. meetup scheduled).'
                      : '⚪ Sold: Deal completed; item marked as sold.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ItemStatus>(
                  segments: const [
                    ButtonSegment(
                      value: ItemStatus.active,
                      label: Text('Available'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: ItemStatus.reserved,
                      label: Text('Reserved'),
                      icon: Icon(Icons.lock_clock),
                    ),
                    ButtonSegment(
                      value: ItemStatus.sold,
                      label: Text('Sold'),
                      icon: Icon(Icons.task_alt),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (set) {
                    setState(() => _status = set.first);
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Item Title *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 14),

                // Price & Free toggle
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        enabled: !_isFree,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _isFree ? 'Free Item' : 'Price (NZD) *',
                          prefixText: _isFree ? '' : '\$ ',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        validator: (v) {
                          if (_isFree) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter price';
                          }
                          final numVal = double.tryParse(v.trim());
                          if (numVal == null || numVal < 0) {
                            return 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Free'),
                      selected: _isFree,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade800,
                      onSelected: (val) {
                        setState(() {
                          _isFree = val;
                          if (val) _priceController.text = '0';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category & Condition
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _condition,
                        decoration: const InputDecoration(
                          labelText: 'Condition',
                          border: OutlineInputBorder(),
                        ),
                        items: _conditions
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _condition = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Image URL
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Photo Image URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image_outlined),
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isLoading ? 'Saving Changes...' : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
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
