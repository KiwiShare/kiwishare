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
  Completer<void>? markReadCompleter;
  ChatRepositoryException? sendError;
  ChatRepositoryException? deleteError;
  ChatConversationModel? createdConversation;
  Completer<ChatConversationModel>? createCompleter;
  final List<Completer<List<ChatConversationModel>>> conversationCompleters =
      [];
  final Map<String, Completer<ChatMessagePage>> messageCompletersByToken = {};
  final List<Completer<ChatMessagePage>> messageCompleters = [];
  int conversationFetches = 0;
  int createCalls = 0;
  int messageFetches = 0;
  int markReadCalls = 0;
  int remainingUnreadCount = 0;
  final List<String> readThroughMessageIds = [];
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
    if (conversationCompleters.isNotEmpty) {
      return conversationCompleters.removeAt(0).future;
    }
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
    if (messageCompleters.isNotEmpty) {
      return messageCompleters.removeAt(0).future;
    }
    final completer = messageCompletersByToken[token];
    if (completer != null) return completer.future;
    return ChatMessagePage(
      // Match the REST repository, which returns a fixed-length page list.
      messages: List.unmodifiable(messages[conversationId] ?? const []),
      hasMore: false,
    );
  }

  @override
  Future<int> markConversationRead({
    required String conversationId,
    required String throughMessageId,
    required String token,
  }) async {
    markReadCalls += 1;
    readThroughMessageIds.add(throughMessageId);
    final completer = markReadCompleter;
    if (completer != null) await completer.future;
    if (markReadError != null) throw markReadError!;
    return remainingUnreadCount;
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

  @override
  Future<ChatMessageModel> sendLocationMessage({
    required String conversationId,
    required String name,
    required double latitude,
    required double longitude,
    required String token,
  }) async {
    sendCalls += 1;
    if (sendError != null) throw sendError!;
    final message = ChatMessageModel(
      id: 'sent-$sendCalls',
      conversationId: conversationId,
      senderId: 'current-user',
      receiverId: 'other-user',
      type: 'location',
      text: '📍 $name',
      location: ChatLocationPayload(
        name: name,
        latitude: latitude,
        longitude: longitude,
      ),
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
  String? participantAvatarUrl,
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
    participantAvatarUrl: participantAvatarUrl,
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
  ChatLocationPayload? location,
  ChatMeetupPayload? meetup,
  String status = 'sent',
  DateTime? readAt,
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
    location: location,
    meetup: meetup,
    status: status,
    isMine: isMine,
    createdAt: DateTime.utc(2026, 8, 27, 8, int.parse(id)),
    readAt: readAt,
  );
}
