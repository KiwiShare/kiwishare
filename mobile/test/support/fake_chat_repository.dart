import 'dart:async';

import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/models/chat_message_model.dart';
import 'package:kiwishare/repositories/chat_repository.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.conversations = const [],
    Map<String, List<ChatMessageModel>>? messages,
  }) : messages = messages ?? {};

  List<ChatConversationModel> conversations;
  final Map<String, List<ChatMessageModel>> messages;
  ChatRepositoryException? conversationError;
  ChatRepositoryException? createError;
  ChatRepositoryException? messageError;
  Object? markReadError;
  ChatRepositoryException? sendError;
  ChatRepositoryException? deleteError;
  ChatConversationModel? createdConversation;
  Completer<ChatConversationModel>? createCompleter;
  int conversationFetches = 0;
  int createCalls = 0;
  int messageFetches = 0;
  int markReadCalls = 0;
  int sendCalls = 0;
  int deleteCalls = 0;
  final List<String> sentTexts = [];
  final List<String> sentImageUrls = [];
  final List<String> sentAudioUrls = [];
  final List<int> sentVoiceDurations = [];
  final List<String> createdItemIds = [];
  final List<String> deletedConversationIds = [];

  @override
  Future<List<ChatConversationModel>> fetchConversations({
    required String token,
  }) async {
    conversationFetches += 1;
    if (conversationError != null) throw conversationError!;
    return conversations;
  }

  @override
  Future<ChatConversationModel> createConversation({
    required String itemId,
    required String token,
  }) async {
    createCalls += 1;
    createdItemIds.add(itemId);
    if (createError != null) throw createError!;
    final completer = createCompleter;
    if (completer != null) return completer.future;
    return createdConversation ?? conversations.first;
  }

  @override
  Future<ChatMessagePage> fetchMessages({
    required String conversationId,
    required String token,
    DateTime? before,
    int limit = 50,
  }) async {
    messageFetches += 1;
    if (messageError != null) throw messageError!;
    return ChatMessagePage(
      // Match the REST repository, which returns a fixed-length page list.
      messages: List.unmodifiable(messages[conversationId] ?? const []),
      hasMore: false,
    );
  }

  @override
  Future<void> markConversationRead({
    required String conversationId,
    required String token,
  }) async {
    markReadCalls += 1;
    if (markReadError != null) throw markReadError!;
  }

  @override
  Future<void> deleteConversation({
    required String conversationId,
    required String token,
  }) async {
    deleteCalls += 1;
    deletedConversationIds.add(conversationId);
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<ChatMessageModel> sendTextMessage({
    required String conversationId,
    required String text,
    required String token,
  }) async {
    sendCalls += 1;
    sentTexts.add(text);
    if (sendError != null) throw sendError!;
    final message = ChatMessageModel(
      id: 'sent-$sendCalls',
      conversationId: conversationId,
      senderId: 'current-user',
      receiverId: 'other-user',
      text: text,
      status: 'sent',
      isMine: true,
      createdAt: DateTime.utc(2026, 8, 27, 8, sendCalls),
    );
    messages.putIfAbsent(conversationId, () => []).add(message);
    return message;
  }

  @override
  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String imageUrl,
    required String token,
  }) async {
    sendCalls += 1;
    sentImageUrls.add(imageUrl);
    if (sendError != null) throw sendError!;
    final message = ChatMessageModel(
      id: 'sent-$sendCalls',
      conversationId: conversationId,
      senderId: 'current-user',
      receiverId: 'other-user',
      type: 'image',
      text: '',
      imageUrl: imageUrl,
      status: 'sent',
      isMine: true,
      createdAt: DateTime.utc(2026, 8, 27, 8, sendCalls),
    );
    messages.putIfAbsent(conversationId, () => []).add(message);
    return message;
  }

  @override
  Future<ChatMessageModel> sendVoiceMessage({
    required String conversationId,
    required String audioUrl,
    required int durationMs,
    required String token,
  }) async {
    sendCalls += 1;
    sentAudioUrls.add(audioUrl);
    sentVoiceDurations.add(durationMs);
    if (sendError != null) throw sendError!;
    final message = ChatMessageModel(
      id: 'sent-$sendCalls',
      conversationId: conversationId,
      senderId: 'current-user',
      receiverId: 'other-user',
      type: 'voice',
      text: '',
      audioUrl: audioUrl,
      durationMs: durationMs,
      status: 'sent',
      isMine: true,
      createdAt: DateTime.utc(2026, 8, 27, 8, sendCalls),
    );
    messages.putIfAbsent(conversationId, () => []).add(message);
    return message;
  }
}

ChatConversationModel testConversation({
  String id = 'conversation-1',
  String participantName = 'Sophie M.',
  String itemTitle = 'Ergonomic Office Chair',
  ChatDirection direction = ChatDirection.buying,
  String lastMessage = 'Is this still available?',
  int unreadCount = 0,
  String status = 'active',
}) {
  return ChatConversationModel(
    id: id,
    itemId: 'item-$id',
    itemTitle: itemTitle,
    itemImageUrl: '',
    participantId: 'participant-$id',
    participantName: participantName,
    direction: direction,
    status: status,
    lastMessage: lastMessage,
    lastMessageAt: DateTime.utc(2026, 8, 27, 8, 30),
    unreadCount: unreadCount,
  );
}

ChatMessageModel testMessage({
  required String id,
  required String text,
  required bool isMine,
  String type = 'text',
  String? imageUrl,
  String? audioUrl,
  int? durationMs,
}) {
  return ChatMessageModel(
    id: id,
    conversationId: 'conversation-1',
    senderId: isMine ? 'current-user' : 'other-user',
    receiverId: isMine ? 'other-user' : 'current-user',
    type: type,
    text: text,
    imageUrl: imageUrl,
    audioUrl: audioUrl,
    durationMs: durationMs,
    status: 'sent',
    isMine: isMine,
    createdAt: DateTime.utc(2026, 8, 27, 8, int.parse(id)),
  );
}
