import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../theme/app_theme.dart';
import '../profile/notification_settings_screen.dart';
import 'widgets/chat_list_tile.dart';

export '../../models/chat_conversation_model.dart'
    show ChatConversationModel, ChatDirection;

typedef ChatPreview = ChatConversationModel;

enum ChatFilter {
  all('All'),
  unread('Unread'),
  buying('Buying'),
  selling('Selling');

  const ChatFilter(this.label);

  final String label;
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.onComposePressed,
    this.onConversationPressed,
    this.chatProvider,
    this.authToken,
  });

  final VoidCallback? onComposePressed;
  final ValueChanged<ChatConversationModel>? onConversationPressed;
  final ChatProvider? chatProvider;
  final String? authToken;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  ChatFilter _selectedFilter = ChatFilter.all;
  String? _loadedToken;
  String? _currentAuthToken;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text != _searchQuery) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chatProvider.loadConversations(token);
      });
    }
  }

  List<ChatConversationModel> _visibleChats(
    List<ChatConversationModel> conversations,
  ) {
    var filtered = switch (_selectedFilter) {
      ChatFilter.all => conversations,
      ChatFilter.unread =>
        conversations
            .where((chat) => chat.unreadCount > 0)
            .toList(growable: false),
      ChatFilter.buying =>
        conversations
            .where((chat) => chat.direction == ChatDirection.buying)
            .toList(growable: false),
      ChatFilter.selling =>
        conversations
            .where((chat) => chat.direction == ChatDirection.selling)
            .toList(growable: false),
    };

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((chat) {
            return chat.participantName.toLowerCase().contains(q) ||
                chat.itemTitle.toLowerCase().contains(q) ||
                chat.lastMessage.toLowerCase().contains(q);
          })
          .toList(growable: false);
    }

    return filtered;
  }

  Future<void> _refresh() async {
    final token = _currentAuthToken;
    if (token != null && token.isNotEmpty) {
      await _chatProvider.loadConversations(token);
    }
  }

  void _openConversation(ChatConversationModel conversation) {
    final callback = widget.onConversationPressed;
    if (callback != null) {
      callback(conversation);
      return;
    }
    context.push('/messages/${conversation.id}', extra: conversation);
  }

  Future<bool> _confirmRemoveConversation(
    ChatConversationModel conversation,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove chat?'),
            content: Text(
              'Remove your conversation with ${conversation.participantName} '
              'from this list? It will return if a new message arrives.',
            ),
            actions: [
              TextButton(
                key: const Key('chat_delete_cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('chat_delete_confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _removeConversation(
    ChatConversationModel conversation,
    String token,
  ) async {
    final removed = await _chatProvider.deleteConversation(
      conversation: conversation,
      token: token,
    );
    if (!removed && mounted) {
      final message =
          _chatProvider.conversationDeleteErrorFor(conversation.id) ??
          'Chat could not be removed. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openChatSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final pushEnabled =
                prefs.getBool('chat_push_notifications_enabled') ?? true;
            final soundEnabled = prefs.getBool('chat_sound_enabled') ?? true;

            return Material(
              color: isDark ? const Color(0xFF1B231E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chat Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        key: const Key('chat_push_notifications_switch'),
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text(
                          'Message Push Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Receive notifications when you receive new chat messages or offers',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: pushEnabled,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) async {
                          await prefs.setBool(
                            'chat_push_notifications_enabled',
                            val,
                          );
                          setSheetState(() {});
                          if (val && sheetContext.mounted) {
                            await offerContextualNotificationPermission(
                              sheetContext,
                            );
                          }
                        },
                      ),
                      SwitchListTile.adaptive(
                        key: const Key('chat_sound_switch'),
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: const Text(
                          'Message Sounds & Vibration',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Play alert sounds when receiving messages',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: soundEnabled,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) async {
                          await prefs.setBool('chat_sound_enabled', val);
                          setSheetState(() {});
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.tune_rounded),
                        title: const Text(
                          'Device System Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Manage OS permission and system banner alerts',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _chatProvider;
    final token = widget.authToken ?? context.watch<AuthProvider?>()?.jwtToken;
    _ensureLoaded(token);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatHeader(
              isSearching: _isSearching,
              searchController: _searchController,
              onComposePressed: widget.onComposePressed,
              onSearchPressed: () => setState(() => _isSearching = true),
              onCloseSearch: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              onClearSearch: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              onSettingsPressed: _openChatSettings,
            ),
            _ChatFilters(
              selectedFilter: _selectedFilter,
              onSelected: (filter) {
                setState(() => _selectedFilter = filter);
              },
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: provider,
                builder: (context, _) => _buildContent(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ChatProvider provider) {
    final token = _currentAuthToken;
    if (token == null || token.isEmpty) {
      return const _ChatMessageState(
        key: Key('chat_signed_out_state'),
        icon: Icons.lock_outline,
        title: 'Please sign in to view your chats',
        message: 'Your conversations will appear here after you sign in.',
      );
    }

    if (!provider.ownsSession(token)) {
      return const Center(
        child: CircularProgressIndicator(key: Key('chat_loading_indicator')),
      );
    }

    if (provider.isLoadingConversations && provider.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(key: Key('chat_loading_indicator')),
      );
    }

    if (provider.conversationError != null && provider.conversations.isEmpty) {
      return _ChatMessageState(
        key: const Key('chat_error_state'),
        icon: Icons.cloud_off_outlined,
        title: 'Chats could not be loaded',
        message: provider.conversationError!,
        actionLabel: 'Try again',
        onAction: _refresh,
      );
    }

    final chats = _visibleChats(provider.conversations);
    if (chats.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _ChatMessageState(
          key: const Key('chat_search_empty_state'),
          icon: Icons.search_off_rounded,
          title: 'No conversations found',
          message: 'No chats matching "$_searchQuery".',
          actionLabel: 'Clear search',
          onAction: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
        );
      }
      return _ChatMessageState(
        key: const Key('chat_empty_state'),
        icon: Icons.forum_outlined,
        title: _selectedFilter == ChatFilter.all
            ? 'No conversations yet'
            : 'No chats match this filter',
        message: _selectedFilter == ChatFilter.all
            ? 'Messages with buyers and sellers will appear here.'
            : 'Choose another filter to see more conversations.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        key: const Key('chat_list'),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: chats.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          indent: 82,
          endIndent: 28,
          color: Theme.of(context).dividerColor,
        ),
        itemBuilder: (context, index) {
          final chat = chats[index];
          return Dismissible(
            key: Key(
              'chat_dismissible_${chat.id}_'
              '${provider.conversationRenderVersionFor(chat.id)}',
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmRemoveConversation(chat),
            onDismissed: (_) {
              _removeConversation(chat, token);
            },
            background: Container(
              key: Key('chat_delete_background_${chat.id}'),
              alignment: Alignment.centerRight,
              color: Colors.transparent,
              child: Container(
                width: 104,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.32),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                      semanticLabel: 'Remove chat',
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Remove',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: ChatListTile(
              key: Key('chat_conversation_${chat.id}'),
              name: chat.participantName,
              itemTitle: chat.itemTitle,
              lastMessage: chat.lastMessage.isEmpty
                  ? 'No messages yet'
                  : chat.lastMessage,
              time: _conversationTime(chat.lastMessageAt),
              unreadCount: chat.unreadCount,
              avatarUrl: chat.participantAvatarUrl,
              avatarStyle: chat.direction == ChatDirection.buying
                  ? ChatAvatarStyle.personWarm
                  : ChatAvatarStyle.item,
              onTap: () => _openConversation(chat),
            ),
          );
        },
      ),
    );
  }
}

String _conversationTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
  if (difference == 1) return 'Yesterday';
  return '${local.day}/${local.month}';
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.isSearching,
    required this.searchController,
    required this.onComposePressed,
    required this.onSearchPressed,
    required this.onCloseSearch,
    required this.onClearSearch,
    required this.onSettingsPressed,
  });

  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback? onComposePressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onCloseSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  key: const Key('chat_search_field'),
                  controller: searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search chats, people, items...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: onClearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('chat_cancel_search_button'),
              onPressed: onCloseSearch,
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Chat',
              key: const Key('chat_title'),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            key: const Key('chat_search_button'),
            onPressed: onSearchPressed,
            tooltip: 'Search chats',
            icon: const Icon(Icons.search_rounded, size: 24),
            color: Theme.of(context).colorScheme.onSurface,
          ),
          if (onComposePressed != null)
            IconButton(
              key: const Key('chat_compose_button'),
              onPressed: onComposePressed,
              tooltip: 'Start a new chat',
              icon: const Icon(Icons.open_in_new_rounded, size: 24),
              color: Theme.of(context).colorScheme.primary,
            ),
          IconButton(
            key: const Key('chat_settings_button'),
            onPressed: onSettingsPressed,
            tooltip: 'Chat settings',
            icon: const Icon(Icons.settings_outlined, size: 24),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _ChatFilters extends StatelessWidget {
  const _ChatFilters({required this.selectedFilter, required this.onSelected});

  final ChatFilter selectedFilter;
  final ValueChanged<ChatFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (var index = 0; index < ChatFilter.values.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _ChatFilterChip(
              filter: ChatFilter.values[index],
              isSelected: ChatFilter.values[index] == selectedFilter,
              onTap: () => onSelected(ChatFilter.values[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatFilterChip extends StatelessWidget {
  const _ChatFilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final ChatFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? AppColors.brandPrimaryContainer
            : Theme.of(context).colorScheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected
                ? AppColors.brandPrimary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: InkWell(
          key: Key('chat_filter_${filter.name}'),
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageState extends StatelessWidget {
  const _ChatMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - (AppSpacing.xl * 2)).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
