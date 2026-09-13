import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../config/api_config.dart';
import '../../navigation/app_route_observer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/listing_image_picker.dart';
import '../../services/chat_voice_service.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../theme/app_theme.dart';
import 'widgets/location_bubble.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/meetup_card_bubble.dart';
import 'widgets/schedule_meetup_sheet.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.chatProvider,
    this.authToken,
    this.imagePicker,
    this.voiceRecorder,
    this.permissionCoordinator,
    this.enablePolling = false,
    this.pollingInterval,
  });

  final ChatConversationModel conversation;
  final ChatProvider? chatProvider;
  final String? authToken;
  final ListingImagePicker? imagePicker;
  final ChatVoiceRecorder? voiceRecorder;
  final NotificationPermissionCoordinator? permissionCoordinator;
  final bool? enablePolling;
  final Duration? pollingInterval;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver, RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late final ListingImagePicker _imagePicker;
  late final ChatVoiceRecorder _voiceRecorder;
  Timer? _recordingTimer;
  Timer? _conversationPollTimer;
  Timer? _focusScrollTimer;
  bool _isRecording = false;
  bool _isStartingVoice = false;
  bool _isFinalizingVoice = false;
  Future<void> _recorderQueue = Future<void>.value();
  int _recordingSeconds = 0;
  String? _loadedToken;
  String? _currentAuthToken;
  bool _leftForeground = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  ModalRoute<dynamic>? _subscribedRoute;
  final Object _visibilityOwner = Object();

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_handleFocusChange);
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
    _voiceRecorder = widget.voiceRecorder ?? DeviceChatVoiceRecorder();
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPhoto());
  }

  void _handleFocusChange() {
    if (_messageFocusNode.hasFocus) {
      _focusScrollTimer?.cancel();
      _focusScrollTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToEnd();
      });
    }
  }

  void _startConversationPolling() {
    _conversationPollTimer?.cancel();
    if (!(widget.enablePolling ?? false) ||
        !_isCurrentRoute ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final interval = widget.pollingInterval ?? const Duration(seconds: 3);
    _conversationPollTimer = Timer.periodic(interval, (_) async {
      if (!mounted ||
          !_isCurrentRoute ||
          _lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final token = _currentAuthToken;
      if (token == null ||
          token.isEmpty ||
          _chatProvider.isLoadingMessages(widget.conversation.id)) {
        return;
      }
      final previousCount = _chatProvider
          .messagesFor(widget.conversation.id)
          .length;
      await _chatProvider.loadMessages(
        conversation: widget.conversation,
        token: token,
        queueIfBusy: true,
        shouldMarkRead: () => _isCurrentRoute,
      );
      if (!mounted) return;
      final currentCount = _chatProvider
          .messagesFor(widget.conversation.id)
          .length;
      if (currentCount > previousCount) {
        _scrollToEnd();
      }
    });
  }

  void _stopConversationPolling() {
    _conversationPollTimer?.cancel();
    _conversationPollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncVisibility();
    if (state != AppLifecycleState.resumed) {
      _leftForeground = true;
      _stopConversationPolling();
      return;
    }
    if (!_leftForeground) return;
    _leftForeground = false;
    unawaited(_refreshAfterResume());
    _startConversationPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<dynamic>(context);
    if (identical(route, _subscribedRoute)) return;
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
    _syncVisibility();
  }

  @override
  void didPushNext() {
    _syncVisibility();
    _stopConversationPolling();
  }

  @override
  void didPopNext() {
    _syncVisibility();
    unawaited(_refreshAfterResume());
    _startConversationPolling();
  }

  Future<void> _refreshAfterResume() async {
    final token = _currentAuthToken;
    if (!_isCurrentRoute || token == null || token.isEmpty) return;
    await _chatProvider.loadMessages(
      conversation: widget.conversation,
      token: token,
      queueIfBusy: true,
      shouldMarkRead: () => _isCurrentRoute,
    );
    if (mounted) _scrollToEnd();
  }

  bool get _isCurrentRoute =>
      mounted &&
      _lifecycleState == AppLifecycleState.resumed &&
      (ModalRoute.of<dynamic>(context)?.isCurrent ?? false);

  void _syncVisibility() {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) {
      chatVisibilityTracker.clear(_visibilityOwner);
      return;
    }
    chatVisibilityTracker.update(
      owner: _visibilityOwner,
      conversationId: widget.conversation.id,
      sessionToken: token,
      visible: _isCurrentRoute,
    );
  }

  ChatProvider get _chatProvider =>
      widget.chatProvider ?? context.read<ChatProvider>();
  void _ensureLoaded(String? token) {
    _currentAuthToken = token;
    _syncVisibility();
    if (token == null || token.isEmpty) {
      _loadedToken = null;
      _stopConversationPolling();
      return;
    }
    if (token != _loadedToken) {
      _loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _chatProvider.loadMessages(
          conversation: widget.conversation,
          token: token,
          shouldMarkRead: () => _isCurrentRoute,
        );
        _scrollToEnd();
        _startConversationPolling();
      });
    }
  }

  @override
  void dispose() {
    _focusScrollTimer?.cancel();
    _stopConversationPolling();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageFocusNode.dispose();
    chatVisibilityTracker.clear(_visibilityOwner);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    if (_isRecording || _isStartingVoice) {
      unawaited(_queueRecorder(_voiceRecorder.cancel));
    }
    unawaited(_queueRecorder(_voiceRecorder.dispose));
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<T> _queueRecorder<T>(Future<T> Function() operation) {
    final result = _recorderQueue.then((_) => operation());
    _recorderQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _retry() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.loadMessages(
      conversation: widget.conversation,
      token: token,
      shouldMarkRead: () => _isCurrentRoute,
    );
    _scrollToEnd();
  }

  Future<void> _retryMarkRead() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.markConversationRead(
      conversation: widget.conversation,
      token: token,
      shouldMarkRead: () => _isCurrentRoute,
    );
  }

  Future<void> _offerNotificationPermissionAfterAction() async {
    if (!mounted) return;
    await offerContextualNotificationPermission(
      context,
      coordinator: widget.permissionCoordinator,
    );
  }

  void _requestNotificationPermissionAfterAction() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_offerNotificationPermissionAfterAction());
    });
  }

  Future<void> _send() async {
    final token = _currentAuthToken;
    final text = _messageController.text;
    if (token == null || token.isEmpty || text.trim().isEmpty) return;
    final sent = await _chatProvider.sendText(
      conversation: widget.conversation,
      text: text,
      token: token,
    );
    if (!mounted) return;
    if (sent) {
      _messageController.clear();
      _scrollToEnd();
      _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<_ChatPhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _ChatPhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    try {
      final XFile? file;
      if (source == _ChatPhotoSource.camera) {
        file = await _imagePicker.takePhoto();
      } else {
        final files = await _imagePicker.chooseFromGallery(limit: 1);
        file = files.isEmpty ? null : files.first;
      }
      if (file == null || !mounted) return;
      await _sendPhoto(file);
    } on PlatformException {
      _showPhotoPickerError(
        'Camera or photo access is unavailable. Check the app permissions and try again.',
      );
    } catch (_) {
      _showPhotoPickerError(
        'That photo could not be opened. Please try again.',
      );
    }
  }

  Future<void> _recoverLostPhoto() async {
    try {
      final files = await _imagePicker.recoverLostPhotos();
      if (files.isEmpty || !mounted) return;
      await _sendPhoto(files.first, offerPermission: false);
    } on PlatformException {
      _showPhotoPickerError(
        'The selected photo could not be restored. Please choose it again.',
      );
    } catch (_) {
      _showPhotoPickerError(
        'The selected photo could not be restored. Please choose it again.',
      );
    }
  }

  Future<void> _sendPhoto(XFile file, {bool offerPermission = true}) async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty || !mounted) return;
    final contentType = _photoContentType(file);
    final sent = await _chatProvider.sendPhoto(
      conversation: widget.conversation,
      bytes: await file.readAsBytes(),
      fileName: file.name.isEmpty
          ? 'chat_photo_${DateTime.now().millisecondsSinceEpoch}.${_photoExtension(contentType)}'
          : file.name,
      contentType: contentType,
      token: token,
    );
    if (sent && mounted) {
      _scrollToEnd();
      if (offerPermission) _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _shareLocation() async {
    final selection = await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const LocationPickerSheet(),
    );
    if (selection == null || !mounted) return;
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    final sent = await _chatProvider.sendLocation(
      conversation: widget.conversation,
      name: selection.name,
      latitude: selection.latitude,
      longitude: selection.longitude,
      token: token,
    );
    if (sent && mounted) {
      _scrollToEnd();
      _requestNotificationPermissionAfterAction();
    }
  }

  Future<void> _scheduleMeetup() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ScheduleMeetupSheet(
        itemId: widget.conversation.itemId,
        itemTitle: widget.conversation.itemTitle,
        counterpartId: widget.conversation.participantId,
        counterpartName: widget.conversation.participantName,
        onProposed: (meetup) {
          if (mounted && token.isNotEmpty) {
            _chatProvider.loadMessages(
              conversation: widget.conversation,
              token: token,
              shouldMarkRead: () => _isCurrentRoute,
            );
            _scrollToEnd();
          }
        },
      ),
    );
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording ||
        _isStartingVoice ||
        _isFinalizingVoice ||
        _chatProvider.isSending(widget.conversation.id)) {
      return;
    }
    setState(() => _isStartingVoice = true);
    try {
      await _queueRecorder(_voiceRecorder.start);
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        setState(() => _recordingSeconds += 1);
        // Keep one second of headroom so timer scheduling jitter cannot push
        // the native recording beyond the server's hard 60-second limit.
        if (_recordingSeconds >= 59) {
          timer.cancel();
          unawaited(_finishVoiceRecording(send: true));
        }
      });
    } on ChatVoiceException catch (error) {
      _showComposerError(error.message);
    } on PlatformException {
      _showComposerError(
        'Microphone access is unavailable. Check the app permissions and try again.',
      );
    } catch (_) {
      _showComposerError(
        'Voice recording could not be started. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isStartingVoice = false);
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (!_isRecording || _isFinalizingVoice) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isFinalizingVoice = true;
    });

    try {
      if (!send) {
        await _queueRecorder(_voiceRecorder.cancel);
        return;
      }
      final recording = await _queueRecorder(_voiceRecorder.stop);
      final token = _currentAuthToken;
      if (recording == null || token == null || token.isEmpty || !mounted) {
        return;
      }
      final sent = await _chatProvider.sendVoice(
        conversation: widget.conversation,
        bytes: recording.bytes,
        fileName: recording.fileName,
        contentType: recording.contentType,
        durationMs: recording.durationMs,
        token: token,
      );
      if (sent && mounted) {
        _scrollToEnd();
        _requestNotificationPermissionAfterAction();
      }
    } on ChatVoiceException catch (error) {
      _showComposerError(error.message);
    } catch (_) {
      _showComposerError(
        'The voice message could not be prepared. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizingVoice = false;
          _recordingSeconds = 0;
        });
      }
    }
  }

  void _showPhotoPickerError(String message) {
    _showComposerError(message);
  }

  void _showComposerError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _chatProvider;
    final token = widget.authToken ?? context.watch<AuthProvider?>()?.jwtToken;
    _ensureLoaded(token);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.participantName,
              key: const Key('conversation_participant_name'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              widget.conversation.itemTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('chat_schedule_meetup_action'),
            tooltip: 'Schedule Meetup',
            icon: const Icon(Icons.handshake_outlined),
            onPressed:
                widget.conversation.isActive &&
                    (_currentAuthToken?.isNotEmpty ?? false)
                ? _scheduleMeetup
                : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) => Column(
            children: [
              Expanded(child: _buildHistory(provider)),
              if (provider.messageReadErrorFor(widget.conversation.id) != null)
                _InlineChatError(
                  key: const Key('conversation_read_error'),
                  message: provider.messageReadErrorFor(
                    widget.conversation.id,
                  )!,
                  actionLabel: 'Retry',
                  onAction: _retryMarkRead,
                ),
              if (provider.messageSendErrorFor(widget.conversation.id) != null)
                _InlineChatError(
                  key: const Key('conversation_inline_error'),
                  message: provider.messageSendErrorFor(
                    widget.conversation.id,
                  )!,
                ),
              _MessageComposer(
                controller: _messageController,
                focusNode: _messageFocusNode,
                isSending:
                    provider.isSending(widget.conversation.id) ||
                    _isStartingVoice ||
                    _isFinalizingVoice,
                enabled:
                    widget.conversation.isActive &&
                    (_currentAuthToken?.isNotEmpty ?? false),
                onAddPhoto: _addPhoto,
                onShareLocation: _shareLocation,
                onSend: _send,
                isRecording: _isRecording,
                recordingSeconds: _recordingSeconds,
                onStartRecording: _startVoiceRecording,
                onCancelRecording: () => _finishVoiceRecording(send: false),
                onSendRecording: () => _finishVoiceRecording(send: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(ChatProvider provider) {
    if (_currentAuthToken == null || _currentAuthToken!.isEmpty) {
      return const _ConversationState(
        key: Key('conversation_signed_out_state'),
        icon: Icons.lock_outline,
        message: 'Sign in to view this conversation.',
      );
    }
    if (provider.isLoadingMessages(widget.conversation.id) &&
        provider.messagesFor(widget.conversation.id).isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('conversation_loading_indicator'),
        ),
      );
    }
    final error = provider.messageLoadErrorFor(widget.conversation.id);
    final messages = provider.messagesFor(widget.conversation.id);
    if (error != null && messages.isEmpty) {
      return _ConversationState(
        key: const Key('conversation_error_state'),
        icon: Icons.cloud_off_outlined,
        message: error,
        actionLabel: 'Try again',
        onAction: _retry,
      );
    }
    if (messages.isEmpty) {
      return const _ConversationState(
        key: Key('conversation_empty_state'),
        icon: Icons.waving_hand_outlined,
        message: 'No messages yet. Say hello and ask about the item.',
      );
    }
    final latestSentIndex = messages.lastIndexWhere(
      (message) => message.isMine,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _messageFocusNode.unfocus(),
      child: ListView.builder(
        key: const Key('conversation_message_list'),
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return _MessageBubble(
            message: message,
            isBuyer: widget.conversation.direction == ChatDirection.buying,
            showReadReceipt:
                index == latestSentIndex && message.status == 'read',
            onMeetupStatusChanged: () {
              final token = _currentAuthToken;
              if (token != null && token.isNotEmpty) {
                _chatProvider.loadMessages(
                  conversation: widget.conversation,
                  token: token,
                  shouldMarkRead: () => _isCurrentRoute,
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showReadReceipt,
    this.isBuyer = false,
    this.onMeetupStatusChanged,
  });

  final ChatMessageModel message;
  final bool showReadReceipt;
  final bool isBuyer;
  final VoidCallback? onMeetupStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (message.isMeetup && message.meetup != null) {
      return Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              MeetupCardBubble(
                key: Key('chat_meetup_card_${message.id}'),
                meetup: message.meetup!,
                isMine: message.isMine,
                isBuyer: isBuyer,
                createdAt: message.createdAt,
                onStatusChanged: onMeetupStatusChanged,
              ),
              if (showReadReceipt) _ReadReceipt(messageId: message.id),
            ],
          ),
        ),
      );
    }

    if (message.isLocation && message.location != null) {
      return Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              LocationBubble(
                key: Key('chat_location_${message.id}'),
                location: message.location!,
                isMine: message.isMine,
                createdAt: message.createdAt,
              ),
              if (showReadReceipt) _ReadReceipt(messageId: message.id),
            ],
          ),
        ),
      );
    }

    final mine = message.isMine;
    final semanticContent = message.isImage
        ? 'a photo'
        : message.isVoice
        ? 'a voice message'
        : message.text;
    return Semantics(
      excludeSemantics: !message.isVoice,
      label: mine
          ? 'You sent $semanticContent${showReadReceipt ? ', read' : ''}'
          : 'They sent $semanticContent',
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: Key('chat_message_${message.id}'),
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: mine
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.medium),
              topRight: const Radius.circular(AppRadius.medium),
              bottomLeft: Radius.circular(mine ? AppRadius.medium : 4),
              bottomRight: Radius.circular(mine ? 4 : AppRadius.medium),
            ),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Image.network(
                    _resolvedChatImageUrl(message.imageUrl!),
                    key: Key('chat_message_image_${message.id}'),
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) => SizedBox(
                      width: 220,
                      height: 120,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: mine
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else if (message.isVoice)
                _VoiceMessageBubble(
                  messageId: message.id,
                  audioUrl: _resolvedChatAssetUrl(message.audioUrl!),
                  durationMs: message.durationMs!,
                  mine: mine,
                )
              else
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mine
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _messageTime(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mine
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.78)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (showReadReceipt)
                Text(
                  'Read',
                  key: Key('chat_read_receipt_${message.id}'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Read',
      key: Key('chat_read_receipt_$messageId'),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _messageTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.enabled,
    required this.onAddPhoto,
    required this.onShareLocation,
    required this.onSend,
    required this.isRecording,
    required this.recordingSeconds,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool enabled;
  final VoidCallback onAddPhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onSend;
  final bool isRecording;
  final int recordingSeconds;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: isRecording
            ? _RecordingComposer(
                seconds: recordingSeconds,
                onCancel: onCancelRecording,
                onSend: onSendRecording,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_add_photo_button'),
                      tooltip: 'Add photo',
                      onPressed: enabled && !isSending ? onAddPhoto : null,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_share_location_button'),
                      tooltip: 'Share location',
                      onPressed: enabled && !isSending ? onShareLocation : null,
                      icon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      key: const Key('chat_message_input'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled && !isSending,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: enabled ? 'Message' : 'Conversation closed',
                        hintText: enabled ? 'Write a message' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      key: const Key('chat_record_voice_button'),
                      tooltip: 'Record voice message',
                      onPressed: enabled && !isSending
                          ? onStartRecording
                          : null,
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      key: const Key('chat_send_button'),
                      tooltip: 'Send message',
                      onPressed: enabled && !isSending ? onSend : null,
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RecordingComposer extends StatelessWidget {
  const _RecordingComposer({
    required this.seconds,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('chat_cancel_voice_button'),
          tooltip: 'Cancel recording',
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.mic_rounded, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Recording ${_voiceDuration(seconds * 1000)} / 1:00',
            key: const Key('chat_voice_recording_timer'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton.filled(
          key: const Key('chat_send_voice_button'),
          tooltip: 'Send voice message',
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.messageId,
    required this.audioUrl,
    required this.durationMs,
    required this.mine,
  });

  final String messageId;
  final String audioUrl;
  final int durationMs;
  final bool mine;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _isPlaying = false;
  bool _isLoading = false;

  Future<void> _toggle() async {
    if (_isLoading) return;
    final player = _player ??= AudioPlayer();
    _stateSubscription ??= player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    try {
      if (player.playing) {
        await player.pause();
      } else {
        if (player.audioSource == null) {
          setState(() => _isLoading = true);
          await player.setUrl(widget.audioUrl);
        } else if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('This voice message could not be played.'),
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.mine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('chat_voice_play_${widget.messageId}'),
          tooltip: _isPlaying ? 'Pause voice message' : 'Play voice message',
          color: foreground,
          onPressed: _toggle,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
        ),
        Icon(Icons.graphic_eq_rounded, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _voiceDuration(widget.durationMs),
          key: Key('chat_voice_duration_${widget.messageId}'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: foreground),
        ),
      ],
    );
  }
}

String _voiceDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000).ceil().clamp(0, 60);
  return '${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
}

enum _ChatPhotoSource { camera, gallery }

class _ChatPhotoSourceSheet extends StatelessWidget {
  const _ChatPhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a photo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('chat_take_photo_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Open your device camera'),
              onTap: () => Navigator.pop(context, _ChatPhotoSource.camera),
            ),
            ListTile(
              key: const Key('chat_choose_photo_option'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select an existing photo'),
              onTap: () => Navigator.pop(context, _ChatPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

String _photoContentType(XFile file) {
  final reported = file.mimeType?.trim().toLowerCase();
  if (reported != null && reported.startsWith('image/')) return reported;
  final extension = file.name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}

String _photoExtension(String contentType) => switch (contentType) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/heic' => 'heic',
  _ => 'jpg',
};

String _resolvedChatAssetUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme) return value;
  final path = value.startsWith('/') ? value : '/$value';
  return '${ApiConfig.baseUrl}$path';
}

String _resolvedChatImageUrl(String value) => _resolvedChatAssetUrl(value);

class _InlineChatError extends StatelessWidget {
  const _InlineChatError({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ConversationState extends StatelessWidget {
  const _ConversationState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
