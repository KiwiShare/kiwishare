import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/config/api_config.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';
import 'package:kiwishare/services/chat_voice_service.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/views/messages/chat_conversation_screen.dart';

import '../../support/fake_chat_photo_uploader.dart';
import '../../support/fake_chat_repository.dart';
import '../../support/fake_chat_voice_service.dart';

Widget _buildSubject({
  required FakeChatRepository repository,
  ChatConversationModel? conversation,
  String? authToken = 'valid-token',
  TextScaler textScaler = TextScaler.noScaling,
  ChatPhotoUploader? photoUploader,
  ListingImagePicker? imagePicker,
  ChatVoiceUploader? voiceUploader,
  ChatVoiceRecorder? voiceRecorder,
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
          voiceUploader: voiceUploader,
        ),
        authToken: authToken,
        imagePicker: imagePicker,
        voiceRecorder: voiceRecorder,
      ),
    ),
  );
}

void main() {
  testWidgets('loads private history and marks incoming messages read', (
    tester,
  ) async {
    final conversation = testConversation(unreadCount: 2);
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Is the chair available?', isMine: false),
          testMessage(id: '2', text: 'Yes, it is.', isMine: true),
        ],
      },
    );
    await tester.pumpWidget(
      _buildSubject(repository: repository, conversation: conversation),
    );
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

  testWidgets('shows Read only under the latest sent message when viewed', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '1',
            text: 'First sent',
            isMine: true,
            status: 'read',
            readAt: DateTime.utc(2026, 8, 27, 8, 31),
          ),
          testMessage(
            id: '2',
            text: 'Latest sent',
            isMine: true,
            status: 'read',
            readAt: DateTime.utc(2026, 8, 27, 8, 32),
          ),
          testMessage(id: '3', text: 'Reply', isMine: false, status: 'read'),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_read_receipt_1')), findsNothing);
    expect(find.byKey(const Key('chat_read_receipt_2')), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.bySemanticsLabel('You sent Latest sent, read'), findsOneWidget);
  });

  testWidgets('does not show a stale receipt when the latest send is unread', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Viewed', isMine: true, status: 'read'),
          testMessage(id: '2', text: 'Waiting', isMine: true),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsNothing);
  });

  testWidgets('aligns received content left and sent content right', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Hi', isMine: false),
          testMessage(id: '2', text: 'Mine', isMine: true),
        ],
      },
    );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final receivedBubble = find.byKey(const Key('chat_message_1'));
    final sentBubble = find.byKey(const Key('chat_message_2'));
    expect(
      tester.getTopLeft(receivedBubble).dx,
      lessThan(tester.getTopLeft(sentBubble).dx),
    );

    final receivedLabels = find.descendant(
      of: receivedBubble,
      matching: find.byType(Text),
    );
    expect(receivedLabels, findsNWidgets(2));
    expect(
      tester.getTopLeft(receivedLabels.at(0)).dx,
      closeTo(tester.getTopLeft(receivedLabels.at(1)).dx, 0.1),
    );

    final sentLabels = find.descendant(
      of: sentBubble,
      matching: find.byType(Text),
    );
    expect(sentLabels, findsNWidgets(2));
    expect(
      tester.getBottomRight(sentLabels.at(0)).dx,
      closeTo(tester.getBottomRight(sentLabels.at(1)).dx, 0.1),
    );
  });

  testWidgets('shows the empty state for a newly created conversation', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 1);
    expect(repository.markReadCalls, 0);
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
    expect(find.byKey(const Key('conversation_error_state')), findsNothing);
  });

  testWidgets('keeps the retry state for a genuine history fetch failure', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..messageError = const ChatRepositoryException(
        'Messages could not be loaded. Please try again.',
      );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation_error_state')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.messageError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 2);
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
    expect(find.byKey(const Key('conversation_error_state')), findsNothing);
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

  testWidgets('records, uploads, sends, and renders a voice message', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    expect(recorder.startCalls, 1);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat_send_voice_button')));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(repository.sentAudioUrls, [uploader.url]);
    expect(find.byKey(const Key('chat_voice_play_sent-1')), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
  });

  testWidgets('cancels a recording without uploading a message', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_cancel_voice_button')));
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    expect(uploader.uploadCalls, 0);
    expect(repository.sentAudioUrls, isEmpty);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsNothing);
  });

  testWidgets('auto-stops with headroom before the hard duration limit', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 59));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsNothing);
  });

  testWidgets('keeps the microphone locked while stop is finalizing', (
    tester,
  ) async {
    final stopGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(stopGate: stopGate);
    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        voiceUploader: FakeChatVoiceUploader(),
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send_voice_button')));
    await tester.pump();

    final microphone = tester.widget<IconButton>(
      find.byKey(const Key('chat_record_voice_button')),
    );
    expect(microphone.onPressed, isNull);
    stopGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.startCalls, 1);
  });

  testWidgets('keeps the microphone locked while cancel is finalizing', (
    tester,
  ) async {
    final cancelGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(cancelGate: cancelGate);
    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        voiceUploader: FakeChatVoiceUploader(),
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_cancel_voice_button')));
    await tester.pump();

    final microphone = tester.widget<IconButton>(
      find.byKey(const Key('chat_record_voice_button')),
    );
    expect(microphone.onPressed, isNull);
    cancelGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.startCalls, 1);
  });

  testWidgets('locks the microphone while recorder startup is pending', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(startGate: startGate);
    await tester.pumpWidget(
      _buildSubject(repository: FakeChatRepository(), voiceRecorder: recorder),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final microphone = tester.widget<IconButton>(
      find.byKey(const Key('chat_record_voice_button')),
    );
    expect(microphone.onPressed, isNull);
    expect(recorder.startCalls, 1);

    startGate.complete();
    await tester.pump();
    expect(recorder.startCalls, 1);

    await tester.tap(find.byKey(const Key('chat_cancel_voice_button')));
    await tester.pumpAndSettle();
  });

  testWidgets('sequences cancellation before recorder disposal', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final cancelGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(
      startGate: startGate,
      cancelGate: cancelGate,
    );
    await tester.pumpWidget(
      _buildSubject(repository: FakeChatRepository(), voiceRecorder: recorder),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    expect(recorder.callOrder, ['start']);

    startGate.complete();
    await tester.pump();
    expect(recorder.callOrder, ['start', 'cancel']);
    cancelGate.complete();
    await tester.pump();
    expect(recorder.callOrder, ['start', 'cancel', 'dispose']);
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

  testWidgets('preserves the draft and explains a moderation rejection', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..sendError = const ChatRepositoryException(
        'Your message contains language that is not allowed. Please edit it and try again.',
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
      find.text(
        'Your message contains language that is not allowed. Please edit it and try again.',
      ),
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
