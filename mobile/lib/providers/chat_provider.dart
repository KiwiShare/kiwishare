import 'package:flutter/foundation.dart';

import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_photo_upload_service.dart';
import '../services/chat_voice_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.repository,
    ChatPhotoUploader? photoUploader,
    ChatVoiceUploader? voiceUploader,
  }) : photoUploader = photoUploader ?? R2ChatPhotoUploader(),
       voiceUploader = voiceUploader ?? R2ChatVoiceUploader();

  final ChatRepository repository;
  final ChatPhotoUploader photoUploader;
  final ChatVoiceUploader voiceUploader;

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
  final Set<String> _startingItemIds = {};
  final Set<String> _deletingConversationIds = {};
  final Map<String, String> _messageLoadErrors = {};
  final Map<String, String> _messageSendErrors = {};
  final Map<String, String> _conversationStartErrors = {};
  final Map<String, String> _conversationDeleteErrors = {};
  final Map<String, int> _conversationRenderVersions = {};

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
  bool isStartingConversation(String itemId) =>
      _startingItemIds.contains(itemId);
  String? conversationStartErrorFor(String itemId) =>
      _conversationStartErrors[itemId];
  bool isDeletingConversation(String conversationId) =>
      _deletingConversationIds.contains(conversationId);
  String? conversationDeleteErrorFor(String conversationId) =>
      _conversationDeleteErrors[conversationId];
  int conversationRenderVersionFor(String conversationId) =>
      _conversationRenderVersions[conversationId] ?? 0;

  Future<ChatConversationModel?> startConversation({
    required String itemId,
    required String token,
  }) async {
    if (itemId.isEmpty || token.isEmpty || _startingItemIds.contains(itemId)) {
      return null;
    }

    if (_sessionToken != token) {
      _sessionToken = token;
      _conversations = const [];
      _conversationError = null;
      _messages.clear();
      _messageLoadErrors.clear();
      _messageSendErrors.clear();
      _conversationStartErrors.clear();
      _conversationDeleteErrors.clear();
      _conversationRenderVersions.clear();
    }

    _startingItemIds.add(itemId);
    _conversationStartErrors.remove(itemId);
    notifyListeners();
    try {
      final conversation = await repository.createConversation(
        itemId: itemId,
        token: token,
      );
      if (_sessionToken != token) return null;
      final index = _conversations.indexWhere(
        (existing) => existing.id == conversation.id,
      );
      if (index == -1) {
        _conversations = [conversation, ..._conversations];
      } else {
        _replaceConversation(conversation);
      }
      return conversation;
    } on ChatAuthenticationException {
      if (_sessionToken == token) rethrow;
      return null;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _conversationStartErrors[itemId] = error.message;
      }
      return null;
    } catch (_) {
      if (_sessionToken == token) {
        _conversationStartErrors[itemId] =
            'Chat could not be started. Please try again.';
      }
      return null;
    } finally {
      _startingItemIds.remove(itemId);
      notifyListeners();
    }
  }

  Future<void> loadConversations(String token) async {
    if (_isLoadingConversations && _sessionToken == token) return;
    if (_sessionToken != token) {
      _sessionToken = token;
      _conversations = const [];
      _conversationError = null;
      _messages.clear();
      _messageLoadErrors.clear();
      _messageSendErrors.clear();
      _conversationStartErrors.clear();
      _conversationDeleteErrors.clear();
      _conversationRenderVersions.clear();
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
      final hasUnreadIncomingMessage = page.messages.any(
        (message) => !message.isMine && message.status != 'read',
      );
      if (conversation.unreadCount > 0 || hasUnreadIncomingMessage) {
        try {
          await repository.markConversationRead(
            conversationId: conversation.id,
            token: token,
          );
          _replaceConversation(conversation.copyWith(unreadCount: 0));
        } catch (_) {
          // History is already available. Keep the unread count so a later
          // visit can retry without replacing usable content with an error.
        }
      }
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
      _appendMessage(conversation, message, preview: message.text);
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

  Future<bool> sendPhoto({
    required ChatConversationModel conversation,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String token,
  }) async {
    const maximumPhotoBytes = 10 * 1024 * 1024;
    if (bytes.isEmpty ||
        bytes.length > maximumPhotoBytes ||
        token.isEmpty ||
        _sendingConversationIds.contains(conversation.id)) {
      if (bytes.length > maximumPhotoBytes) {
        _messageSendErrors[conversation.id] =
            'Choose a photo smaller than 10 MB.';
        notifyListeners();
      }
      return false;
    }

    _sendingConversationIds.add(conversation.id);
    _messageSendErrors.remove(conversation.id);
    notifyListeners();
    try {
      final imageUrl = await photoUploader.uploadPhoto(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        authToken: token,
      );
      final message = await repository.sendImageMessage(
        conversationId: conversation.id,
        imageUrl: imageUrl,
        token: token,
      );
      _appendMessage(conversation, message, preview: 'Photo');
      return true;
    } on ChatPhotoUploadException catch (error) {
      _messageSendErrors[conversation.id] = error.message;
      return false;
    } on ChatRepositoryException catch (error) {
      _messageSendErrors[conversation.id] = error.message;
      return false;
    } catch (_) {
      _messageSendErrors[conversation.id] =
          'Your photo was not sent. Please try again.';
      return false;
    } finally {
      _sendingConversationIds.remove(conversation.id);
      notifyListeners();
    }
  }

  Future<bool> sendVoice({
    required ChatConversationModel conversation,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required int durationMs,
    required String token,
  }) async {
    const maximumVoiceBytes = 5 * 1024 * 1024;
    if (bytes.isEmpty ||
        bytes.length > maximumVoiceBytes ||
        durationMs < 1 ||
        durationMs > 60000 ||
        token.isEmpty ||
        _sendingConversationIds.contains(conversation.id)) {
      if (bytes.length > maximumVoiceBytes) {
        _messageSendErrors[conversation.id] =
            'Keep the voice message smaller than 5 MB.';
      } else if (durationMs > 60000) {
        _messageSendErrors[conversation.id] =
            'Voice messages can be up to 60 seconds long.';
      }
      notifyListeners();
      return false;
    }

    _sendingConversationIds.add(conversation.id);
    _messageSendErrors.remove(conversation.id);
    notifyListeners();
    try {
      final audioUrl = await voiceUploader.uploadVoice(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        authToken: token,
      );
      final message = await repository.sendVoiceMessage(
        conversationId: conversation.id,
        audioUrl: audioUrl,
        durationMs: durationMs,
        token: token,
      );
      _appendMessage(conversation, message, preview: 'Voice message');
      return true;
    } on ChatVoiceException catch (error) {
      _messageSendErrors[conversation.id] = error.message;
      return false;
    } on ChatRepositoryException catch (error) {
      _messageSendErrors[conversation.id] = error.message;
      return false;
    } catch (_) {
      _messageSendErrors[conversation.id] =
          'Your voice message was not sent. Please try again.';
      return false;
    } finally {
      _sendingConversationIds.remove(conversation.id);
      notifyListeners();
    }
  }

  Future<bool> deleteConversation({
    required ChatConversationModel conversation,
    required String token,
  }) async {
    if (conversation.id.isEmpty ||
        token.isEmpty ||
        _sessionToken != token ||
        _deletingConversationIds.contains(conversation.id)) {
      return false;
    }

    final originalIndex = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (originalIndex == -1) return false;

    _deletingConversationIds.add(conversation.id);
    _conversationDeleteErrors.remove(conversation.id);
    _conversations = _conversations
        .where((item) => item.id != conversation.id)
        .toList(growable: false);
    notifyListeners();

    try {
      await repository.deleteConversation(
        conversationId: conversation.id,
        token: token,
      );
      if (_sessionToken == token) _messages.remove(conversation.id);
      return true;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _conversationDeleteErrors[conversation.id] = error.message;
        _refreshConversationRenderIdentity(conversation.id);
        _restoreConversation(conversation, originalIndex);
      }
      return false;
    } catch (_) {
      if (_sessionToken == token) {
        _conversationDeleteErrors[conversation.id] =
            'Chat could not be removed. Please try again.';
        _refreshConversationRenderIdentity(conversation.id);
        _restoreConversation(conversation, originalIndex);
      }
      return false;
    } finally {
      _deletingConversationIds.remove(conversation.id);
      notifyListeners();
    }
  }

  void clearMessageSendError(String conversationId) {
    if (_messageSendErrors.remove(conversationId) != null) notifyListeners();
  }

  void _appendMessage(
    ChatConversationModel conversation,
    ChatMessageModel message, {
    required String preview,
  }) {
    final messages = _messages[conversation.id] ?? const [];
    if (!messages.any((existing) => existing.id == message.id)) {
      _messages[conversation.id] = [...messages, message];
    }
    _replaceConversation(
      conversation.copyWith(
        lastMessage: preview,
        lastMessageAt: message.createdAt,
      ),
    );
  }

  void _replaceConversation(ChatConversationModel value) {
    final index = _conversations.indexWhere((item) => item.id == value.id);
    if (index == -1) return;
    _conversations = [..._conversations]..[index] = value;
  }

  void _restoreConversation(ChatConversationModel value, int originalIndex) {
    if (_conversations.any((item) => item.id == value.id)) return;
    final restored = [..._conversations];
    final safeIndex = originalIndex < restored.length
        ? originalIndex
        : restored.length;
    restored.insert(safeIndex, value);
    _conversations = restored;
  }

  void _refreshConversationRenderIdentity(String conversationId) {
    _conversationRenderVersions[conversationId] =
        conversationRenderVersionFor(conversationId) + 1;
  }
}
