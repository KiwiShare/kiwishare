import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/views/messages/chat_conversation_screen.dart';

import '../../support/fake_chat_repository.dart';

Widget _buildSubject({
  required FakeChatRepository repository,
  ChatConversationModel? conversation,
  String? authToken = 'valid-token',
  TextScaler textScaler = TextScaler.noScaling,
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
        chatProvider: ChatProvider(repository: repository),
        authToken: authToken,
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
