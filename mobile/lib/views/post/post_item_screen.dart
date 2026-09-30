import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/listing_category_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../services/listing_image_picker.dart';
import '../../services/listing_location_service.dart';
import '../../services/listing_publish_service.dart';
import '../../services/listing_suggestion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/campus_locations.dart';

const TextStyle _postPlaceholderStyle = TextStyle(color: Color(0xFF94A3B8));

class PostItemScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback? onPostItem;
  final ListingImagePicker? imagePicker;
  final ListingLocationService? locationService;
  final ListingPublishService? publishService;
  final ListingSuggestionService? suggestionService;
  final String? authToken;
  final String? initialCategory;

  const PostItemScreen({
    super.key,
    required this.onCancel,
    this.onPostItem,
    this.imagePicker,
    this.locationService,
    this.publishService,
    this.suggestionService,
    this.authToken,
    this.initialCategory,
  });

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  static const _maximumPhotoCount = 10;
  static const _conditions = <String>['New', 'Like new', 'Good', 'Fair'];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Map<String, TextEditingController> _attributeControllers = {};
  final Map<String, String> _attributeSelections = {};
  late final ListingImagePicker _imagePicker;
  late final ListingLocationService _locationService;
  late final ListingPublishService _publishService;
  late final ListingSuggestionService _suggestionService;

  String? _category;
  late bool _flowStarted;
  ListingLocation? _location;
  String? _condition;
  final List<_SelectedPhoto> _photos = [];
  int _selectedPhotoIndex = 0;
  bool _isSustainable = false;
  bool _isPickingPhotos = false;
  bool _isLocating = false;
  bool _isPublishing = false;
  bool _isGeneratingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _category = listingCategoryNames.contains(widget.initialCategory)
        ? widget.initialCategory
        : null;
    _flowStarted = _category != null;
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
    _locationService = widget.locationService ?? DeviceListingLocationService();
    _publishService = widget.publishService ?? RestListingPublishService();
    _suggestionService =
        widget.suggestionService ?? RestListingSuggestionService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _recoverLostPhotos();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _attributeController(String key) {
    return _attributeControllers.putIfAbsent(key, TextEditingController.new);
  }

  Map<String, String> _currentAttributes() {
    final definition = listingCategoryDefinition(_category);
    if (definition == null) return const {};
    final result = <String, String>{};
    for (final field in definition.attributes) {
      final raw = field.type == ListingAttributeInputType.choice
          ? _attributeSelections[field.key]
          : _attributeControllers[field.key]?.text;
      final value = raw?.trim() ?? '';
      if (value.isNotEmpty) result[field.key] = value;
    }
    return result;
  }

  void _applySuggestion(ListingSuggestion suggestion) {
    _titleController.text = suggestion.title;
    _descriptionController.text = suggestion.description;
    _priceController.text = suggestion.priceNzd;
    _category = suggestion.category;
    _condition = suggestion.condition;

    final definition = listingCategoryDefinition(suggestion.category);
    for (final field
        in definition?.attributes ?? const <ListingAttributeField>[]) {
      final value = suggestion.attributes[field.key]?.trim() ?? '';
      if (value.isEmpty) continue;
      if (field.type == ListingAttributeInputType.choice) {
        String? matched;
        for (final option in field.options) {
          if (option.toLowerCase() == value.toLowerCase()) {
            matched = option;
            break;
          }
        }
        if (matched != null) _attributeSelections[field.key] = matched;
      } else {
        _attributeController(field.key).text = value;
      }
    }
  }

  Future<void> _startCategoryFlow() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _SelectionSheet(
        title: 'What are you selling?',
        options: listingCategoryNames,
        selectedValue: _category,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _category = selected;
      _flowStarted = true;
    });
  }

  Future<void> _startAiFlow() async {
    if (_isGeneratingSuggestion || _isPickingPhotos) return;
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    final before = _photos.length;
    await _pickPhotos(source);
    if (!mounted || _photos.length == before) return;
    await _requestSuggestion(autoApply: true, openFormAfter: true);
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
    if (field.required && text.isEmpty) return 'Required';
    if (text.isEmpty || field.type != ListingAttributeInputType.number) {
      return null;
    }
    final number = num.tryParse(text);
    if (number == null) return 'Enter a valid number';
    if (field.min != null && number < field.min!) return 'Minimum ${field.min}';
    if (field.max != null && number > field.max!) return 'Maximum ${field.max}';
    return null;
  }

  List<Widget> _buildCategoryAttributeFields(BuildContext context) {
    final definition = listingCategoryDefinition(_category);
    if (definition == null || definition.attributes.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.sm),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Row(
          children: [
            Icon(
              _category == 'Cars & Vehicles'
                  ? Icons.directions_car_outlined
                  : Icons.tune_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${definition.name} details',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          'These details are optional, but they help buyers compare listings more easily.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final field in definition.attributes) ...[
        _XianyuCardTile(
          child: _ResponsiveFieldRow(
            label: field.required ? '${field.label} *' : field.label,
            child: field.type == ListingAttributeInputType.choice
                ? _MobileSelectionFormField(
                    key: Key('post_attribute_${field.key}'),
                    value: _attributeSelections[field.key],
                    hintText:
                        field.hint ?? 'Select ${field.label.toLowerCase()}',
                    sheetTitle: field.label,
                    options: field.options,
                    required: field.required,
                    onChanged: (value) =>
                        setState(() => _attributeSelections[field.key] = value),
                  )
                : field.type == ListingAttributeInputType.date ||
                      field.type == ListingAttributeInputType.year
                ? TextFormField(
                    key: Key('post_attribute_${field.key}'),
                    controller: _attributeController(field.key),
                    readOnly: true,
                    onTap: () => _pickAttributeDate(field),
                    decoration: InputDecoration(
                      hintText:
                          field.hint ??
                          (field.type == ListingAttributeInputType.year
                              ? 'Select year'
                              : 'Select date'),
                      hintStyle: _postPlaceholderStyle,
                      suffixIcon: const Icon(Icons.calendar_today_rounded),
                    ),
                    validator: (value) => _attributeValidator(field, value),
                  )
                : TextFormField(
                    key: Key('post_attribute_${field.key}'),
                    controller: _attributeController(field.key),
                    keyboardType: field.type == ListingAttributeInputType.number
                        ? const TextInputType.numberWithOptions(decimal: false)
                        : TextInputType.text,
                    inputFormatters:
                        field.type == ListingAttributeInputType.number
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: field.hint ?? 'Optional',
                      hintStyle: _postPlaceholderStyle,
                      suffixText: field.unit,
                    ),
                    validator: (value) => _attributeValidator(field, value),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      setState(() {
        final previousCount = _photos.length;
        _photos.addAll(loadedPhotos);
        _selectedPhotoIndex = previousCount;
      });
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
    setState(() {
      _photos.removeAt(index);
      if (_photos.isEmpty) {
        _selectedPhotoIndex = 0;
      } else if (_selectedPhotoIndex >= _photos.length) {
        _selectedPhotoIndex = _photos.length - 1;
      } else if (_selectedPhotoIndex > index) {
        _selectedPhotoIndex--;
      }
    });
  }

  void _selectPhoto(int index) {
    if (index >= 0 && index < _photos.length) {
      setState(() => _selectedPhotoIndex = index);
    }
  }

  void _setCoverPhoto(int index) {
    if (index <= 0 || index >= _photos.length) return;
    setState(() {
      final photo = _photos.removeAt(index);
      _photos.insert(0, photo);
      _selectedPhotoIndex = 0;
    });
    _showPhotoMessage('Set as cover photo');
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

  Future<ListingLocation?> _findCurrentLocation() async {
    if (_isLocating) {
      return null;
    }

    setState(() => _isLocating = true);
    try {
      return await _locationService.getCurrentLocation();
    } on ListingLocationException catch (error) {
      _showLocationError(error.code);
      return null;
    } catch (_) {
      _showLocationError(ListingLocationErrorCode.unavailable);
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showLocationError(ListingLocationErrorCode code) {
    if (!mounted) {
      return;
    }

    final (message, action) = switch (code) {
      ListingLocationErrorCode.servicesDisabled => (
        'Location services are off. Turn them on and try again.',
        SnackBarAction(
          label: 'Settings',
          onPressed: _locationService.openLocationSettings,
        ),
      ),
      ListingLocationErrorCode.permissionDeniedForever => (
        'Location permission is blocked. Enable it in Settings and try again.',
        SnackBarAction(
          label: 'Settings',
          onPressed: _locationService.openAppSettings,
        ),
      ),
      ListingLocationErrorCode.permissionDenied => (
        'Location permission was denied. Allow it to use your current area.',
        null,
      ),
      ListingLocationErrorCode.timedOut => (
        'Finding your location took too long. Please try again.',
        null,
      ),
      ListingLocationErrorCode.unavailable => (
        'We could not find your current location. Please try again.',
        null,
      ),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
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
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateForm(requirePhoto: false)) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  '${_category ?? ''} · ${_location?.label ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isSustainable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Sustainable Item',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  void _showSustainableInfoDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'What is a Sustainable Item?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Supporting the Circular Economy on Campus',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF059669),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'In a circular economy, items are kept in circulation for as long as possible rather than ending up in New Zealand landfills. Reusing, sharing, and re-homing items drastically cuts carbon emissions and campus waste.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: isDark
                      ? Colors.grey.shade300
                      : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'What qualifies as sustainable?',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _buildBulletPoint(
                ctx,
                'Pre-loved textbooks, notes, and study essentials passed on to new students.',
              ),
              _buildBulletPoint(
                ctx,
                'Quality second-hand furniture and dorm gear given another lifecycle.',
              ),
              _buildBulletPoint(
                ctx,
                'Refurbished or working electronics and appliances.',
              ),
              _buildBulletPoint(
                ctx,
                'Eco-friendly, reusable, or zero-waste lifestyle products.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it, thanks!'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Color(0xFF059669),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestSuggestion({
    bool autoApply = false,
    bool openFormAfter = false,
  }) async {
    if (_isGeneratingSuggestion || _isPublishing) return;
    final hasItemContext =
        _photos.isNotEmpty ||
        [
          _titleController.text,
          _descriptionController.text,
          _category,
          _condition,
        ].any((value) => value?.trim().isNotEmpty ?? false);
    if (!hasItemContext) {
      _showPhotoMessage(
        'Add a title, description, category, or condition before asking for help.',
      );
      return;
    }

    final authProvider = widget.authToken == null
        ? context.read<AuthProvider?>()
        : null;
    final authToken = widget.authToken ?? authProvider?.jwtToken;
    if (authToken == null || authToken.trim().isEmpty) {
      _showPhotoMessage('Please sign in to use AI suggestions.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final requestedDraft = (
      _titleController.text,
      _descriptionController.text,
      _priceController.text,
      _category,
      _condition,
      _location?.label,
      jsonEncode(_currentAttributes()),
    );

    String? photoBase64;
    String? photoMimeType;
    if (_photos.isNotEmpty) {
      try {
        photoBase64 = base64Encode(_photos.first.bytes);
        photoMimeType = _photoContentType(_photos.first.file);
      } catch (_) {}
    }

    setState(() => _isGeneratingSuggestion = true);
    try {
      final suggestion = await _suggestionService.suggest(
        authToken: authToken,
        input: ListingSuggestionInput(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          condition: _condition,
          location: _location?.label,
          imageBase64: photoBase64,
          imageMimeType: photoMimeType,
          attributes: _currentAttributes(),
        ),
      );
      if (!mounted) return;
      setState(() => _isGeneratingSuggestion = false);
      if (authProvider != null && authProvider.jwtToken != authToken) {
        return;
      }
      final currentDraft = (
        _titleController.text,
        _descriptionController.text,
        _priceController.text,
        _category,
        _condition,
        _location?.label,
        jsonEncode(_currentAttributes()),
      );
      if (currentDraft != requestedDraft) {
        _showPhotoMessage(
          'Your listing changed while AI was working. Ask again to use the latest details.',
        );
        return;
      }
      if (autoApply) {
        setState(() {
          _applySuggestion(suggestion);
          if (openFormAfter) _flowStarted = true;
        });
        _showPhotoMessage(
          'AI draft ready. Review the detected category and details before publishing.',
        );
      } else {
        final shouldApply = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (context) => _ListingSuggestionSheet(suggestion: suggestion),
        );
        if (shouldApply == true && mounted) {
          setState(() => _applySuggestion(suggestion));
        }
      }
    } on ListingSuggestionAuthenticationException catch (error) {
      if (!mounted) return;
      if (authProvider == null || authProvider.jwtToken != authToken) return;
      await authProvider.clearSession();
      if (mounted) _showPhotoMessage(error.message);
    } on ListingSuggestionException catch (error) {
      _showPhotoMessage(error.message);
    } catch (_) {
      _showPhotoMessage(
        'AI suggestions could not be generated. Please try again.',
      );
    } finally {
      if (mounted && _isGeneratingSuggestion) {
        setState(() => _isGeneratingSuggestion = false);
      }
    }
  }

  Future<void> _postItem() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isPublishing || !_validateForm(requirePhoto: true)) {
      return;
    }

    final authToken =
        widget.authToken ?? context.read<AuthProvider?>()?.jwtToken;
    if (authToken == null || authToken.trim().isEmpty) {
      _showPhotoMessage('Please sign in before publishing an item.');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      await _publishService.publish(
        authToken: authToken,
        draft: ListingDraft(
          title: _titleController.text,
          priceNzd: _priceController.text,
          locationLabel: _location!.label,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          category: _category!,
          condition: _condition!,
          description: _descriptionController.text,
          isSustainable: _isSustainable,
          attributes: _currentAttributes(),
          photos: [
            for (var index = 0; index < _photos.length; index++)
              ListingPhotoDraft(
                bytes: _photos[index].bytes,
                fileName: _photoFileName(_photos[index].file, index),
                contentType: _photoContentType(_photos[index].file),
              ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      context.read<ListingProvider?>()?.invalidateCaches();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your listing is live.')));
      widget.onPostItem?.call();
    } on ListingAuthenticationException catch (error) {
      await context.read<AuthProvider?>()?.clearSession();
      if (!mounted) {
        return;
      }
      _showPhotoMessage(error.message);
      widget.onCancel();
    } on ListingPublishException catch (error) {
      _showPhotoMessage(error.message);
    } catch (_) {
      _showPhotoMessage('Your item could not be published. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  String _photoContentType(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String _photoFileName(XFile file, int index) {
    final name = file.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final extension = switch (_photoContentType(file)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    return 'listing_photo_${index + 1}.$extension';
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
    if (price == null || price < 0) {
      return 'Enter a valid price (0 for Free)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_flowStarted) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0C1310)
            : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _PostHeader(onCancel: widget.onCancel, onPreview: null),
              const Divider(key: Key('post_header_divider'), height: 1),
              Expanded(
                child: ListView(
                  key: const Key('post_start_page'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      'How do you want to list it?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a category for a tailored form, or let AI identify the item from a photo and prepare the right form for you.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PublishStartCard(
                            key: const Key('post_start_category_button'),
                            icon: Icons.dashboard_customize_rounded,
                            accentColor: const Color(0xFF0F766E),
                            title: 'Choose a category',
                            subtitle:
                                'Pick a category and use its tailored selling form.',
                            buttonLabel: 'Choose',
                            onTap: _startCategoryFlow,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _PublishStartCard(
                            key: const Key('post_start_ai_button'),
                            icon: Icons.auto_awesome_rounded,
                            accentColor: const Color(0xFF7C3AED),
                            title: 'AI list it for me',
                            subtitle:
                                'Take or choose a photo. AI identifies it and prepares the right form.',
                            buttonLabel: _isGeneratingSuggestion
                                ? 'Identifying…'
                                : 'Use AI',
                            loading:
                                _isGeneratingSuggestion || _isPickingPhotos,
                            onTap: _startAiFlow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C1310)
          : const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _PostHeader(
              onCancel: _isPublishing ? null : widget.onCancel,
              onPreview: _isPublishing ? null : _showPreview,
            ),
            const Divider(key: Key('post_header_divider'), height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: const Key('post_item_form'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    _PhotosSection(
                      key: const Key('post_photos_section'),
                      photos: _photos,
                      selectedIndex: _selectedPhotoIndex,
                      isPickingPhotos: _isPickingPhotos,
                      onAddPhoto: _showPhotoSourcePicker,
                      onSelectPhoto: _selectPhoto,
                      onRemovePhoto: _removePhoto,
                      onSetCoverPhoto: _setCoverPhoto,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 1. Xianyu-style Content Card (Title + Description)
                    _XianyuCardTile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ResponsiveFieldRow(
                            label: 'Title',
                            child: TextFormField(
                              key: const Key('post_title_field'),
                              controller: _titleController,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'e.g. Solid Wood Desk',
                                hintStyle: _postPlaceholderStyle,
                              ),
                              validator: _requiredTextValidator,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ResponsiveFieldRow(
                            label: 'Description',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    TextFormField(
                                      key: const Key('post_description_field'),
                                      controller: _descriptionController,
                                      minLines: 3,
                                      maxLines: 6,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.45,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Describe your item, condition, and details...',
                                        hintStyle: _postPlaceholderStyle,
                                        alignLabelWithHint: true,
                                        contentPadding: EdgeInsets.fromLTRB(
                                          14,
                                          12,
                                          14,
                                          38,
                                        ),
                                      ),
                                      validator: _requiredTextValidator,
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Semantics(
                                        liveRegion: _isGeneratingSuggestion,
                                        child: OutlinedButton.icon(
                                          key: const Key(
                                            'post_ai_suggestion_button',
                                          ),
                                          onPressed:
                                              _isPublishing ||
                                                  _isGeneratingSuggestion
                                              ? null
                                              : _requestSuggestion,
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFFDE68A),
                                            ),
                                            backgroundColor: const Color(
                                              0xFFFFFBEB,
                                            ).withOpacity(0.95),
                                            foregroundColor: const Color(
                                              0xFFB45309,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          icon: _isGeneratingSuggestion
                                              ? const SizedBox.square(
                                                  dimension: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Color(0xFFB45309)),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.auto_awesome,
                                                  size: 14,
                                                ),
                                          label: Text(
                                            _isGeneratingSuggestion
                                                ? 'Creating suggestion…'
                                                : 'AI Help Me Write',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Your listing details and first photo are sent to our AI provider to create the draft. AI can make mistakes, so review every suggestion.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Xianyu-style Trading Details Tiles
                    _XianyuCardTile(
                      child: _ResponsiveFieldRow(
                        label: 'Category',
                        child: _MobileSelectionFormField(
                          key: const Key('post_category_field'),
                          value: _category,
                          hintText: 'Select a category',
                          sheetTitle: 'Choose category',
                          options: listingCategoryNames,
                          onChanged: (value) =>
                              setState(() => _category = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _XianyuCardTile(
                      child: _ResponsiveFieldRow(
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
                            hintStyle: _postPlaceholderStyle,
                          ),
                          validator: _priceValidator,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _XianyuCardTile(
                      child: _ResponsiveFieldRow(
                        label: 'Location',
                        child: _CurrentLocationFormField(
                          key: const Key('post_location_container'),
                          value: _location,
                          isLocating: _isLocating,
                          onLocate: _findCurrentLocation,
                          onChanged: (value) {
                            setState(() => _location = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _XianyuCardTile(
                      child: _ResponsiveFieldRow(
                        label: 'Condition',
                        child: _MobileSelectionFormField(
                          key: const Key('post_condition_field'),
                          value: _condition,
                          hintText: 'Select condition',
                          sheetTitle: 'Choose condition',
                          options: _conditions,
                          onChanged: (value) =>
                              setState(() => _condition = value),
                        ),
                      ),
                    ),
                    ..._buildCategoryAttributeFields(context),
                    const SizedBox(height: AppSpacing.sm),
                    _XianyuCardTile(
                      child: Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile.adaptive(
                          key: const Key('post_sustainable_switch'),
                          contentPadding: EdgeInsets.zero,
                          value: _isSustainable,
                          onChanged: _isPublishing
                              ? null
                              : (value) =>
                                    setState(() => _isSustainable = value),
                          activeColor: Theme.of(context).colorScheme.primary,
                          secondary: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs + 2),
                            decoration: BoxDecoration(
                              color: _isSustainable
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                            ),
                            child: Icon(
                              _isSustainable ? Icons.eco : Icons.eco_outlined,
                              color: _isSustainable
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                          title: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Sustainable Item ',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: InkWell(
                                    key: const Key(
                                      'post_sustainable_help_button',
                                    ),
                                    onTap: _showSustainableInfoDialog,
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.help_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          subtitle: Text(
                            'Mark this item as eco-friendly, circular, or pre-loved',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 3. Xianyu-style Publish Button
                    FilledButton(
                      key: const Key('post_submit_button'),
                      onPressed: _isPublishing || _isGeneratingSuggestion
                          ? null
                          : _postItem,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(
                          0xFF059669,
                        ).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isPublishing
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Post item',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingSuggestionSheet extends StatelessWidget {
  const _ListingSuggestionSheet({required this.suggestion});

  final ListingSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('post_ai_suggestion_sheet'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review AI suggestion',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing changes until you apply this draft. Your location is never generated or replaced.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SuggestionValue(label: 'Title', value: suggestion.title),
            _SuggestionValue(label: 'Category', value: suggestion.category),
            _SuggestionValue(label: 'Condition', value: suggestion.condition),
            _SuggestionValue(
              label: 'Suggested price',
              value: '\$${suggestion.priceNzd} NZD',
            ),
            _SuggestionValue(
              label: 'Description',
              value: suggestion.description,
            ),
            if (suggestion.attributes.isNotEmpty) ...[
              Text(
                suggestion.category == 'Cars & Vehicles'
                    ? 'Detected vehicle details'
                    : 'Detected category details',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final field
                  in listingCategoryDefinition(
                        suggestion.category,
                      )?.attributes ??
                      const <ListingAttributeField>[])
                if (suggestion.attributes[field.key]?.trim().isNotEmpty == true)
                  _SuggestionValue(
                    label: field.label,
                    value: suggestion.attributes[field.key]!,
                  ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('post_ai_cancel_button'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep mine'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('post_ai_apply_button'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Apply draft'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionValue extends StatelessWidget {
  const _SuggestionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _PublishStartCard extends StatelessWidget {
  const _PublishStartCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(
        accentColor.withValues(alpha: 0.045),
        colors.surface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: loading ? null : () => onTap(),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: accentColor.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: loading ? null : () => onTap(),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, size: 18),
                  label: Text(
                    buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.onCancel, required this.onPreview});

  final VoidCallback? onCancel;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final useAccessibleLayout = MediaQuery.textScalerOf(context).scale(14) > 18;
    final title = Semantics(
      header: true,
      child: Text(
        'List an Item',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );

    return Padding(
      key: const Key('post_header'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: useAccessibleLayout
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                title,
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('post_cancel_button'),
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('post_preview_button'),
                          onPressed: onPreview,
                          child: const Text('Preview'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('post_cancel_button'),
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  Expanded(child: title),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('post_preview_button'),
                        onPressed: onPreview,
                        child: const Text('Preview'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PhotosSection extends StatefulWidget {
  final List<_SelectedPhoto> photos;
  final int selectedIndex;
  final bool isPickingPhotos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onSelectPhoto;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onSetCoverPhoto;

  const _PhotosSection({
    super.key,
    required this.photos,
    required this.selectedIndex,
    required this.isPickingPhotos,
    required this.onAddPhoto,
    required this.onSelectPhoto,
    required this.onRemovePhoto,
    required this.onSetCoverPhoto,
  });

  @override
  State<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<_PhotosSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.photos.isNotEmpty
          ? widget.selectedIndex.clamp(0, widget.photos.length - 1)
          : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _PhotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photos.isNotEmpty) {
      final safeIndex = widget.selectedIndex.clamp(0, widget.photos.length - 1);
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? -1) != safeIndex) {
        _pageController.animateToPage(
          safeIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useAccessibleHeight = MediaQuery.textScalerOf(context).scale(14) > 18;
    final colors = Theme.of(context).colorScheme;
    final hasPhotos = widget.photos.isNotEmpty;
    final activeIndex = hasPhotos
        ? widget.selectedIndex.clamp(0, widget.photos.length - 1)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.photos.isEmpty
                    ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
                    : colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${widget.photos.length}/10',
                key: const Key('post_photo_count'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: widget.photos.isEmpty
                      ? colors.onSurfaceVariant
                      : colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 1. If NO photos: show the large, welcoming upload box
        if (!hasPhotos)
          Semantics(
            button: true,
            label: 'Add photos. 0 of 10 selected.',
            child: CustomPaint(
              painter: _DashedRoundedBorderPainter(colors.secondary),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('post_add_photos_button'),
                  onTap: !widget.isPickingPhotos ? widget.onAddPhoto : null,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: SizedBox(
                    width: double.infinity,
                    height: useAccessibleHeight ? 240 : 152,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isPickingPhotos)
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
                              color: colors.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              size: 24,
                              color: colors.primary,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.isPickingPhotos
                              ? 'Adding photos…'
                              : 'Add photos',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.primary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'First photo will be the cover · Up to 10 photos',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else ...[
          // 2. If HAS photos: Large Hero Preview (Xianyu-style)
          Container(
            key: const Key('post_hero_image_card'),
            width: double.infinity,
            height: useAccessibleHeight ? 270 : 230,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.photos.length,
                    onPageChanged: widget.onSelectPhoto,
                    itemBuilder: (context, index) {
                      return Image.memory(
                        widget.photos[index].bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        semanticLabel:
                            'Photo ${index + 1} of ${widget.photos.length}: ${widget.photos[index].file.name}',
                      );
                    },
                  ),

                  // Top & bottom subtle gradient overlays for contrast
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left: Cover Badge OR "Set as cover" action button
                  Positioned(
                    top: 10,
                    left: 10,
                    child: activeIndex == 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.95,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Cover',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('post_photo_set_cover_button'),
                              onTap: () => widget.onSetCoverPhoto(activeIndex),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.crop_original_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Set as cover',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Top-Right: Delete button for active photo
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: Tooltip(
                        message: 'Remove photo',
                        child: InkWell(
                          key: Key('post_photo_delete_$activeIndex'),
                          onTap: () => widget.onRemovePhoto(activeIndex),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Right: Index counter pill
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${activeIndex + 1}/${widget.photos.length}',
                        key: const Key('post_hero_photo_index'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Previous / Next chevron hints
                  if (widget.photos.length > 1) ...[
                    if (activeIndex > 0)
                      Positioned(
                        left: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('post_hero_prev_photo'),
                              onTap: () =>
                                  widget.onSelectPhoto(activeIndex - 1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (activeIndex < widget.photos.length - 1)
                      Positioned(
                        right: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('post_hero_next_photo'),
                              onTap: () =>
                                  widget.onSelectPhoto(activeIndex + 1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. Below: Thumbnails Strip (Tap to select, delete via 'x' button)
          SizedBox(
            height: 66,
            child: ListView.separated(
              key: const Key('post_photo_slots'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: widget.photos.length < 10
                  ? widget.photos.length + 1
                  : widget.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                // If it's the "+ Add" button at the end
                if (index == widget.photos.length) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('post_add_photos_button'),
                      onTap: widget.isPickingPhotos ? null : widget.onAddPhoto,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: CustomPaint(
                        painter: _DashedRoundedBorderPainter(colors.secondary),
                        child: SizedBox.square(
                          dimension: 58,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final isSelected = index == activeIndex;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Semantics(
                      button: true,
                      label: isSelected
                          ? 'Photo ${index + 1}, currently viewing.'
                          : 'Photo ${index + 1}. Tap to view.',
                      child: InkWell(
                        key: Key('post_photo_slot_$index'),
                        onTap: () => widget.onSelectPhoto(index),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : colors.outlineVariant.withValues(
                                      alpha: 0.7,
                                    ),
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.brandPrimary.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.small - 1,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  widget.photos[index].bytes,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  semanticLabel:
                                      'Photo ${index + 1}: ${widget.photos[index].file.name}',
                                ),
                                if (index == 0)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 1,
                                      ),
                                      color: AppColors.brandPrimary.withValues(
                                        alpha: 0.92,
                                      ),
                                      child: const Text(
                                        'Cover',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Circular '✕' delete button on thumbnail corner
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Material(
                        color: Colors.transparent,
                        child: Tooltip(
                          message: 'Remove photo ${index + 1}',
                          child: InkWell(
                            key: Key('post_photo_thumb_delete_$index'),
                            onTap: () => widget.onRemovePhoto(index),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.close,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'First photo is the cover · Tap thumbnail to switch preview · Can set as cover',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 10.5,
            ),
          ),
        ],
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

class _XianyuCardTile extends StatelessWidget {
  final Widget child;

  const _XianyuCardTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1.5),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: child,
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
              width: 82,
              height: 48,
              child: Align(alignment: Alignment.centerLeft, child: labelWidget),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _CurrentLocationFormField extends StatefulWidget {
  const _CurrentLocationFormField({
    super.key,
    required this.value,
    required this.isLocating,
    required this.onLocate,
    required this.onChanged,
  });

  final ListingLocation? value;
  final bool isLocating;
  final Future<ListingLocation?> Function() onLocate;
  final ValueChanged<ListingLocation> onChanged;

  @override
  State<_CurrentLocationFormField> createState() =>
      _CurrentLocationFormFieldState();
}

class _CurrentLocationFormFieldState extends State<_CurrentLocationFormField> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value?.label ?? '');
  }

  @override
  void didUpdateWidget(covariant _CurrentLocationFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value?.label != null &&
        widget.value!.label != _textController.text) {
      _textController.text = widget.value!.label;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<String?> _requestManualLocation(BuildContext context) async {
    String location = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter location',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Enter a suburb or city. Do not include a street address.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                          'Auckland Central',
                          'Newmarket',
                          'Ponsonby',
                          'Takapuna',
                          'Mount Eden',
                          'Wellington Central',
                          'Christchurch Central',
                          'Hamilton',
                        ].map((area) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(sheetContext).pop(area),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                area,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('post_manual_location_input'),
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Suburb or city',
                      hintText: 'e.g. Auckland Central',
                      hintStyle: _postPlaceholderStyle,
                    ),
                    onChanged: (value) {
                      setSheetState(() => location = value.trim());
                    },
                    onSubmitted: (value) {
                      final trimmedValue = value.trim();
                      if (trimmedValue.isNotEmpty) {
                        Navigator.of(sheetContext).pop(trimmedValue);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const Key('post_manual_location_save'),
                    onPressed: location.isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(location),
                    child: const Text('Use this location'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<ListingLocation>(
      initialValue: widget.value,
      validator: (value) =>
          (widget.value == null && _textController.text.trim().isEmpty)
          ? 'Required'
          : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.value?.label ?? ''),
              optionsBuilder: (TextEditingValue textVal) {
                if (textVal.text.trim().isEmpty) {
                  return const Iterable<String>.empty();
                }
                return CampusLocations.search(textVal.text);
              },
              onSelected: (String selection) {
                _textController.text = selection;
                final loc = ListingLocation(label: selection);
                field.didChange(loc);
                widget.onChanged(loc);
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    if (_textController.text.isNotEmpty &&
                        textEditingController.text.isEmpty) {
                      textEditingController.text = _textController.text;
                    }
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Campus, suburb or city',
                        hintStyle: _postPlaceholderStyle,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        errorText: field.errorText,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 88,
                          minHeight: 48,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('post_location_field'),
                              tooltip: 'Use my location',
                              onPressed: widget.isLocating
                                  ? null
                                  : () async {
                                      final location = await widget.onLocate();
                                      if (location == null ||
                                          !context.mounted) {
                                        return;
                                      }
                                      textEditingController.text =
                                          location.label;
                                      _textController.text = location.label;
                                      field.didChange(location);
                                      widget.onChanged(location);
                                    },
                              icon: widget.isLocating
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location_rounded,
                                      size: 19,
                                    ),
                            ),
                            IconButton(
                              key: const Key('post_manual_location_button'),
                              tooltip: 'Popular areas',
                              onPressed: () async {
                                final label = await _requestManualLocation(
                                  context,
                                );
                                if (label == null || !context.mounted) return;
                                textEditingController.text = label;
                                _textController.text = label;
                                final location = ListingLocation(label: label);
                                field.didChange(location);
                                widget.onChanged(location);
                              },
                              icon: const Icon(
                                Icons.expand_more_rounded,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (val) {
                        final trimmed = val.trim();
                        _textController.text = trimmed;
                        if (trimmed.isNotEmpty) {
                          final loc = ListingLocation(label: trimmed);
                          field.didChange(loc);
                          widget.onChanged(loc);
                        }
                      },
                    );
                  },
            ),
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
  final bool required;

  const _MobileSelectionFormField({
    super.key,
    required this.value,
    required this.hintText,
    required this.sheetTitle,
    required this.options,
    required this.onChanged,
    this.required = true,
  });

  Future<String?> _showOptions(BuildContext context, String? selectedValue) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      key: ValueKey(value),
      initialValue: value,
      validator: (value) => required && value == null ? 'Required' : null,
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
                hintStyle: _postPlaceholderStyle,
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
    final colors = Theme.of(context).colorScheme;
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
                                ? colors.primaryContainer
                                : colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? colors.primary
                                    : colors.outline,
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
                                      if (_getOptionIcon(option) != null) ...[
                                        Icon(
                                          _getOptionIcon(option),
                                          size: 18,
                                          color: isSelected
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(
                                          width: AppSpacing.xs + 2,
                                        ),
                                      ],
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: colors.primary,
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
  const _DashedRoundedBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

IconData? _getOptionIcon(String option) {
  final lower = option.toLowerCase();
  if (lower.contains('furniture')) return Icons.chair_outlined;
  if (lower.contains('electronic')) return Icons.devices_outlined;
  if (lower.contains('book')) return Icons.menu_book_outlined;
  if (lower.contains('home')) return Icons.home_outlined;
  if (lower.contains('sport')) return Icons.sports_basketball_outlined;
  if (lower.contains('kid') || lower.contains('toy')) {
    return Icons.child_care_outlined;
  }
  if (lower.contains('cloth') || lower.contains('fashion')) {
    return Icons.checkroom_outlined;
  }
  if (lower.contains('car') || lower.contains('vehicle')) {
    return Icons.directions_car_outlined;
  }
  if (lower.contains('other')) return Icons.category_outlined;
  if (lower == 'new') return Icons.verified_outlined;
  if (lower.contains('like new')) return Icons.thumb_up_outlined;
  if (lower.contains('good')) return Icons.sentiment_satisfied_outlined;
  if (lower.contains('fair')) return Icons.handshake_outlined;
  return null;
}
