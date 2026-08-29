import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/config/api_config.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/views/messages/chat_conversation_screen.dart';

import '../../support/fake_chat_photo_uploader.dart';
import '../../support/fake_chat_repository.dart';

Widget _buildSubject({
  required FakeChatRepository repository,
  ChatConversationModel? conversation,
  String? authToken = 'valid-token',
  TextScaler textScaler = TextScaler.noScaling,
  ChatPhotoUploader? photoUploader,
  ListingImagePicker? imagePicker,
}) {
  final value = conversation ?? testConversation();
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF064B3A)),
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: ChatConversationScreen(
        conversation: value,
        chatProvider: ChatProvider(
          repository: repository,
          photoUploader: photoUploader,
        ),
        authToken: authToken,
        imagePicker: imagePicker,
      ),
    ),
  );
}

void main() {
  testWidgets('loads private history and marks incoming messages read', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Is the chair available?', isMine: false),
          testMessage(id: '2', text: 'Yes, it is.', isMine: true),
        ],
      },
    );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 1);
    expect(repository.markReadCalls, 1);
    expect(
      find.byKey(const Key('conversation_participant_name')),
      findsOneWidget,
    );
    expect(find.text('Sophie M.'), findsOneWidget);
    expect(find.text('Ergonomic Office Chair'), findsOneWidget);
    expect(find.byKey(const Key('chat_message_1')), findsOneWidget);
    expect(find.byKey(const Key('chat_message_2')), findsOneWidget);
  });

  testWidgets(
    'appends to fixed-length history and clears the composer after API success',
    (tester) async {
      final repository = FakeChatRepository();
      await tester.pumpWidget(_buildSubject(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat_message_input')),
        '  Can I collect this tomorrow?  ',
      );
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      expect(repository.sendCalls, 1);
      expect(repository.sentTexts, ['Can I collect this tomorrow?']);
      expect(find.text('Can I collect this tomorrow?'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(input.controller?.text, isEmpty);
    },
  );

  testWidgets('chooses, uploads, sends, and renders a gallery photo', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatPhotoUploader();
    final picker = _FakeChatImagePicker();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        photoUploader: uploader,
        imagePicker: picker,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_add_photo_button')));
    await tester.pumpAndSettle();
    expect(find.text('Send a photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_choose_photo_option')));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(uploader.uploadedFileName, endsWith('.png'));
    expect(uploader.uploadedContentType, 'image/png');
    expect(repository.sentImageUrls, [uploader.url]);
    expect(find.byKey(const Key('chat_message_image_sent-1')), findsOneWidget);
  });

  testWidgets('recovers and sends a photo after Android recreates the screen', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatPhotoUploader();
    final picker = _FakeChatImagePicker(
      lostPhotos: [
        XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'recovered.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        photoUploader: uploader,
        imagePicker: picker,
      ),
    );
    await tester.pumpAndSettle();

    expect(picker.recoveryCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(uploader.uploadedFileName, endsWith('.jpg'));
    expect(uploader.uploadedBytes, Uint8List.fromList([4, 5, 6]));
    expect(repository.sentImageUrls, [uploader.url]);
  });

  testWidgets('resolves relative image proxy URLs against the API origin', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '7',
            type: 'image',
            text: '',
            imageUrl: '/api/images/test/pr-97/chat/photo.jpg',
            isMine: false,
          ),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('chat_message_image_7')),
    );
    expect(
      (image.image as NetworkImage).url,
      '${ApiConfig.baseUrl}/api/images/test/pr-97/chat/photo.jpg',
    );
  });

  testWidgets('preserves the draft and explains a recoverable send failure', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..sendError = const ChatRepositoryException(
        'Message service unavailable. Please try again.',
      );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'Please keep this draft',
    );
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation_inline_error')), findsOneWidget);
    expect(
      find.text('Message service unavailable. Please try again.'),
      findsOneWidget,
    );
    final input = tester.widget<TextField>(
      find.byKey(const Key('chat_message_input')),
    );
    expect(input.controller?.text, 'Please keep this draft');
  });

  testWidgets('shows signed-out and empty conversation states', (tester) async {
    final signedOutRepository = FakeChatRepository();
    await tester.pumpWidget(
      _buildSubject(repository: signedOutRepository, authToken: null),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('conversation_signed_out_state')),
      findsOneWidget,
    );
    expect(signedOutRepository.messageFetches, 0);

    await tester.pumpWidget(_buildSubject(repository: FakeChatRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
  });

  testWidgets('disables sending when a conversation is closed', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        conversation: testConversation(status: 'closed'),
      ),
    );
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('chat_message_input')),
    );
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat_send_button')),
    );
    expect(input.enabled, isFalse);
    expect(sendButton.onPressed, isNull);
    expect(find.text('Conversation closed'), findsOneWidget);
  });

  testWidgets('remains readable at 200 percent text scaling', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(
          messages: {
            'conversation-1': [
              testMessage(
                id: '1',
                text: 'This message remains readable when text is enlarged.',
                isMine: false,
              ),
            ],
          },
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('conversation_message_list')), findsOneWidget);
  });
}

class _FakeChatImagePicker implements ListingImagePicker {
  _FakeChatImagePicker({this.lostPhotos = const []});

  final List<XFile> lostPhotos;
  int galleryCalls = 0;
  int recoveryCalls = 0;

  @override
  Future<List<XFile>> chooseFromGallery({required int limit}) async {
    galleryCalls += 1;
    return [
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'chair.png',
        mimeType: 'image/png',
      ),
    ];
  }

  @override
  Future<List<XFile>> recoverLostPhotos() async {
    recoveryCalls += 1;
    return lostPhotos;
  }

  @override
  Future<XFile?> takePhoto() async => null;
}
