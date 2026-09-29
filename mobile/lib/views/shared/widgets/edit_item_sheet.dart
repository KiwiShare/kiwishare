import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../models/listing_category_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/listing_provider.dart';
import '../../../services/listing_image_picker.dart';
import '../../../services/r2_upload_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/resilient_network_image.dart';

class EditItemSheet extends StatefulWidget {
  const EditItemSheet({
    super.key,
    required this.item,
    this.onUpdated,
    this.imagePicker,
    this.photoUploader,
  });

  final ItemModel item;
  final ValueChanged<ItemModel>? onUpdated;
  final ListingImagePicker? imagePicker;
  final ListingPhotoUploader? photoUploader;

  static Future<ItemModel?> show(
    BuildContext context, {
    required ItemModel item,
  }) async {
    if (item.status == ItemStatus.sold) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: const Text('Sold listing is locked'),
          content: const Text(
            'Refund or cancel the paid order first. After the transaction is reversed, the listing can be edited again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return null;
    }

    return Navigator.of(context).push<ItemModel>(
      MaterialPageRoute<ItemModel>(
        fullscreenDialog: true,
        builder: (_) => EditItemSheet(item: item),
      ),
    );
  }

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  static const _maximumPhotoCount = 10;
  static const _conditions = <String>['New', 'Like new', 'Good', 'Fair'];

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _attributeControllers = {};
  final Map<String, String> _attributeSelections = {};

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late final ListingImagePicker _imagePicker;
  late final ListingPhotoUploader _photoUploader;
  late final List<String> _categories;

  final List<_EditableListingPhoto> _photos = [];

  late String _category;
  late String _condition;
  late ItemStatus _status;
  late bool _isFree;
  late bool _isSustainable;

  int _selectedPhotoIndex = 0;
  bool _isSaving = false;
  bool _isPickingPhoto = false;
  String? _saveStage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
    _photoUploader = widget.photoUploader ?? R2UploadService();

    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _priceController = TextEditingController(text: widget.item.priceNzd);
    _locationController = TextEditingController(text: widget.item.location);

    _categories = <String>[...listingCategoryNames];
    if (!_categories.contains(widget.item.category) &&
        widget.item.category.trim().isNotEmpty) {
      _categories.add(widget.item.category);
    }
    _category = _categories.contains(widget.item.category)
        ? widget.item.category
        : 'Other';

    final normalizedCondition =
        widget.item.condition?.toLowerCase().replaceAll('_', ' ') ?? 'good';
    _condition = _conditions.firstWhere(
      (condition) => condition.toLowerCase() == normalizedCondition,
      orElse: () => 'Good',
    );

    _status = widget.item.status;
    _isFree = widget.item.isFree;
    _isSustainable = widget.item.isSustainable;

    for (final url in widget.item.allImages) {
      if (url.trim().isNotEmpty) {
        _photos.add(_EditableListingPhoto.remote(url.trim()));
      }
    }

    for (final definition in listingCategoryDefinitions) {
      for (final field in definition.attributes) {
        if (field.type != ListingAttributeInputType.choice) {
          _attributeControllers.putIfAbsent(
            field.key,
            TextEditingController.new,
          );
        }
      }
    }
    _hydrateAttributes(widget.item.attributes);
  }

  void _hydrateAttributes(Map<String, String> attributes) {
    final definition = listingCategoryDefinition(_category);
    for (final field
        in definition?.attributes ?? const <ListingAttributeField>[]) {
      final value = attributes[field.key]?.trim() ?? '';
      if (value.isEmpty) continue;
      if (field.type == ListingAttributeInputType.choice) {
        final canonical = field.options.where(
          (option) => option.toLowerCase() == value.toLowerCase(),
        );
        if (canonical.isNotEmpty) {
          _attributeSelections[field.key] = canonical.first;
        }
      } else {
        _attributeController(field.key).text = value;
      }
    }
  }

  TextEditingController _attributeController(String key) {
    return _attributeControllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _currentAttributes() {
    final definition = listingCategoryDefinition(_category);
    if (definition == null) return const {};
    final result = <String, String>{};
    for (final field in definition.attributes) {
      final value = field.type == ListingAttributeInputType.choice
          ? _attributeSelections[field.key]?.trim()
          : _attributeControllers[field.key]?.text.trim();
      if (value != null && value.isNotEmpty) {
        result[field.key] = value;
      }
    }
    return result;
  }

  String _statusLabel(ItemStatus status) => switch (status) {
    ItemStatus.active => 'Available',
    ItemStatus.reserved => 'Reserved',
    ItemStatus.delisted => 'Hidden',
    ItemStatus.sold => 'Sold',
  };

  String _statusDescription(ItemStatus status) => switch (status) {
    ItemStatus.active => 'Visible in marketplace search and discovery.',
    ItemStatus.reserved =>
      'Reserved for a buyer. This state is normally managed by the transaction flow.',
    ItemStatus.delisted =>
      'Hidden from buyers until you make it available again.',
    ItemStatus.sold => 'Sold listings cannot be edited.',
  };

  IconData _statusIcon(ItemStatus status) => switch (status) {
    ItemStatus.active => Icons.public_rounded,
    ItemStatus.reserved => Icons.schedule_rounded,
    ItemStatus.delisted => Icons.visibility_off_outlined,
    ItemStatus.sold => Icons.lock_rounded,
  };

  Future<_PhotoSource?> _choosePhotoSource({required String title}) {
    return showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                key: const Key('edit_photo_camera_option'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a new photo'),
                subtitle: const Text('Open the camera'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoSource.camera),
              ),
              ListTile(
                key: const Key('edit_photo_gallery_option'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Photos'),
                subtitle: const Text('Select from your photo library'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<XFile>> _pickSourceFiles(
    _PhotoSource source, {
    required int limit,
  }) async {
    if (source == _PhotoSource.camera) {
      final file = await _imagePicker.takePhoto();
      return <XFile>[?file];
    }
    return _imagePicker.chooseFromGallery(limit: limit);
  }

  Future<_EditableListingPhoto?> _loadLocalPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return _EditableListingPhoto.local(
      bytes: bytes,
      fileName: _photoFileName(file),
      contentType: _photoContentType(file),
    );
  }

  Future<void> _addPhotos({required _PhotoSource source}) async {
    if (_isPickingPhoto || _photos.length >= _maximumPhotoCount) {
      if (_photos.length >= _maximumPhotoCount) {
        _showMessage('You can keep up to $_maximumPhotoCount photos.');
      }
      return;
    }

    setState(() => _isPickingPhoto = true);
    try {
      final remaining = _maximumPhotoCount - _photos.length;
      final files = await _pickSourceFiles(source, limit: remaining);
      if (files.isEmpty) return;

      final loaded = <_EditableListingPhoto>[];
      for (final file in files.take(remaining)) {
        final photo = await _loadLocalPhoto(file);
        if (photo != null) loaded.add(photo);
      }
      if (!mounted || loaded.isEmpty) return;
      setState(() {
        final firstNewIndex = _photos.length;
        _photos.addAll(loaded);
        _selectedPhotoIndex = firstNewIndex;
        _errorMessage = null;
      });
    } on PlatformException catch (error) {
      _showPickerError(error);
    } catch (_) {
      _showMessage('We could not read that photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _replacePhoto(int index) async {
    if (_isPickingPhoto || index < 0 || index >= _photos.length) return;
    final source = await _choosePhotoSource(title: 'Replace this photo');
    if (source == null || !mounted) return;

    setState(() => _isPickingPhoto = true);
    try {
      final files = await _pickSourceFiles(source, limit: 1);
      if (files.isEmpty) return;
      final replacement = await _loadLocalPhoto(files.first);
      if (!mounted || replacement == null) return;
      setState(() {
        _photos[index] = replacement;
        _selectedPhotoIndex = index;
        _errorMessage = null;
      });
    } on PlatformException catch (error) {
      _showPickerError(error);
    } catch (_) {
      _showMessage('We could not replace that photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _photos.removeAt(index);
      if (_photos.isEmpty) {
        _selectedPhotoIndex = 0;
      } else if (_selectedPhotoIndex >= _photos.length) {
        _selectedPhotoIndex = _photos.length - 1;
      } else if (_selectedPhotoIndex > index) {
        _selectedPhotoIndex -= 1;
      }
    });
  }

  void _setCoverPhoto(int index) {
    if (index <= 0 || index >= _photos.length) return;
    setState(() {
      final photo = _photos.removeAt(index);
      _photos.insert(0, photo);
      _selectedPhotoIndex = 0;
    });
    _showMessage('Cover photo updated.');
  }

  void _showPickerError(PlatformException error) {
    final code = error.code.toLowerCase();
    final denied = code.contains('denied') || code.contains('permission');
    _showMessage(
      denied
          ? 'Camera or photo access is disabled. Allow KiwiShare access in Settings and try again.'
          : 'We could not open your camera or photos. Please try again.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _photoContentType(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  String _photoFileName(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final extension = switch (_photoContentType(file)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    return 'listing_edit_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  DateTime? _parseAttributeDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      final year = int.tryParse(trimmed);
      return year == null ? null : DateTime(year);
    }
    return DateTime.tryParse(trimmed);
  }

  String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickAttributeDate(ListingAttributeField field) async {
    final controller = _attributeController(field.key);
    final existing = _parseAttributeDate(controller.text);
    final now = DateTime.now();
    final firstYear = field.min?.toInt() ?? 1900;
    final lastYear = field.max?.toInt() ?? 2100;
    final initialYear = (existing?.year ?? now.year).clamp(firstYear, lastYear);
    final initialDate = field.type == ListingAttributeInputType.year
        ? DateTime(initialYear)
        : (existing ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(firstYear),
      lastDate: DateTime(lastYear, 12, 31),
      initialDatePickerMode: field.type == ListingAttributeInputType.year
          ? DatePickerMode.year
          : DatePickerMode.day,
      helpText: 'Select ${field.label.toLowerCase()}',
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = field.type == ListingAttributeInputType.year
          ? picked.year.toString()
          : _isoDate(picked);
    });
  }

  String? _attributeValidator(ListingAttributeField field, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (field.type != ListingAttributeInputType.number &&
        field.type != ListingAttributeInputType.year) {
      return null;
    }
    final number = num.tryParse(text);
    if (number == null) return 'Enter a valid number';
    if (field.min != null && number < field.min!) {
      return 'Minimum ${field.min}';
    }
    if (field.max != null && number > field.max!) {
      return 'Maximum ${field.max}';
    }
    return null;
  }

  String? _priceValidator(String? value) {
    if (_isFree) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a price';
    final price = double.tryParse(text);
    if (price == null || price < 0) return 'Enter a valid price';
    return null;
  }

  Future<List<String>> _resolvePhotoUrls(String authToken) async {
    final urls = <String>[];
    final localCount = _photos.where((photo) => photo.bytes != null).length;
    var uploaded = 0;

    for (final photo in _photos) {
      if (photo.url != null) {
        urls.add(photo.url!);
        continue;
      }
      uploaded += 1;
      if (mounted) {
        setState(() {
          _saveStage = localCount == 1
              ? 'Uploading new photo…'
              : 'Uploading photo $uploaded of $localCount…';
        });
      }
      urls.add(
        await _photoUploader.uploadImage(
          bytes: photo.bytes!,
          fileName: photo.fileName!,
          contentType: photo.contentType!,
          authToken: authToken,
        ),
      );
    }
    return urls;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      setState(() => _errorMessage = 'Keep at least one photo on the listing.');
      return;
    }

    final auth = context.read<AuthProvider?>();
    final token = auth?.jwtToken;
    if (token == null || token.isEmpty) {
      setState(
        () => _errorMessage = 'Please sign in again to edit this listing.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _saveStage = 'Preparing changes…';
      _errorMessage = null;
    });

    try {
      final imageUrls = await _resolvePhotoUrls(token);
      if (!mounted) return;
      setState(() => _saveStage = 'Saving listing…');

      final normalizedCondition = _condition.trim().toLowerCase().replaceAll(
        RegExp(r'[\s-]+'),
        '_',
      );

      final status = switch (_status) {
        ItemStatus.active => 'active',
        ItemStatus.reserved => 'reserved',
        ItemStatus.delisted => 'draft',
        ItemStatus.sold => 'sold',
      };

      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'condition': normalizedCondition,
        'priceNzd': _isFree ? '0' : _priceController.text.trim(),
        'status': status,
        'isSustainable': _isSustainable,
        'location': _locationController.text.trim(),
        'attributes': _currentAttributes(),
        'imageUrl': imageUrls.first,
        'images': [
          for (var index = 0; index < imageUrls.length; index++)
            {
              'url': imageUrls[index],
              'thumbnailUrl': imageUrls[index],
              'sortOrder': index,
            },
        ],
      };

      final updated = await context.read<ListingProvider>().updateItem(
        id: widget.item.id,
        token: token,
        updates: updates,
      );
      if (!mounted) return;

      widget.onUpdated?.call(updated);
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Listing updated.')));
    } on ListingPhotoAuthenticationException catch (error) {
      await auth?.clearSession();
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on ListingPhotoUploadException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStage = null;
        });
      }
    }
  }

  Future<void> _pickCategory() async {
    final selected = await _showOptionPicker(
      title: 'Category',
      options: _categories,
      selected: _category,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _category = selected;
      _errorMessage = null;
    });
  }

  Future<void> _pickCondition() async {
    final selected = await _showOptionPicker(
      title: 'Condition',
      options: _conditions,
      selected: _condition,
    );
    if (selected == null || !mounted) return;
    setState(() => _condition = selected);
  }

  Future<String?> _showOptionPicker({
    required String title,
    required List<String> options,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: options.length,
                  itemBuilder: (_, index) {
                    final option = options[index];
                    final isSelected = option == selected;
                    return ListTile(
                      title: Text(option),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(_EditableListingPhoto photo, {required BoxFit fit}) {
    if (photo.bytes != null) {
      return Image.memory(photo.bytes!, fit: fit, gaplessPlayback: true);
    }
    return ResilientNetworkImage(
      url: photo.url!,
      logicalCacheWidth: 760,
      fit: fit,
      semanticLabel: 'Listing photo',
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasPhotos = _photos.isNotEmpty;
    final safeIndex = hasPhotos
        ? _selectedPhotoIndex.clamp(0, _photos.length - 1)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditSectionHeader(
          icon: Icons.photo_library_outlined,
          title: 'Photos',
          subtitle:
              '${_photos.length}/$_maximumPhotoCount · first photo is the cover',
        ),
        const SizedBox(height: AppSpacing.md),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            key: const Key('edit_photo_preview'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: hasPhotos
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPhoto(_photos[safeIndex], fit: BoxFit.cover),
                      Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: _PhotoBadge(
                          label: safeIndex == 0
                              ? 'Cover photo'
                              : 'Photo ${safeIndex + 1}',
                          icon: safeIndex == 0
                              ? Icons.star_rounded
                              : Icons.image_outlined,
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Row(
                          children: [
                            if (safeIndex != 0)
                              _PhotoActionButton(
                                tooltip: 'Set as cover',
                                icon: Icons.star_outline_rounded,
                                onPressed: () => _setCoverPhoto(safeIndex),
                              ),
                            const SizedBox(width: 6),
                            _PhotoActionButton(
                              key: const Key('edit_replace_photo_button'),
                              tooltip: 'Replace photo',
                              icon: Icons.cameraswitch_outlined,
                              onPressed: _isPickingPhoto
                                  ? null
                                  : () => _replacePhoto(safeIndex),
                            ),
                            const SizedBox(width: 6),
                            _PhotoActionButton(
                              tooltip: 'Remove photo',
                              icon: Icons.delete_outline_rounded,
                              onPressed: () => _removePhoto(safeIndex),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    key: const Key('edit_empty_photo_picker'),
                    onTap: _isPickingPhoto
                        ? null
                        : () => _addPhotos(source: _PhotoSource.gallery),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 46,
                            color: colors.primary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add a listing photo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Take a new one or choose from Photos',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (hasPhotos) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  _photos.length +
                  (_photos.length < _maximumPhotoCount ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == _photos.length) {
                  return _AddPhotoTile(
                    onTap: _isPickingPhoto
                        ? null
                        : () => _addPhotos(source: _PhotoSource.gallery),
                  );
                }
                final selected = index == safeIndex;
                return InkWell(
                  key: Key('edit_photo_thumbnail_$index'),
                  onTap: () => setState(() => _selectedPhotoIndex = index),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 76,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.outlineVariant.withValues(alpha: 0.45),
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPhoto(_photos[index], fit: BoxFit.cover),
                        if (index == 0)
                          const Positioned(
                            left: 4,
                            bottom: 4,
                            child: _PhotoBadge(
                              label: 'Cover',
                              icon: Icons.star_rounded,
                              compact: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('edit_take_photo_button'),
                onPressed:
                    _isPickingPhoto || _photos.length >= _maximumPhotoCount
                    ? null
                    : () => _addPhotos(source: _PhotoSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const Key('edit_choose_photo_button'),
                onPressed:
                    _isPickingPhoto || _photos.length >= _maximumPhotoCount
                    ? null
                    : () => _addPhotos(source: _PhotoSource.gallery),
                icon: _isPickingPhoto
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photos'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionHeader(
          icon: Icons.edit_note_rounded,
          title: 'Listing',
          subtitle: 'Keep the title clear and the description useful.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const Key('edit_item_title'),
          controller: _titleController,
          textInputAction: TextInputAction.next,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'What are you selling?',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Enter a title';
            if (value.trim().length < 3) return 'Use at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const Key('edit_item_description'),
          controller: _descriptionController,
          minLines: 4,
          maxLines: 7,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText:
                'Condition, what is included, and anything the buyer should know',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndCategorySection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionHeader(
          icon: Icons.sell_outlined,
          title: 'Price & category',
          subtitle: 'Change how the item is described in the marketplace.',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('edit_item_price'),
                controller: _priceController,
                enabled: !_isFree,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: _isFree ? null : r'$ ',
                  hintText: _isFree ? 'Free' : '0.00',
                ),
                validator: _priceValidator,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: _isFree
                    ? colors.primaryContainer.withValues(alpha: 0.55)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: _isFree
                      ? colors.primary.withValues(alpha: 0.35)
                      : colors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Text('Free'),
                  Switch(
                    key: const Key('edit_item_free_switch'),
                    value: _isFree,
                    onChanged: (value) {
                      setState(() {
                        _isFree = value;
                        if (value) _priceController.text = '0';
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _EditPickerTile(
                key: const Key('edit_item_category'),
                label: 'Category',
                value: _category,
                icon: Icons.category_outlined,
                onTap: _pickCategory,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _EditPickerTile(
                key: const Key('edit_item_condition'),
                label: 'Condition',
                value: _condition,
                icon: Icons.auto_awesome_outlined,
                onTap: _pickCondition,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryDetailsSection(BuildContext context) {
    final definition = listingCategoryDefinition(_category);
    if (definition == null || definition.attributes.isEmpty) {
      return const SizedBox.shrink();
    }

    final fields = <Widget>[];
    for (final field in definition.attributes) {
      Widget input;
      if (field.type == ListingAttributeInputType.choice) {
        input = DropdownButtonFormField<String>(
          key: Key('edit_attribute_${field.key}'),
          value: _attributeSelections[field.key],
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: 'Optional',
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            setState(() {
              if (value == null) {
                _attributeSelections.remove(field.key);
              } else {
                _attributeSelections[field.key] = value;
              }
            });
          },
        );
      } else if (field.type == ListingAttributeInputType.date ||
          field.type == ListingAttributeInputType.year) {
        input = TextFormField(
          key: Key('edit_attribute_${field.key}'),
          controller: _attributeController(field.key),
          readOnly: true,
          onTap: () => _pickAttributeDate(field),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.type == ListingAttributeInputType.year
                ? 'Select year'
                : 'Select date',
            suffixIcon: const Icon(Icons.calendar_today_rounded),
          ),
          validator: (value) => _attributeValidator(field, value),
        );
      } else {
        input = TextFormField(
          key: Key('edit_attribute_${field.key}'),
          controller: _attributeController(field.key),
          keyboardType: field.type == ListingAttributeInputType.number
              ? const TextInputType.numberWithOptions(decimal: false)
              : TextInputType.text,
          inputFormatters: field.type == ListingAttributeInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint ?? 'Optional',
            suffixText: field.unit,
          ),
          validator: (value) => _attributeValidator(field, value),
        );
      }
      fields.add(input);
      fields.add(const SizedBox(height: AppSpacing.sm));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditSectionHeader(
          icon: _category == 'Cars & Vehicles'
              ? Icons.directions_car_outlined
              : Icons.tune_rounded,
          title: '${definition.name} details',
          subtitle: 'Optional details help buyers compare listings faster.',
        ),
        const SizedBox(height: AppSpacing.md),
        ...fields,
      ],
    );
  }

  Widget _buildLocationAndPreferencesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionHeader(
          icon: Icons.place_outlined,
          title: 'Location & preferences',
          subtitle: 'Update the meetup area and sustainability label.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const Key('edit_item_location'),
          controller: _locationController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Location',
            hintText: 'e.g. Newmarket, Auckland',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a location' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile.adaptive(
          key: const Key('edit_item_sustainable'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Eco choice'),
          subtitle: const Text(
            'Mark this as a pre-loved or reuse-focused item.',
          ),
          secondary: const Icon(Icons.eco_outlined),
          value: _isSustainable,
          onChanged: (value) => setState(() => _isSustainable = value),
        ),
      ],
    );
  }

  Widget _buildVisibilitySection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final options = _status == ItemStatus.reserved
        ? const <ItemStatus>[
            ItemStatus.reserved,
            ItemStatus.active,
            ItemStatus.delisted,
          ]
        : const <ItemStatus>[ItemStatus.active, ItemStatus.delisted];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionHeader(
          icon: Icons.visibility_outlined,
          title: 'Visibility',
          subtitle: 'Control whether buyers can discover this listing.',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final status in options) ...[
          InkWell(
            key: Key('edit_status_${status.name}'),
            onTap: () => setState(() => _status = status),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _status == status
                    ? colors.primaryContainer.withValues(alpha: 0.52)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: _status == status
                      ? colors.primary.withValues(alpha: 0.45)
                      : colors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(status),
                    color: _status == status
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(status),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusDescription(status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<ItemStatus>(
                    value: status,
                    groupValue: _status,
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('edit_item_error'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        key: const Key('edit_item_page'),
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('edit_item_close'),
            tooltip: 'Close',
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          title: const Text('Edit listing'),
          centerTitle: false,
          actions: [
            TextButton(
              key: const Key('edit_item_save_top'),
              onPressed: _isSaving ? null : _submit,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            key: const Key('edit_item_scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              128,
            ),
            children: [
              if (_errorMessage != null) ...[
                _buildErrorBanner(context),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildPhotoSection(context),
              const _EditSectionDivider(),
              _buildBasicsSection(context),
              const _EditSectionDivider(),
              _buildPriceAndCategorySection(context),
              if (listingCategoryDefinition(_category)?.attributes.isNotEmpty ==
                  true) ...[
                const _EditSectionDivider(),
                _buildCategoryDetailsSection(context),
              ],
              const _EditSectionDivider(),
              _buildLocationAndPreferencesSection(context),
              const _EditSectionDivider(),
              _buildVisibilitySection(context),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: FilledButton.icon(
              key: const Key('edit_item_save_button'),
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isSaving ? (_saveStage ?? 'Saving…') : 'Save changes',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoSource { camera, gallery }

class _EditableListingPhoto {
  const _EditableListingPhoto._({
    this.url,
    this.bytes,
    this.fileName,
    this.contentType,
  });

  factory _EditableListingPhoto.remote(String url) {
    return _EditableListingPhoto._(url: url);
  }

  factory _EditableListingPhoto.local({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    return _EditableListingPhoto._(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  final String? url;
  final Uint8List? bytes;
  final String? fileName;
  final String? contentType;
}

class _EditSectionHeader extends StatelessWidget {
  const _EditSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditSectionDivider extends StatelessWidget {
  const _EditSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Divider(
        height: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    );
  }
}

class _EditPickerTile extends StatelessWidget {
  const _EditPickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 11,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({
    required this.label,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        key: const Key('edit_add_photo_tile'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: colors.primary),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
