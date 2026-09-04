import 'dart:async';

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
  int get totalUnreadCount => _conversations.fold<int>(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );
  ChatConversationModel? conversationById(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  ChatConversationModel? conversationByIdForSession(
    String conversationId,
    String? token,
  ) {
    if (token == null || !ownsSession(token)) return null;
    return conversationById(conversationId);
  }

  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;
  String? _conversationError;
  String? get conversationError => _conversationError;
  Completer<void>? _conversationLoadCompleter;
  bool _conversationRefreshQueued = false;

  final Map<String, List<ChatMessageModel>> _messages = {};
  final Map<String, ChatConversationModel> _messageConversationSnapshots = {};
  final Set<String> _loadingConversationIds = {};
  final Set<String> _sendingConversationIds = {};
  final Set<String> _startingItemIds = {};
  final Set<String> _deletingConversationIds = {};
  final Map<String, String> _messageLoadErrors = {};
  final Map<String, String> _messageReadErrors = {};
  final Map<String, String> _messageSendErrors = {};
  final Map<String, String> _conversationStartErrors = {};
  final Map<String, String> _conversationDeleteErrors = {};
  final Map<String, int> _conversationRenderVersions = {};
  final Map<String, Future<bool>> _markingReadOperations = {};
  final Map<String, String> _activeReadWatermarks = {};
  final Map<String, String> _queuedReadWatermarks = {};
  final Map<String, Completer<void>> _messageLoadCompleters = {};
  final Set<String> _messageRefreshQueued = {};

  List<ChatMessageModel> messagesFor(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);
  ChatConversationModel? messageConversationByIdForSession(
    String conversationId,
    String? token,
  ) {
    if (token == null || !ownsSession(token)) return null;
    return conversationById(conversationId) ??
        _messageConversationSnapshots[conversationId];
  }

  bool isLoadingMessages(String conversationId) =>
      _loadingConversationIds.contains(conversationId);
  bool isSending(String conversationId) =>
      _sendingConversationIds.contains(conversationId);
  String? messageLoadErrorFor(String conversationId) =>
      _messageLoadErrors[conversationId];
  String? messageReadErrorFor(String conversationId) =>
      _messageReadErrors[conversationId];
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

  void updateAuthToken(String? token) {
    if (_sessionToken == token) return;
    _resetSession(token);
    if (token == null || token.isEmpty) {
      scheduleMicrotask(notifyListeners);
      return;
    }
    scheduleMicrotask(() {
      if (_sessionToken == token) unawaited(loadConversations(token));
    });
  }

  void _useSession(String token) {
    if (_sessionToken == token) return;
    _resetSession(token);
  }

  void _resetSession(String? token) {
    _sessionToken = token;
    _conversations = const [];
    _isLoadingConversations = false;
    _conversationError = null;
    _conversationRefreshQueued = false;
    _messages.clear();
    _messageConversationSnapshots.clear();
    _loadingConversationIds.clear();
    _sendingConversationIds.clear();
    _startingItemIds.clear();
    _deletingConversationIds.clear();
    _messageLoadErrors.clear();
    _messageReadErrors.clear();
    _messageSendErrors.clear();
    _conversationStartErrors.clear();
    _conversationDeleteErrors.clear();
    _conversationRenderVersions.clear();
    _markingReadOperations.clear();
    _activeReadWatermarks.clear();
    _queuedReadWatermarks.clear();
    _messageLoadCompleters.clear();
    _messageRefreshQueued.clear();
  }

  Future<ChatConversationModel?> startConversation({
    required String itemId,
    required String token,
  }) async {
    if (itemId.isEmpty || token.isEmpty || _startingItemIds.contains(itemId)) {
      return null;
    }

    _useSession(token);

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
      if (_sessionToken == token) {
        _startingItemIds.remove(itemId);
        notifyListeners();
      }
    }
  }

  Future<void> loadConversations(
    String token, {
    bool queueIfBusy = false,
  }) async {
    if (_isLoadingConversations && _sessionToken == token) {
      if (!queueIfBusy) return;
      _conversationRefreshQueued = true;
      final activeLoad = _conversationLoadCompleter?.future;
      if (activeLoad != null) await activeLoad;
      if (_sessionToken == token && _conversationRefreshQueued) {
        _conversationRefreshQueued = false;
        await loadConversations(token);
      }
      return;
    }
    _useSession(token);
    _isLoadingConversations = true;
    final loadCompleter = Completer<void>();
    _conversationLoadCompleter = loadCompleter;
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
      if (!loadCompleter.isCompleted) loadCompleter.complete();
      if (identical(_conversationLoadCompleter, loadCompleter)) {
        _conversationLoadCompleter = null;
      }
    }
  }

  Future<void> loadMessages({
    required ChatConversationModel conversation,
    required String token,
    bool queueIfBusy = false,
    bool Function()? shouldMarkRead,
  }) async {
    _useSession(token);
    _messageConversationSnapshots[conversation.id] = conversation;
    if (_loadingConversationIds.contains(conversation.id)) {
      if (!queueIfBusy) return;
      _messageRefreshQueued.add(conversation.id);
      final activeLoad = _messageLoadCompleters[conversation.id]?.future;
      if (activeLoad != null) await activeLoad;
      if (_sessionToken == token &&
          _messageRefreshQueued.remove(conversation.id)) {
        await loadMessages(
          conversation: conversation,
          token: token,
          shouldMarkRead: shouldMarkRead,
        );
      }
      return;
    }
    final messageIdsAtStart = (_messages[conversation.id] ?? const [])
        .map((message) => message.id)
        .toSet();
    _loadingConversationIds.add(conversation.id);
    final loadCompleter = Completer<void>();
    _messageLoadCompleters[conversation.id] = loadCompleter;
    _messageLoadErrors.remove(conversation.id);
    notifyListeners();
    try {
      final page = await repository.fetchMessages(
        conversationId: conversation.id,
        token: token,
      );
      if (_sessionToken != token) return;
      final fetchedIds = page.messages.map((message) => message.id).toSet();
      final messagesAddedWhileLoading = (_messages[conversation.id] ?? const [])
          .where(
            (message) =>
                !messageIdsAtStart.contains(message.id) &&
                !fetchedIds.contains(message.id),
          );
      _messages[conversation.id] =
          [...page.messages, ...messagesAddedWhileLoading]..sort((left, right) {
            final timeOrder = left.createdAt.compareTo(right.createdAt);
            return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
          });
      final hasUnreadIncomingMessage = page.messages.any(
        (message) => !message.isMine && message.status != 'read',
      );
      final canonical = conversationById(conversation.id) ?? conversation;
      if ((shouldMarkRead?.call() ?? true) &&
          (canonical.unreadCount > 0 || hasUnreadIncomingMessage)) {
        final readThroughMessageId = _latestMessageId(page.messages);
        if (readThroughMessageId != null) {
          await markConversationRead(
            conversation: canonical,
            token: token,
            throughMessageId: readThroughMessageId,
          );
        }
      }
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _messageLoadErrors[conversation.id] = error.message;
      }
    } catch (_) {
      if (_sessionToken == token) {
        _messageLoadErrors[conversation.id] =
            'Messages could not be loaded. Please try again.';
      }
    } finally {
      if (_sessionToken == token) {
        _loadingConversationIds.remove(conversation.id);
        notifyListeners();
      }
      if (!loadCompleter.isCompleted) loadCompleter.complete();
      if (identical(_messageLoadCompleters[conversation.id], loadCompleter)) {
        _messageLoadCompleters.remove(conversation.id);
      }
    }
  }

  Future<bool> markConversationRead({
    required ChatConversationModel conversation,
    required String token,
    String? throughMessageId,
  }) {
    if (conversation.id.isEmpty || token.isEmpty) return Future.value(false);
    _useSession(token);
    final watermark =
        throughMessageId ??
        _latestMessageId(_messages[conversation.id] ?? const []);
    if (watermark == null) return Future.value(false);
    final highestWatermark =
        _queuedReadWatermarks[conversation.id] ??
        _activeReadWatermarks[conversation.id];
    if (highestWatermark == null || watermark.compareTo(highestWatermark) > 0) {
      _queuedReadWatermarks[conversation.id] = watermark;
    }
    final pending = _markingReadOperations[conversation.id];
    if (pending != null) return pending;

    late final Future<bool> operation;
    operation =
        _drainMarkConversationRead(
          conversation: conversation,
          token: token,
        ).whenComplete(() {
          if (identical(_markingReadOperations[conversation.id], operation)) {
            _markingReadOperations.remove(conversation.id);
          }
        });
    _markingReadOperations[conversation.id] = operation;
    return operation;
  }

  Future<bool> _drainMarkConversationRead({
    required ChatConversationModel conversation,
    required String token,
  }) async {
    var succeeded = true;
    while (_sessionToken == token) {
      final watermark = _queuedReadWatermarks.remove(conversation.id);
      if (watermark == null) break;
      _activeReadWatermarks[conversation.id] = watermark;
      try {
        succeeded = await _markConversationReadNow(
          conversation: conversation,
          token: token,
          throughMessageId: watermark,
        );
      } finally {
        if (_activeReadWatermarks[conversation.id] == watermark) {
          _activeReadWatermarks.remove(conversation.id);
        }
      }
      if (!succeeded) {
        _queuedReadWatermarks.remove(conversation.id);
        break;
      }
    }
    return succeeded && _sessionToken == token;
  }

  Future<bool> _markConversationReadNow({
    required ChatConversationModel conversation,
    required String token,
    required String throughMessageId,
  }) async {
    final canonical = conversationById(conversation.id) ?? conversation;
    final previousUnreadCount = canonical.unreadCount;
    final clearedReadError = _messageReadErrors.remove(conversation.id) != null;
    if (previousUnreadCount > 0 && conversationById(conversation.id) != null) {
      _replaceConversation(canonical.copyWith(unreadCount: 0));
      notifyListeners();
    } else if (clearedReadError) {
      notifyListeners();
    }

    try {
      final remainingUnreadCount = await repository.markConversationRead(
        conversationId: conversation.id,
        throughMessageId: throughMessageId,
        token: token,
      );
      if (_sessionToken == token) {
        final current = conversationById(conversation.id);
        if (_isLoadingConversations ||
            (current != null && current.unreadCount > 0)) {
          await loadConversations(token, queueIfBusy: true);
        } else if (current != null &&
            current.unreadCount != remainingUnreadCount) {
          _replaceConversation(
            current.copyWith(unreadCount: remainingUnreadCount),
          );
          notifyListeners();
        }
      }
      return _sessionToken == token;
    } catch (_) {
      if (_sessionToken == token) {
        final current = conversationById(conversation.id);
        if (previousUnreadCount > 0 &&
            current != null &&
            current.unreadCount == 0) {
          _replaceConversation(
            current.copyWith(unreadCount: previousUnreadCount),
          );
        }
        _messageReadErrors[conversation.id] =
            'Messages could not be marked as read. Try again.';
        notifyListeners();
      }
      return false;
    }
  }

  String? _latestMessageId(Iterable<ChatMessageModel> messages) {
    ChatMessageModel? latest;
    for (final message in messages) {
      if (latest == null ||
          message.createdAt.isAfter(latest.createdAt) ||
          (message.createdAt == latest.createdAt &&
              message.id.compareTo(latest.id) > 0)) {
        latest = message;
      }
    }
    return latest?.id;
  }

  Future<bool> sendText({
    required ChatConversationModel conversation,
    required String text,
    required String token,
  }) async {
    if (token.isNotEmpty) _useSession(token);
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
      if (_sessionToken != token) return false;
      _appendMessage(conversation, message, preview: message.text);
      return true;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] = error.message;
      }
      return false;
    } catch (_) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] =
            'Your message was not sent. Please try again.';
      }
      return false;
    } finally {
      if (_sessionToken == token) {
        _sendingConversationIds.remove(conversation.id);
        notifyListeners();
      }
    }
  }

  Future<bool> sendPhoto({
    required ChatConversationModel conversation,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String token,
  }) async {
    if (token.isNotEmpty) _useSession(token);
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
      if (_sessionToken != token) return false;
      _appendMessage(conversation, message, preview: 'Photo');
      return true;
    } on ChatPhotoUploadException catch (error) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] = error.message;
      }
      return false;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] = error.message;
      }
      return false;
    } catch (_) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] =
            'Your photo was not sent. Please try again.';
      }
      return false;
    } finally {
      if (_sessionToken == token) {
        _sendingConversationIds.remove(conversation.id);
        notifyListeners();
      }
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

  Future<bool> sendLocation({
    required ChatConversationModel conversation,
    required String name,
    required double latitude,
    required double longitude,
    required String token,
  }) async {
    if (token.isNotEmpty) _useSession(token);
    if (name.trim().isEmpty ||
        _sendingConversationIds.contains(conversation.id)) {
      return false;
    }

    _sendingConversationIds.add(conversation.id);
    _messageSendErrors.remove(conversation.id);
    notifyListeners();
    try {
      final message = await repository.sendLocationMessage(
        conversationId: conversation.id,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        token: token,
      );
      if (_sessionToken != token) return false;
      _appendMessage(conversation, message, preview: '📍 ${name.trim()}');
      return true;
    } on ChatRepositoryException catch (error) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] = error.message;
      }
      return false;
    } catch (_) {
      if (_sessionToken == token) {
        _messageSendErrors[conversation.id] =
            'Your location was not sent. Please try again.';
      }
      return false;
    } finally {
      if (_sessionToken == token) {
        _sendingConversationIds.remove(conversation.id);
        notifyListeners();
      }
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
      if (_sessionToken != token) return false;
      _messages.remove(conversation.id);
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
      if (_sessionToken == token) {
        _deletingConversationIds.remove(conversation.id);
        notifyListeners();
      }
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
    final canonical = conversationById(conversation.id) ?? conversation;
    _replaceConversation(
      canonical.copyWith(
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
