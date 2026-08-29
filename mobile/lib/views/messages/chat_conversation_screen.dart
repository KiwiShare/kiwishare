import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/listing_image_picker.dart';
import '../../theme/app_theme.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.chatProvider,
    this.authToken,
    this.imagePicker,
  });

  final ChatConversationModel conversation;
  final ChatProvider? chatProvider;
  final String? authToken;
  final ListingImagePicker? imagePicker;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ListingImagePicker _imagePicker;
  String? _loadedToken;
  String? _currentAuthToken;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? DeviceListingImagePicker();
  }

  ChatProvider get _chatProvider =>
      widget.chatProvider ?? context.read<ChatProvider>();
  void _ensureLoaded(String? token) {
    _currentAuthToken = token;
    if (token == null || token.isEmpty) {
      _loadedToken = null;
      return;
    }
    if (token != _loadedToken) {
      _loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _chatProvider.loadMessages(
          conversation: widget.conversation,
          token: token,
        );
        _scrollToEnd();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
    await _chatProvider.loadMessages(
      conversation: widget.conversation,
      token: token,
    );
    _scrollToEnd();
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
    }
  }

  Future<void> _addPhoto() async {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) return;
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
      if (sent && mounted) _scrollToEnd();
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

  void _showPhotoPickerError(String message) {
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
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) => Column(
            children: [
              Expanded(child: _buildHistory(provider)),
              if (provider.messageSendErrorFor(widget.conversation.id) != null)
                _InlineChatError(
                  message: provider.messageSendErrorFor(
                    widget.conversation.id,
                  )!,
                ),
              _MessageComposer(
                controller: _messageController,
                isSending: provider.isSending(widget.conversation.id),
                enabled:
                    widget.conversation.isActive &&
                    (_currentAuthToken?.isNotEmpty ?? false),
                onAddPhoto: _addPhoto,
                onSend: _send,
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
    return ListView.builder(
      key: const Key('conversation_message_list'),
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final semanticContent = message.isImage ? 'a photo' : message.text;
    return Semantics(
      label: mine ? 'You sent $semanticContent' : 'They sent $semanticContent',
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Image.network(
                    message.imageUrl!,
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
            ],
          ),
        ),
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
    required this.isSending,
    required this.enabled,
    required this.onAddPhoto,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool enabled;
  final VoidCallback onAddPhoto;
  final VoidCallback onSend;

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
        child: Row(
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
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                key: const Key('chat_message_input'),
                controller: controller,
                enabled: enabled && !isSending,
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

class _InlineChatError extends StatelessWidget {
  const _InlineChatError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('conversation_inline_error'),
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
