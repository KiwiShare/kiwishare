import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/post/post_item_screen.dart';

void main() {
  Widget buildTestApp({
    required VoidCallback onCancel,
    TextScaler textScaler = TextScaler.noScaling,
    ListingImagePicker? imagePicker,
  }) {
    return MaterialApp(
      theme: buildKiwiShareTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: PostItemScreen(
          onCancel: onCancel,
          imagePicker: imagePicker ?? FakeListingImagePicker(),
        ),
      ),
    );
  }

  testWidgets('renders the Figma listing form and photo slots', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(onCancel: () {}));

    expect(find.text('Post an item'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);
    expect(find.byKey(const Key('post_title_field')), findsOneWidget);
    expect(find.byKey(const Key('post_category_field')), findsOneWidget);
    expect(find.byKey(const Key('post_price_field')), findsOneWidget);
    expect(find.byKey(const Key('post_location_field')), findsOneWidget);
    expect(find.byKey(const Key('post_condition_field')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('post_submit_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('post_description_field')), findsOneWidget);
    expect(find.byKey(const Key('post_submit_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo area opens gallery and shows the selected image', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final imagePicker = FakeListingImagePicker(
      galleryPhotos: [testPhoto('desk.png')],
    );
    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, imagePicker: imagePicker),
    );

    await tester.tap(find.byKey(const Key('post_add_photos_button')));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    await tester.tap(find.byKey(const Key('post_choose_gallery_option')));
    await tester.pumpAndSettle();

    expect(find.text('1/10'), findsOneWidget);
    expect(imagePicker.lastGalleryLimit, 10);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byKey(const Key('post_photo_slot_0')));
    await tester.pump();
    expect(find.text('0/10'), findsOneWidget);
  });

  testWidgets('restores a photo returned by Android lost-data recovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final imagePicker = FakeListingImagePicker(
      lostPhotos: [testPhoto('restored.png')],
    );
    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, imagePicker: imagePicker),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/10'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('uses a compact mobile sheet for listing selections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(onCancel: () {}));

    await tester.tap(find.byKey(const Key('post_category_field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_selection_sheet')), findsOneWidget);
    expect(find.text('Choose category'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.tap(
      find.byKey(const Key('post_selection_option_Electronics')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post_selection_sheet')), findsNothing);
    expect(find.text('Electronics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks labels above fields on narrow mobile screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(onCancel: () {}));

    final titleLabel = tester.getRect(find.text('Title'));
    final titleField = tester.getRect(
      find.byKey(const Key('post_title_field')),
    );

    expect(titleField.left, closeTo(titleLabel.left, 1));
    expect(titleField.top, greaterThan(titleLabel.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel action is wired and empty submission is validated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cancelled = false;
    await tester.pumpWidget(buildTestApp(onCancel: () => cancelled = true));

    await tester.tap(find.byKey(const Key('post_cancel_button')));
    expect(cancelled, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('post_submit_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(find.text('Add at least one photo to continue.'), findsOneWidget);
  });

  testWidgets('supports 200 percent text scaling without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, textScaler: const TextScaler.linear(2)),
    );
    await tester.pump();

    expect(find.text('Post an item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeListingImagePicker implements ListingImagePicker {
  final List<XFile> galleryPhotos;
  final List<XFile> lostPhotos;
  final XFile? cameraPhoto;
  int? lastGalleryLimit;

  FakeListingImagePicker({
    this.galleryPhotos = const [],
    this.lostPhotos = const [],
    this.cameraPhoto,
  });

  @override
  Future<List<XFile>> chooseFromGallery({required int limit}) async {
    lastGalleryLimit = limit;
    return galleryPhotos;
  }

  @override
  Future<List<XFile>> recoverLostPhotos() async => lostPhotos;

  @override
  Future<XFile?> takePhoto() async => cameraPhoto;
}

XFile testPhoto(String name) {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return XFile.fromData(bytes, name: name, mimeType: 'image/png');
}
