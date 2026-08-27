import 'package:flutter/foundation.dart';

import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({required this.repository});

  final ChatRepository repository;

  String? _sessionToken;
  bool ownsSession(String token) => _sessionToken == token;

  List<ChatConversationModel> _conversations = const [];
  List<ChatConversationModel> get conversations => _conversations;
  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;
  String? _conversationError;
  String? get conversationError => _conversationError;

  final Map<String, List<ChatMessageModel>> _messages = {};
  final Set<String> _loadingConversationIds = {};
  final Set<String> _sendingConversationIds = {};
  final Map<String, String> _messageLoadErrors = {};
  final Map<String, String> _messageSendErrors = {};

  List<ChatMessageModel> messagesFor(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);
  bool isLoadingMessages(String conversationId) =>
      _loadingConversationIds.contains(conversationId);
  bool isSending(String conversationId) =>
      _sendingConversationIds.contains(conversationId);
  String? messageLoadErrorFor(String conversationId) =>
      _messageLoadErrors[conversationId];
  String? messageSendErrorFor(String conversationId) =>
      _messageSendErrors[conversationId];

  Future<void> loadConversations(String token) async {
    if (_isLoadingConversations && _sessionToken == token) return;
    if (_sessionToken != token) {
      _sessionToken = token;
      _conversations = const [];
      _conversationError = null;
      _messages.clear();
      _messageLoadErrors.clear();
      _messageSendErrors.clear();
    }
    _isLoadingConversations = true;
    _conversationError = null;
    notifyListeners();
    try {
      final conversations = await repository.fetchConversations(token: token);
      if (_sessionToken == token) _conversations = conversations;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) _conversationError = error.message;
    } catch (_) {
      if (_sessionToken == token) {
        _conversationError = 'Chats could not be loaded. Please try again.';
      }
    } finally {
      if (_sessionToken == token) {
        _isLoadingConversations = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMessages({
    required ChatConversationModel conversation,
    required String token,
  }) async {
    if (_loadingConversationIds.contains(conversation.id)) return;
    _loadingConversationIds.add(conversation.id);
    _messageLoadErrors.remove(conversation.id);
    notifyListeners();
    try {
      final page = await repository.fetchMessages(
        conversationId: conversation.id,
        token: token,
      );
      _messages[conversation.id] = page.messages;
      await repository.markConversationRead(
        conversationId: conversation.id,
        token: token,
      );
      _replaceConversation(conversation.copyWith(unreadCount: 0));
    } on ChatRepositoryException catch (error) {
      _messageLoadErrors[conversation.id] = error.message;
    } catch (_) {
      _messageLoadErrors[conversation.id] =
          'Messages could not be loaded. Please try again.';
    } finally {
      _loadingConversationIds.remove(conversation.id);
      notifyListeners();
    }
  }

  Future<bool> sendText({
    required ChatConversationModel conversation,
    required String text,
    required String token,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty ||
        normalized.length > 2000 ||
        _sendingConversationIds.contains(conversation.id)) {
      return false;
    }

    _sendingConversationIds.add(conversation.id);
    _messageSendErrors.remove(conversation.id);
    notifyListeners();
    try {
      final message = await repository.sendTextMessage(
        conversationId: conversation.id,
        text: normalized,
        token: token,
      );
      final messages = _messages.putIfAbsent(conversation.id, () => []);
      if (!messages.any((existing) => existing.id == message.id)) {
        messages.add(message);
      }
      _replaceConversation(
        conversation.copyWith(
          lastMessage: message.text,
          lastMessageAt: message.createdAt,
        ),
      );
      return true;
    } on ChatRepositoryException catch (error) {
      _messageSendErrors[conversation.id] = error.message;
      return false;
    } catch (_) {
      _messageSendErrors[conversation.id] =
          'Your message was not sent. Please try again.';
      return false;
    } finally {
      _sendingConversationIds.remove(conversation.id);
      notifyListeners();
    }
  }

  void clearMessageSendError(String conversationId) {
    if (_messageSendErrors.remove(conversationId) != null) notifyListeners();
  }

  void _replaceConversation(ChatConversationModel value) {
    final index = _conversations.indexWhere((item) => item.id == value.id);
    if (index == -1) return;
    _conversations = [..._conversations]..[index] = value;
  }
}
