import 'package:flutter/material.dart';

import '../../models/report_draft.dart';
import '../../theme/app_theme.dart';
import '../profile/report_screen.dart';

enum _ConversationAction { reportUser }

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.participantName,
    required this.chatId,
    required this.reportedUserId,
    required this.tradeId,
    required this.itemTitle,
  });

  final String participantName;
  final String chatId;
  final String reportedUserId;
  final String tradeId;
  final String itemTitle;

  void _openReport(BuildContext context, ReportContext reportContext) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(reportContext: reportContext),
      ),
    );
  }

  void _reportUser(BuildContext context) => _openReport(
    context,
    ReportContext(
      targetType: ReportTargetType.user,
      targetId: reportedUserId,
      targetLabel: participantName,
      contextType: ReportContextType.chat,
      contextId: chatId,
      contextLabel: 'Conversation about $itemTitle',
    ),
  );

  void _reportTrade(BuildContext context) => _openReport(
    context,
    ReportContext(
      targetType: ReportTargetType.user,
      targetId: reportedUserId,
      targetLabel: participantName,
      contextType: ReportContextType.transaction,
      contextId: tradeId,
      contextLabel: 'Trade for $itemTitle',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              child: Text(
                participantName.characters.first.toUpperCase(),
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(participantName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ConversationAction>(
            tooltip: 'Conversation options',
            onSelected: (_) => _reportUser(context),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ConversationAction.reportUser,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.report_outlined),
                  title: Text('Report user'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TradeContextCard(
              itemTitle: itemTitle,
              onReport: () => _reportTrade(context),
            ),
            const Expanded(child: _ConversationMessages()),
            const _MessageComposer(),
          ],
        ),
      ),
    );
  }
}

class _TradeContextCard extends StatelessWidget {
  const _TradeContextCard({required this.itemTitle, required this.onReport});

  final String itemTitle;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined, color: colors.onPrimaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Trade in progress',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('report_trade_button'),
            onPressed: onReport,
            icon: const Icon(Icons.report_outlined, size: 20),
            label: const Text('Report'),
            style: TextButton.styleFrom(
              foregroundColor: colors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationMessages extends StatelessWidget {
  const _ConversationMessages();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: const [
      _MessageBubble(
        text: 'Kia ora! Is this still available?',
        isCurrentUser: false,
      ),
      _MessageBubble(
        text: 'Yes, it is. Would the campus library entrance suit for pickup?',
        isCurrentUser: true,
      ),
      _MessageBubble(
        text: 'That works for me. I can meet there tomorrow at noon.',
        isCurrentUser: false,
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isCurrentUser});

  final String text;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? colors.primaryContainer
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Text(text),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
    ),
    child: Row(
      children: [
        const Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Message',
              prefixIcon: Icon(Icons.add_circle_outline),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          onPressed: () {},
          tooltip: 'Send message',
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    ),
  );
}
