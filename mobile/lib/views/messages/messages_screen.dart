import 'package:flutter/material.dart';

import 'widgets/chat_list_tile.dart';

enum ChatFilter {
  all('All'),
  unread('Unread'),
  buying('Buying'),
  selling('Selling');

  const ChatFilter(this.label);

  final String label;
}

enum ChatDirection { buying, selling }

class ChatPreview {
  const ChatPreview({
    required this.name,
    required this.itemTitle,
    required this.lastMessage,
    required this.time,
    required this.direction,
    required this.avatarStyle,
    this.unreadCount = 0,
  });

  final String name;
  final String itemTitle;
  final String lastMessage;
  final String time;
  final ChatDirection direction;
  final ChatAvatarStyle avatarStyle;
  final int unreadCount;
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.onComposePressed,
    this.onConversationPressed,
  });

  final VoidCallback? onComposePressed;
  final ValueChanged<ChatPreview>? onConversationPressed;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const _chatPreviews = <ChatPreview>[
    ChatPreview(
      name: 'Sophie M.',
      itemTitle: 'Ergonomic Office Chair',
      lastMessage: 'Hi! Is the chair still available?',
      time: '9:30 AM',
      unreadCount: 2,
      direction: ChatDirection.buying,
      avatarStyle: ChatAvatarStyle.personWarm,
    ),
    ChatPreview(
      name: 'James K.',
      itemTitle: 'Giant Escape Bike',
      lastMessage: 'Great, I can pick it up tomorrow.',
      time: 'Yesterday',
      direction: ChatDirection.buying,
      avatarStyle: ChatAvatarStyle.personCool,
    ),
    ChatPreview(
      name: 'Maya L.',
      itemTitle: 'Solid Wood Desk',
      lastMessage: 'Thanks! See you then.',
      time: 'Yesterday',
      direction: ChatDirection.selling,
      avatarStyle: ChatAvatarStyle.item,
    ),
    ChatPreview(
      name: 'Liam R.',
      itemTitle: 'Marshall Speaker',
      lastMessage: 'Could you do \$100?',
      time: 'Tue',
      direction: ChatDirection.selling,
      avatarStyle: ChatAvatarStyle.item,
    ),
    ChatPreview(
      name: 'Olivia T.',
      itemTitle: 'Table Lamp',
      lastMessage: 'Perfect, thank you!',
      time: 'Mon',
      direction: ChatDirection.buying,
      avatarStyle: ChatAvatarStyle.personWarm,
    ),
    ChatPreview(
      name: 'Noah W.',
      itemTitle: 'Bookcase',
      lastMessage: 'Is it okay if I pick it up this weekend?',
      time: 'Mon',
      direction: ChatDirection.selling,
      avatarStyle: ChatAvatarStyle.personCool,
    ),
    ChatPreview(
      name: 'Ava P.',
      itemTitle: 'Dining Table',
      lastMessage: 'Got it, thanks!',
      time: 'Sun',
      direction: ChatDirection.buying,
      avatarStyle: ChatAvatarStyle.personWarm,
    ),
  ];

  ChatFilter _selectedFilter = ChatFilter.all;

  List<ChatPreview> get _visibleChats {
    return switch (_selectedFilter) {
      ChatFilter.all => _chatPreviews,
      ChatFilter.unread =>
        _chatPreviews
            .where((chat) => chat.unreadCount > 0)
            .toList(growable: false),
      ChatFilter.buying =>
        _chatPreviews
            .where((chat) => chat.direction == ChatDirection.buying)
            .toList(growable: false),
      ChatFilter.selling =>
        _chatPreviews
            .where((chat) => chat.direction == ChatDirection.selling)
            .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final chats = _visibleChats;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatHeader(onComposePressed: widget.onComposePressed),
            _ChatFilters(
              selectedFilter: _selectedFilter,
              onSelected: (filter) {
                setState(() => _selectedFilter = filter);
              },
            ),
            Expanded(
              child: ListView.separated(
                key: const Key('chat_list'),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: chats.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 82,
                  endIndent: 28,
                  color: Color(0xFFE5E6E1),
                ),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ChatListTile(
                    key: Key('chat_conversation_${chat.name}'),
                    name: chat.name,
                    itemTitle: chat.itemTitle,
                    lastMessage: chat.lastMessage,
                    time: chat.time,
                    unreadCount: chat.unreadCount,
                    avatarStyle: chat.avatarStyle,
                    onTap: () => widget.onConversationPressed?.call(chat),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onComposePressed});

  final VoidCallback? onComposePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chat',
              key: const Key('chat_title'),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 22,
                color: Color(0xFF17221E),
              ),
            ),
          ),
          IconButton(
            key: const Key('chat_compose_button'),
            onPressed: onComposePressed ?? () {},
            tooltip: 'Start a new chat',
            icon: const Icon(Icons.open_in_new_rounded),
            color: const Color(0xFF006B4F),
            iconSize: 22,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (var index = 0; index < ChatFilter.values.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
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
      child: SizedBox(
        height: 44,
        child: Center(
          child: Material(
            color: isSelected
                ? const Color(0xFF006B4F)
                : const Color(0xFFEEEDE9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: Key('chat_filter_${filter.name}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                child: Text(
                  filter.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? Colors.white : const Color(0xFF565E5A),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
