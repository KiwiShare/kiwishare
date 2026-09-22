import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../profile/my_reports_screen.dart';

class SupportChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? links;

  const SupportChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.links,
  });
}

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<SupportChatMessage> _messages = [];
  bool _isSending = false;

  static const List<String> _quickPrompts = [
    'How it works',
    'Report an issue',
    'Payment & Escrow',
    'Meetup & QR Code',
    'Contact Email',
  ];

  @override
  void initState() {
    super.initState();
    _initWelcomeMessages();
  }

  void _initWelcomeMessages() {
    final now = DateTime.now();
    _messages.addAll([
      SupportChatMessage(
        id: 'welcome-1',
        text:
            '👋 Kia Ora! Welcome to KiwiShare Customer Care.\n\nI am your automated KiwiShare Assistant. How can I help you today?',
        isUser: false,
        timestamp: now,
      ),
      SupportChatMessage(
        id: 'welcome-qa',
        text:
            '💡 **HOW IT WORKS:**\n'
            '1. **Browse & Watchlist**: Discover pre-loved treasures in your neighborhood across NZ.\n'
            '2. **Chat & Agree**: Negotiate fairly through in-app chat.\n'
            '3. **Escrow Protection**: Buyer deposits payment safely into KiwiShare Escrow.\n'
            '4. **Meetup & QR Scan**: Meet in a public spot, inspect the item, scan QR, and confirm receipt.\n'
            '5. **Instant Payout**: Once confirmed by both parties, payment is transferred to the seller!',
        isUser: false,
        timestamp: now.add(const Duration(milliseconds: 100)),
      ),
      SupportChatMessage(
        id: 'welcome-contact-report',
        text:
            '🛡️ **SAFETY & REPORTING:**\n'
            'Your safety is our priority. If you encounter suspicious listings, harassment, or fraudulent users, tap "Report" on their listing or profile.\n\n'
            '✉️ **CONTACT US:**\n'
            'Need dedicated human assistance? Reach our NZ support team anytime at:\n'
            '**customer@kiwishare.online**',
        isUser: false,
        timestamp: now.add(const Duration(milliseconds: 200)),
        links: ['customer@kiwishare.online'],
      ),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String userText) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty || _isSending) return;

    _controller.clear();
    final userMsg = SupportChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/support/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': trimmed}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final replyText = data['reply'] as String? ??
            'Thank you for reaching out. Please contact customer@kiwishare.online for direct assistance.';
        final links = (data['helpfulLinks'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        if (mounted) {
          setState(() {
            _messages.add(
              SupportChatMessage(
                id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                text: replyText,
                isUser: false,
                timestamp: DateTime.now(),
                links: links,
              ),
            );
          });
        }
      } else {
        _fallbackResponse(trimmed);
      }
    } catch (_) {
      _fallbackResponse(trimmed);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _fallbackResponse(String prompt) {
    final lower = prompt.toLowerCase();
    String fallbackReply;
    if (lower.contains('contact') || lower.contains('email')) {
      fallbackReply =
          'You can contact our customer support team directly at **customer@kiwishare.online**. We typically respond within 24 hours.';
    } else if (lower.contains('report')) {
      fallbackReply =
          'To report a user or listing, open the listing/profile page and tap the shield/flag icon. Our moderation team reviews every report within 12 hours.';
    } else if (lower.contains('how') || lower.contains('work')) {
      fallbackReply =
          'KiwiShare works through safe local meetups: 1) Browse items, 2) Agree in chat, 3) Pay securely via Escrow, 4) Meet up & scan QR code, 5) Both confirm receipt to release funds!';
    } else if (lower.contains('pay') || lower.contains('card') || lower.contains('wallet')) {
      fallbackReply =
          'Payments are held safely in escrow until meetup completion. Add debit cards or payout bank cards in your Profile > Wallet.';
    } else {
      fallbackReply =
          'Thanks for your question! For detailed assistance, please contact us anytime at **customer@kiwishare.online**.';
    }

    if (mounted) {
      setState(() {
        _messages.add(
          SupportChatMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            text: fallbackReply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent_rounded, color: colors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KiwiShare Support',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Automated Bot • 24/7',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Reports',
            icon: Icon(Icons.shield_outlined, color: colors.onSurface, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyReportsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, colors, isDark);
              },
            ),
          ),
          if (_isSending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'KiwiShare Assistant is typing...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          _buildQuickSuggestions(colors, isDark),
          _buildInputBar(colors, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(ColorScheme colors, bool isDark) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            backgroundColor: isDark
                ? colors.primary.withValues(alpha: 0.18)
                : colors.primary.withValues(alpha: 0.08),
            side: BorderSide(
              color: colors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _sendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
    SupportChatMessage message,
    ColorScheme colors,
    bool isDark,
  ) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_rounded, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colors.primary
                    : (isDark ? colors.surfaceContainerHigh : const Color(0xFFF3F6F4)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark ? colors.outline.withValues(alpha: 0.2) : const Color(0xFFE2ECE7),
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MarkdownMessageText(
                    text: message.text,
                    isUser: isUser,
                    colors: colors,
                  ),
                  if (message.links != null && message.links!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: message.links!.map((link) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final uri = link.contains('@')
                                ? Uri.parse('mailto:$link')
                                : Uri.parse(link.startsWith('http') ? link : 'https://$link');
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {
                              // Ignore launch error
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (link.contains('@')) ...[
                                  Icon(Icons.email_outlined, size: 14, color: colors.primary),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  link,
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colors, bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? colors.outline.withValues(alpha: 0.2) : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceContainerHigh : const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ask about KiwiShare, reports, contact...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _sendMessage(_controller.text),
              icon: Icon(Icons.send_rounded, color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownMessageText extends StatelessWidget {
  final String text;
  final bool isUser;
  final ColorScheme colors;

  const _MarkdownMessageText({
    required this.text,
    required this.isUser,
    required this.colors,
  });

  static final _inlinePattern = RegExp(
    r'(\[([^\]]+)\]\(([^)]+)\))|'
    r'(\*\*(.+?)\*\*)|'
    r'(__([^_]+)__)|'
    r'(?<!\*)\*([^*]+)\*(?!\*)|'
    r'(`([^`]+)`)|'
    r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
  );

  List<InlineSpan> _parseInline(
    String line,
    TextStyle baseStyle,
    Color boldColor,
    Color linkColor,
  ) {
    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in _inlinePattern.allMatches(line)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(2) != null) {
        // [link text](url)
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ));
      } else if (match.group(5) != null) {
        // **bold**
        final content = match.group(5)!;
        final isEmail = RegExp(
          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(content);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: isEmail ? linkColor : boldColor,
            decoration: isEmail ? TextDecoration.underline : null,
          ),
        ));
      } else if (match.group(7) != null) {
        // __bold__
        spans.add(TextSpan(
          text: match.group(7),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: boldColor,
          ),
        ));
      } else if (match.group(8) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(8),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(10) != null) {
        // `code`
        spans.add(TextSpan(
          text: match.group(10),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (match.group(11) != null) {
        // email
        spans.add(TextSpan(
          text: match.group(11),
          style: baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser ? Colors.white : colors.onSurface;
    final isDark = colors.brightness == Brightness.dark;
    final boldColor = isUser ? Colors.white : (isDark ? Colors.white : const Color(0xFF111827));
    final linkColor = isUser ? Colors.white : colors.primary;
    final baseStyle = TextStyle(
      color: baseColor,
      fontSize: 14,
      height: 1.45,
    );

    final lines = text.split('\n');
    final allSpans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) {
        allSpans.add(const TextSpan(text: '\n'));
      }

      final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!;
        final headerSize = level <= 2 ? 16.0 : 15.0;
        final headerSpans = _parseInline(
          content,
          baseStyle.copyWith(
            fontSize: headerSize,
            fontWeight: FontWeight.bold,
            color: boldColor,
          ),
          boldColor,
          linkColor,
        );
        allSpans.addAll(headerSpans);
        continue;
      }

      allSpans.addAll(_parseInline(line, baseStyle, boldColor, linkColor));
    }

    return Text.rich(
      TextSpan(children: allSpans, style: baseStyle),
    );
  }
}
