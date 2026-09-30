import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/services/r2_upload_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/shared/widgets/edit_item_sheet.dart';

void main() {
  testWidgets('edit listing uses a full page with real photo controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final picker = _FakeEditImagePicker(
      gallery: [_testPhoto('replacement.png')],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        home: EditItemSheet(
          item: _vehicle,
          imagePicker: picker,
          photoUploader: _FakePhotoUploader(),
        ),
      ),
    );

    expect(find.byKey(const Key('edit_item_page')), findsOneWidget);
    expect(find.text('Edit listing'), findsOneWidget);
    expect(find.text('Photo Image URL'), findsNothing);
    expect(find.byKey(const Key('edit_take_photo_button')), findsOneWidget);
    expect(find.byKey(const Key('edit_choose_photo_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_choose_photo_button')));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(find.byKey(const Key('edit_photo_thumbnail_0')), findsOneWidget);
    expect(find.text('Cover photo'), findsOneWidget);
    expect(find.byKey(const Key('edit_replace_photo_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_replace_photo_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_photo_camera_option')));
    await tester.pumpAndSettle();
    expect(picker.cameraCalls, 1);
    expect(find.byKey(const Key('edit_photo_thumbnail_0')), findsOneWidget);
  });

  testWidgets('edit listing exposes category-specific optional date fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        home: EditItemSheet(
          item: _vehicle.copyWith(
            imageUrl: 'https://assets.kiwishare.online/vehicle.jpg',
            images: const ['https://assets.kiwishare.online/vehicle.jpg'],
          ),
          imagePicker: _FakeEditImagePicker(),
          photoUploader: _FakePhotoUploader(),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit_attribute_year')),
      300,
      scrollable: scrollable,
    );
    expect(find.byKey(const Key('edit_attribute_year')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('edit_attribute_wofExpiry')),
      300,
      scrollable: scrollable,
    );
    expect(find.byKey(const Key('edit_attribute_wofExpiry')), findsOneWidget);

    final wofEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('edit_attribute_wofExpiry')),
        matching: find.byType(EditableText),
      ),
    );
    expect(wofEditable.readOnly, isTrue);

    await tester.ensureVisible(
      find.byKey(const Key('edit_attribute_wofExpiry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_attribute_wofExpiry')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}

const _vehicle = ItemModel(
  id: 'vehicle-1',
  title: '2018 Toyota Corolla',
  priceNzd: '16500',
  location: 'Newmarket, Auckland',
  imageUrl: '',
  isSustainable: false,
  category: 'Cars & Vehicles',
  status: ItemStatus.active,
  description: 'Well maintained hatchback.',
  condition: 'good',
  ownerId: 'seller-1',
  attributes: {
    'make': 'Toyota',
    'model': 'Corolla',
    'year': '2018',
    'mileageKm': '85000',
    'fuelType': 'Hybrid',
    'transmission': 'Automatic',
    'bodyType': 'Hatchback',
    'wofExpiry': '2027-06-30',
  },
);

class _FakeEditImagePicker implements ListingImagePicker {
  _FakeEditImagePicker({this.gallery = const []});

  final List<XFile> gallery;
  int galleryCalls = 0;
  int cameraCalls = 0;

  @override
  Future<XFile?> takePhoto() async {
    cameraCalls += 1;
    return _testPhoto('camera.png');
  }

  @override
  Future<List<XFile>> chooseFromGallery({required int limit}) async {
    galleryCalls += 1;
    return gallery.take(limit).toList(growable: false);
  }

  @override
  Future<List<XFile>> recoverLostPhotos() async => const [];
}

class _FakePhotoUploader implements ListingPhotoUploader {
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    required String authToken,
  }) async {
    return 'https://assets.kiwishare.online/$fileName';
  }
}

XFile _testPhoto(String name) {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return XFile.fromData(bytes, name: name, mimeType: 'image/png');
}
