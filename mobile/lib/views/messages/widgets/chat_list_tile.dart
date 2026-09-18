import 'package:flutter/material.dart';

enum ChatAvatarStyle { personWarm, personCool, item }

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.name,
    required this.itemTitle,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarStyle,
    required this.onTap,
  });

  final String name;
  final String itemTitle;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final ChatAvatarStyle avatarStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '$name, $itemTitle, $lastMessage',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 75),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 28, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChatAvatar(style: avatarStyle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF17221E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF909692),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFF065F46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  height: 1.15,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF515A56),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: const Key('chat_unread_badge'),
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF006B4F),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.style});

  final ChatAvatarStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Profile avatar',
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFEDE2D3),
          shape: BoxShape.circle,
        ),
        child: switch (style) {
          ChatAvatarStyle.personWarm => const _PersonAvatar(
            hairColor: Color(0xFF65402D),
            shirtColor: Color(0xFF1E2522),
          ),
          ChatAvatarStyle.personCool => const _PersonAvatar(
            hairColor: Color(0xFF49362B),
            shirtColor: Color(0xFF405A5F),
          ),
          ChatAvatarStyle.item => const _ItemAvatar(),
        },
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.hairColor, required this.shirtColor});

  final Color hairColor;
  final Color shirtColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 9,
          child: Container(
            width: 18,
            height: 19,
            decoration: const BoxDecoration(
              color: Color(0xFFD6A98B),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 6,
          child: Container(
            width: 25,
            height: 13,
            decoration: BoxDecoration(
              color: hairColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          bottom: 5,
          child: Container(
            width: 22,
            height: 17,
            decoration: BoxDecoration(
              color: shirtColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemAvatar extends StatelessWidget {
  const _ItemAvatar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF6D4C35),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 17,
            decoration: BoxDecoration(
              color: const Color(0xFF8A6B4E),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_ItemKnob(), _ItemKnob()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemKnob extends StatelessWidget {
  const _ItemKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: Color(0xFF3B2B21),
        shape: BoxShape.circle,
      ),
    );
  }
}
