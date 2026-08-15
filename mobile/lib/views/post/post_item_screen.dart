import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/listing_image_picker.dart';
import '../../theme/app_theme.dart';

class PostItemScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback? onPostItem;
  final ListingImagePicker? imagePicker;

  const PostItemScreen({
    super.key,
    required this.onCancel,
    this.onPostItem,
    this.imagePicker,
  });

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  static const _maximumPhotoCount = 10;
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
  static const _locations = <String>[
    'Auckland CBD',
    'North Shore',
    'Manukau',
    'Waitakere',
    'Other',
  ];
  static const _conditions = <String>['New', 'Like new', 'Good', 'Fair'];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final ListingImagePicker _imagePicker;

  String? _category;
  String? _location;
  String? _condition;
  final List<_SelectedPhoto> _photos = [];
  bool _isPickingPhotos = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPhotos());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _recoverLostPhotos() async {
    try {
      final files = await _imagePicker.recoverLostPhotos();
      await _addPhotos(files);
    } on PlatformException catch (error) {
      _showPhotoError(error);
    } catch (_) {
      _showPhotoMessage('We could not restore the selected photos.');
    }
  }

  Future<void> _showPhotoSourcePicker() async {
    if (_isPickingPhotos || _photos.length >= _maximumPhotoCount) {
      return;
    }

    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source != null && mounted) {
      await _pickPhotos(source);
    }
  }

  Future<void> _pickPhotos(_PhotoSource source) async {
    final remaining = _maximumPhotoCount - _photos.length;
    if (remaining <= 0) {
      return;
    }

    setState(() => _isPickingPhotos = true);
    try {
      final files = switch (source) {
        _PhotoSource.camera => <XFile>[?await _imagePicker.takePhoto()],
        _PhotoSource.gallery => await _imagePicker.chooseFromGallery(
          limit: remaining,
        ),
      };
      await _addPhotos(files);
    } on PlatformException catch (error) {
      _showPhotoError(error);
    } catch (_) {
      _showPhotoMessage('We could not add that photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isPickingPhotos = false);
      }
    }
  }

  Future<void> _addPhotos(List<XFile> files) async {
    if (files.isEmpty || !mounted) {
      return;
    }

    final remaining = _maximumPhotoCount - _photos.length;
    final loadedPhotos = <_SelectedPhoto>[];
    var failedCount = 0;

    for (final file in files.take(remaining)) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          failedCount += 1;
          continue;
        }
        loadedPhotos.add(_SelectedPhoto(file: file, bytes: bytes));
      } catch (_) {
        failedCount += 1;
      }
    }

    if (!mounted) {
      return;
    }
    if (loadedPhotos.isNotEmpty) {
      setState(() => _photos.addAll(loadedPhotos));
    }
    if (failedCount > 0) {
      _showPhotoMessage(
        failedCount == 1
            ? 'One photo could not be read.'
            : '$failedCount photos could not be read.',
      );
    }
    if (files.length > remaining) {
      _showPhotoMessage('You can add up to 10 photos.');
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) {
      return;
    }
    setState(() => _photos.removeAt(index));
  }

  void _showPhotoError(PlatformException error) {
    final denied =
        error.code.contains('denied') || error.code.contains('permission');
    _showPhotoMessage(
      denied
          ? 'Camera or photo access was denied. Allow access in Settings and try again.'
          : 'We could not open your camera or photos. Please try again.',
    );
  }

  void _showPhotoMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateForm({required bool requirePhoto}) {
    final fieldsAreValid = _formKey.currentState?.validate() ?? false;
    if (requirePhoto && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo to continue.')),
      );
      return false;
    }
    return fieldsAreValid;
  }

  void _showPreview() {
    if (!_validateForm(requirePhoto: false)) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listing preview',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_photos.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.memory(
                        _photos.first.bytes,
                        fit: BoxFit.cover,
                        semanticLabel: 'First listing photo',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  _titleController.text.trim(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '\$${_priceController.text.trim()} · ${_condition ?? ''}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_category ?? ''} · ${_location ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_descriptionController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _descriptionController.text.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _postItem() {
    if (!_validateForm(requirePhoto: true)) {
      return;
    }

    if (widget.onPostItem != null) {
      widget.onPostItem!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your listing is ready to publish.')),
    );
  }

  String? _requiredTextValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _priceValidator(String? value) {
    final requiredError = _requiredTextValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    final price = double.tryParse(value!);
    if (price == null || price <= 0) {
      return 'Enter a valid price';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final useAccessibleHeader = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: useAccessibleHeader ? 112 : 64,
        titleSpacing: AppSpacing.sm,
        title: useAccessibleHeader
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Post an item',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        key: const Key('post_cancel_button'),
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        key: const Key('post_preview_button'),
                        onPressed: _showPreview,
                        child: const Text('Preview'),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('post_cancel_button'),
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Post an item',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('post_preview_button'),
                        onPressed: _showPreview,
                        child: const Text('Preview'),
                      ),
                    ),
                  ),
                ],
              ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('post_item_form'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _PhotosSection(
                photos: _photos,
                isPickingPhotos: _isPickingPhotos,
                onAddPhoto: _showPhotoSourcePicker,
                onRemovePhoto: _removePhoto,
              ),
              const SizedBox(height: AppSpacing.xl),
              _ResponsiveFieldRow(
                label: 'Title',
                child: TextFormField(
                  key: const Key('post_title_field'),
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Solid Wood Desk',
                  ),
                  validator: _requiredTextValidator,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFieldRow(
                label: 'Category',
                child: _MobileSelectionFormField(
                  key: const Key('post_category_field'),
                  value: _category,
                  hintText: 'Select a category',
                  sheetTitle: 'Choose category',
                  options: _categories,
                  onChanged: (value) => setState(() => _category = value),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFieldRow(
                label: 'Price',
                child: TextFormField(
                  key: const Key('post_price_field'),
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                    ),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    hintText: 'e.g. 120',
                  ),
                  validator: _priceValidator,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFieldRow(
                label: 'Location',
                child: _MobileSelectionFormField(
                  key: const Key('post_location_field'),
                  value: _location,
                  hintText: 'Auckland CBD',
                  sheetTitle: 'Choose location',
                  options: _locations,
                  onChanged: (value) => setState(() => _location = value),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFieldRow(
                label: 'Condition',
                child: _MobileSelectionFormField(
                  key: const Key('post_condition_field'),
                  value: _condition,
                  hintText: 'Select condition',
                  sheetTitle: 'Choose condition',
                  options: _conditions,
                  onChanged: (value) => setState(() => _condition = value),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('post_description_field'),
                controller: _descriptionController,
                minLines: 5,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Describe your item, its condition and any details.',
                  alignLabelWithHint: true,
                ),
                validator: _requiredTextValidator,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const Key('post_submit_button'),
                onPressed: _postItem,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                child: const Text('Post item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  final List<_SelectedPhoto> photos;
  final bool isPickingPhotos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;

  const _PhotosSection({
    required this.photos,
    required this.isPickingPhotos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final useAccessibleHeight = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photos', style: Theme.of(context).textTheme.labelLarge),
            Text(
              '${photos.length}/10',
              key: const Key('post_photo_count'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          label: 'Add photos. ${photos.length} of 10 selected.',
          child: CustomPaint(
            painter: const _DashedRoundedBorderPainter(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('post_add_photos_button'),
                onTap: photos.length < 10 && !isPickingPhotos
                    ? onAddPhoto
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: SizedBox(
                  width: double.infinity,
                  height: useAccessibleHeight ? 240 : 152,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPickingPhotos)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.brandPrimary),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 24,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        isPickingPhotos ? 'Adding photos…' : 'Add photos',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textBrand,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        photos.length >= 10
                            ? 'Maximum of 10 photos reached'
                            : 'Use your camera or choose from your device',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 52,
          child: ListView.separated(
            key: const Key('post_photo_slots'),
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final hasPhoto = index < photos.length;
              return Semantics(
                button: hasPhoto,
                label: hasPhoto
                    ? 'Photo ${index + 1}. Tap to remove.'
                    : 'Empty photo slot ${index + 1}.',
                child: InkWell(
                  key: Key('post_photo_slot_$index'),
                  onTap: hasPhoto ? () => onRemovePhoto(index) : null,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: SizedBox.square(
                    dimension: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: hasPhoto
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  photos[index].bytes,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  semanticLabel:
                                      'Photo ${index + 1}: ${photos[index].file.name}',
                                ),
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xB3000000),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const ColoredBox(color: AppColors.surfaceMuted),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _PhotoSource { camera, gallery }

class _SelectedPhoto {
  final XFile file;
  final Uint8List bytes;

  const _SelectedPhoto({required this.file, required this.bytes});
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add photos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('post_take_photo_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Open your device camera'),
              onTap: () => Navigator.pop(context, _PhotoSource.camera),
            ),
            ListTile(
              key: const Key('post_choose_gallery_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select one or more existing photos'),
              onTap: () => Navigator.pop(context, _PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _ResponsiveFieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.labelLarge,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
        final useStackedLayout =
            constraints.maxWidth < 344 || scaledLabelSize > 18;

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 68,
              height: 48,
              child: Align(alignment: Alignment.centerLeft, child: labelWidget),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _MobileSelectionFormField extends StatelessWidget {
  final String? value;
  final String hintText;
  final String sheetTitle;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _MobileSelectionFormField({
    super.key,
    required this.value,
    required this.hintText,
    required this.sheetTitle,
    required this.options,
    required this.onChanged,
  });

  Future<String?> _showOptions(BuildContext context, String? selectedValue) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (context) => _SelectionSheet(
        title: sheetTitle,
        options: options,
        selectedValue: selectedValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: (value) => value == null ? 'Required' : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        return Semantics(
          button: true,
          label: '$sheetTitle. ${field.value ?? 'No option selected'}.',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: () async {
              final selectedValue = await _showOptions(context, field.value);
              if (selectedValue == null) {
                return;
              }
              field.didChange(selectedValue);
              onChanged(selectedValue);
            },
            child: InputDecorator(
              isEmpty: field.value == null,
              decoration: InputDecoration(
                hintText: hintText,
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.chevron_right_rounded),
              ),
              child: Text(field.value ?? ''),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selectedValue;

  const _SelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          key: const Key('post_selection_sheet'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final optionWidth =
                      (constraints.maxWidth - AppSpacing.sm) / 2;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: options.map((option) {
                      final isSelected = option == selectedValue;
                      return SizedBox(
                        width: optionWidth,
                        child: Semantics(
                          selected: isSelected,
                          button: true,
                          child: Material(
                            color: isSelected
                                ? AppColors.brandSecondaryContainer
                                : AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.border,
                              ),
                            ),
                            child: InkWell(
                              key: Key('post_selection_option_$option'),
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              onTap: () => Navigator.pop(context, option),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.medium),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 6, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
