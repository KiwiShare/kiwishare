import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.chatProvider,
    this.authToken,
  });

  final ChatConversationModel conversation;
  final ChatProvider? chatProvider;
  final String? authToken;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _loadedToken;
  String? _currentAuthToken;

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
    return Semantics(
      label: mine ? 'You said ${message.text}' : 'They said ${message.text}',
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
