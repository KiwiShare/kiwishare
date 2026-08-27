import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/listing_provider.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/services/listing_location_service.dart';
import 'package:kiwishare/services/listing_publish_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/post/post_item_screen.dart';
import 'package:provider/provider.dart';

void main() {
  test('coordinate fallback only exposes an approximate area', () {
    expect(
      approximateListingLocationLabel(-36.8485, 174.7633),
      'Approx. -36.85, 174.76',
    );
  });

  Widget buildTestApp({
    required VoidCallback onCancel,
    TextScaler textScaler = TextScaler.noScaling,
    ListingImagePicker? imagePicker,
    ListingLocationService? locationService,
    ListingPublishService? publishService,
    String? authToken,
    VoidCallback? onPostItem,
    ThemeMode themeMode = ThemeMode.light,
    EdgeInsets safeAreaPadding = EdgeInsets.zero,
    AuthProvider? authProvider,
    ListingProvider? listingProvider,
  }) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandSecondary,
      brightness: Brightness.dark,
    );
    final app = MaterialApp(
      themeMode: themeMode,
      theme: buildKiwiShareTheme(),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
      ),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: textScaler,
          padding: safeAreaPadding,
          viewPadding: safeAreaPadding,
        ),
        child: PostItemScreen(
          onCancel: onCancel,
          imagePicker: imagePicker ?? FakeListingImagePicker(),
          locationService:
              locationService ?? FakeListingLocationService.success(),
          publishService: publishService,
          authToken: authToken,
          onPostItem: onPostItem,
        ),
      ),
    );
    Widget result = app;
    if (listingProvider != null) {
      result = ChangeNotifierProvider<ListingProvider>.value(
        value: listingProvider,
        child: result,
      );
    }
    if (authProvider != null) {
      result = ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: result,
      );
    }
    return result;
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

  testWidgets('keeps Photos content below the iOS safe-area header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestApp(
        onCancel: () {},
        safeAreaPadding: const EdgeInsets.only(top: 59, bottom: 34),
      ),
    );

    final headerRect = tester.getRect(find.byKey(const Key('post_header')));
    final dividerRect = tester.getRect(
      find.byKey(const Key('post_header_divider')),
    );
    final photosRect = tester.getRect(
      find.byKey(const Key('post_photos_section')),
    );

    expect(headerRect.top, greaterThanOrEqualTo(59));
    expect(photosRect.top, greaterThan(dividerRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses readable adaptive colours in iOS dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, themeMode: ThemeMode.dark),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final photosText = tester.widget<Text>(find.text('Photos'));
    final background = scaffold.backgroundColor!;
    final foreground = photosText.style!.color!;

    expect(background.computeLuminance(), lessThan(0.2));
    expect(foreground.computeLuminance(), greaterThan(0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detects the current area instead of using a hardcoded location',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final locationService = FakeListingLocationService.success(
        label: 'Auckland Central, Auckland',
      );
      await tester.pumpWidget(
        buildTestApp(onCancel: () {}, locationService: locationService),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('post_location_field')),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byKey(const Key('post_location_field')));
      await tester.pumpAndSettle();

      expect(locationService.locationRequests, 1);
      expect(find.text('Auckland Central, Auckland'), findsOneWidget);
      expect(find.text('Auckland CBD'), findsNothing);
    },
  );

  testWidgets('explains how to recover when location permission is blocked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locationService = FakeListingLocationService.failure(
      ListingLocationErrorCode.permissionDeniedForever,
    );
    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, locationService: locationService),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('post_location_field')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('post_location_field')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Location permission is blocked. Enable it in Settings and try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Settings'));
    expect(locationService.appSettingsRequests, 1);
  });

  testWidgets('manual suburb entry works when GPS permission is denied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locationService = FakeListingLocationService.failure(
      ListingLocationErrorCode.permissionDenied,
    );
    await tester.pumpWidget(
      buildTestApp(onCancel: () {}, locationService: locationService),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('post_location_field')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('post_location_field')));
    await tester.pumpAndSettle();
    expect(locationService.locationRequests, 1);

    await tester.tap(find.byKey(const Key('post_manual_location_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('post_manual_location_input')),
      '  Mount Eden  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('post_manual_location_save')));
    await tester.pumpAndSettle();

    expect(find.text('Mount Eden'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('post_submit_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('post_location_field')),
        matching: find.text('Required'),
      ),
      findsNothing,
    );
  });

  testWidgets('publishes a complete listing through the real submit boundary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final publishService = FakeListingPublishService();
    final listingProvider = TrackingListingProvider();
    var completed = false;
    await tester.pumpWidget(
      buildTestApp(
        onCancel: () {},
        onPostItem: () => completed = true,
        authToken: 'valid-token',
        publishService: publishService,
        listingProvider: listingProvider,
        imagePicker: FakeListingImagePicker(
          galleryPhotos: [testPhoto('desk.png')],
        ),
      ),
    );

    await completeValidListing(tester);
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(find.text('Your listing is live.'), findsOneWidget);
    expect(publishService.authToken, 'valid-token');
    expect(publishService.draft?.title, 'Solid wood desk');
    expect(publishService.draft?.category, 'Furniture');
    expect(publishService.draft?.condition, 'Good');
    expect(publishService.draft?.photos.single.fileName, 'listing_photo_1.png');
    expect(publishService.draft?.latitude, -36.8485);
    expect(publishService.draft?.longitude, 174.7633);
    expect(listingProvider.cachesInvalidated, isTrue);
  });

  testWidgets('keeps the form open and explains a publish failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final publishService = FakeListingPublishService(
      failure: const ListingPublishException('Upload service unavailable.'),
    );
    var completed = false;
    await tester.pumpWidget(
      buildTestApp(
        onCancel: () {},
        onPostItem: () => completed = true,
        authToken: 'valid-token',
        publishService: publishService,
        imagePicker: FakeListingImagePicker(
          galleryPhotos: [testPhoto('desk.png')],
        ),
      ),
    );

    await completeValidListing(tester);
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pumpAndSettle();

    expect(completed, isFalse);
    expect(find.text('Upload service unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('post_item_form')), findsOneWidget);
  });

  testWidgets(
    'retries after a transient API failure without duplicating the item',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final publishService = FailOnceListingPublishService();
      var completed = false;
      await tester.pumpWidget(
        buildTestApp(
          onCancel: () {},
          onPostItem: () => completed = true,
          authToken: 'valid-token',
          publishService: publishService,
          imagePicker: FakeListingImagePicker(
            galleryPhotos: [testPhoto('desk.png')],
          ),
        ),
      );

      await completeValidListing(tester);
      await tester.tap(find.byKey(const Key('post_submit_button')));
      await tester.pumpAndSettle();

      expect(completed, isFalse);
      expect(publishService.publishCalls, 1);
      expect(find.byKey(const Key('post_item_form')), findsOneWidget);
      expect(
        find.text('Temporary server error. Please try again.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('post_submit_button')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('post_submit_button')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(publishService.publishCalls, 2);
      expect(publishService.createdItems, 1);
    },
  );

  testWidgets('disables duplicate submissions while publishing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final publishService = PendingListingPublishService();
    var cancelled = false;
    await tester.pumpWidget(
      buildTestApp(
        onCancel: () => cancelled = true,
        authToken: 'valid-token',
        publishService: publishService,
        imagePicker: FakeListingImagePicker(
          galleryPhotos: [testPhoto('desk.png')],
        ),
      ),
    );

    await completeValidListing(tester);
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('post_submit_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(publishService.publishCalls, 1);
    final cancelButton = tester.widget<TextButton>(
      find.byKey(const Key('post_cancel_button')),
    );
    expect(cancelButton.onPressed, isNull);
    expect(cancelled, isFalse);

    publishService.complete();
    await tester.pumpAndSettle();
    expect(find.text('Post item'), findsOneWidget);
  });

  testWidgets('clears an expired session and exits the publish form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = TrackingAuthProvider();
    var cancelled = false;

    await tester.pumpWidget(
      buildTestApp(
        onCancel: () => cancelled = true,
        authProvider: authProvider,
        authToken: 'expired-token',
        publishService: FakeListingPublishService(
          failure: const ListingAuthenticationException(),
        ),
        imagePicker: FakeListingImagePicker(
          galleryPhotos: [testPhoto('desk.png')],
        ),
      ),
    );

    await completeValidListing(tester);
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(authProvider.sessionCleared, isTrue);
    expect(cancelled, isTrue);
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
  });

  testWidgets('requires a signed-in session before publishing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final publishService = FakeListingPublishService();
    await tester.pumpWidget(
      buildTestApp(
        onCancel: () {},
        publishService: publishService,
        imagePicker: FakeListingImagePicker(
          galleryPhotos: [testPhoto('desk.png')],
        ),
      ),
    );

    await completeValidListing(tester);
    await tester.tap(find.byKey(const Key('post_submit_button')));
    await tester.pump();

    expect(
      find.text('Please sign in before publishing an item.'),
      findsOneWidget,
    );
    expect(publishService.draft, isNull);
  });
}

Future<void> completeValidListing(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('post_add_photos_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('post_choose_gallery_option')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('post_title_field')),
    'Solid wood desk',
  );
  await tester.tap(find.byKey(const Key('post_category_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('post_selection_option_Furniture')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('post_price_field')), '120');

  await tester.scrollUntilVisible(
    find.byKey(const Key('post_location_field')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('post_location_field')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('post_condition_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('post_selection_option_Good')));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byKey(const Key('post_description_field')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(
    find.byKey(const Key('post_description_field')),
    'A sturdy study desk.',
  );
  await tester.scrollUntilVisible(
    find.byKey(const Key('post_submit_button')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
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

class FakeListingLocationService implements ListingLocationService {
  FakeListingLocationService.success({
    String label = 'Auckland Central, Auckland',
  }) : location = ListingLocation(
         label: label,
         latitude: -36.8485,
         longitude: 174.7633,
       ),
       errorCode = null;

  FakeListingLocationService.failure(this.errorCode) : location = null;

  final ListingLocation? location;
  final ListingLocationErrorCode? errorCode;
  int locationRequests = 0;
  int appSettingsRequests = 0;
  int locationSettingsRequests = 0;

  @override
  Future<ListingLocation> getCurrentLocation() async {
    locationRequests += 1;
    if (errorCode != null) {
      throw ListingLocationException(errorCode!);
    }
    return location!;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsRequests += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsRequests += 1;
    return true;
  }
}

class FakeListingPublishService implements ListingPublishService {
  FakeListingPublishService({this.failure});

  final ListingPublishException? failure;
  ListingDraft? draft;
  String? authToken;

  @override
  Future<ItemModel> publish({
    required ListingDraft draft,
    required String authToken,
  }) async {
    this.draft = draft;
    this.authToken = authToken;
    if (failure != null) {
      throw failure!;
    }
    return ItemModel(
      id: 'published-item',
      title: draft.title,
      priceNzd: draft.priceNzd,
      location: draft.locationLabel,
      imageUrl: 'https://assets.kiwishare.online/images/desk.png',
      isSustainable: true,
      category: draft.category,
      status: ItemStatus.active,
      description: draft.description,
      condition: draft.condition,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }
}

class PendingListingPublishService implements ListingPublishService {
  final Completer<ItemModel> _completer = Completer<ItemModel>();
  int publishCalls = 0;

  @override
  Future<ItemModel> publish({
    required ListingDraft draft,
    required String authToken,
  }) {
    publishCalls += 1;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const ItemModel(
        id: 'published-item',
        title: 'Solid wood desk',
        priceNzd: '120',
        location: 'Auckland Central, Auckland',
        imageUrl: 'https://assets.kiwishare.online/images/desk.png',
        isSustainable: true,
        category: 'Furniture',
        status: ItemStatus.active,
      ),
    );
  }
}

class FailOnceListingPublishService implements ListingPublishService {
  int publishCalls = 0;
  int createdItems = 0;

  @override
  Future<ItemModel> publish({
    required ListingDraft draft,
    required String authToken,
  }) async {
    publishCalls += 1;
    if (publishCalls == 1) {
      throw const ListingPublishException(
        'Temporary server error. Please try again.',
      );
    }
    createdItems += 1;
    return ItemModel(
      id: 'published-item',
      title: draft.title,
      priceNzd: draft.priceNzd,
      location: draft.locationLabel,
      imageUrl: 'https://assets.kiwishare.online/test/desk.png',
      isSustainable: true,
      category: draft.category,
      status: ItemStatus.active,
      description: draft.description,
      condition: draft.condition,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }
}

class TrackingListingProvider extends ListingProvider {
  TrackingListingProvider() : super(itemRepository: RestItemRepository());

  bool cachesInvalidated = false;

  @override
  void invalidateCaches() {
    cachesInvalidated = true;
    super.invalidateCaches();
  }
}

class TrackingAuthProvider extends AuthProvider {
  TrackingAuthProvider() : super(userRepository: MockUserRepository());

  bool sessionCleared = false;

  @override
  Future<void> clearSession() async {
    sessionCleared = true;
  }
}

XFile testPhoto(String name) {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return XFile.fromData(bytes, name: name, mimeType: 'image/png');
}
