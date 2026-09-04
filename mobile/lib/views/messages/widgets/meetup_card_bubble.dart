import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_message_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/meetup_provider.dart';
import '../../../theme/app_theme.dart';

class MeetupCardBubble extends StatefulWidget {
  const MeetupCardBubble({
    super.key,
    required this.meetup,
    required this.isMine,
    required this.createdAt,
    this.onViewQrCode,
    this.onStatusChanged,
  });

  final ChatMeetupPayload meetup;
  final bool isMine;
  final DateTime createdAt;
  final ValueChanged<String>? onViewQrCode;
  final VoidCallback? onStatusChanged;

  @override
  State<MeetupCardBubble> createState() => _MeetupCardBubbleState();
}

class _MeetupCardBubbleState extends State<MeetupCardBubble> {
  bool _isLoading = false;
  String? _error;

  Future<void> _acceptMeetup() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meetupProvider = context.read<MeetupProvider>();
      await meetupProvider.acceptMeetup(
        orderId: widget.meetup.orderId,
        token: token,
      );
      widget.onStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _declineMeetup() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meetupProvider = context.read<MeetupProvider>();
      await meetupProvider.declineMeetup(
        orderId: widget.meetup.orderId,
        token: token,
      );
      widget.onStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openQrScreen() {
    if (widget.onViewQrCode != null) {
      widget.onViewQrCode!(widget.meetup.orderId);
    } else {
      context.push('/meetups/${widget.meetup.orderId}/qr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isConfirmed = widget.meetup.isConfirmed;
    final isProposed = widget.meetup.isProposed;
    final isDeclined = widget.meetup.isDeclined || widget.meetup.isCancelled;

    final date = widget.meetup.scheduledAt.toLocal();
    final formattedDate =
        '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      key: Key('meetup_card_${widget.meetup.orderId}'),
      constraints: const BoxConstraints(maxWidth: 290),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed
            ? (isDark
                  ? const Color(0xFF064E3B).withOpacity(0.35)
                  : const Color(0xFFECFDF5))
            : colors.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: isConfirmed
              ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
              : colors.outline.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? (isDark
                        ? const Color(0xFF059669).withOpacity(0.3)
                        : const Color(0xFFD1FAE5))
                  : colors.primaryContainer.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.medium - 1),
                topRight: Radius.circular(AppRadius.medium - 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConfirmed
                      ? Icons.check_circle_outline
                      : isDeclined
                      ? Icons.cancel_outlined
                      : Icons.handshake_outlined,
                  size: 16,
                  color: isConfirmed
                      ? (isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF047857))
                      : colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  isConfirmed
                      ? 'Meetup Confirmed'
                      : isDeclined
                      ? 'Meetup Declined'
                      : 'Meetup Proposed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isConfirmed
                        ? (isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF047857))
                        : colors.primary,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.meetup.locationName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),

                if (widget.meetup.note != null &&
                    widget.meetup.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Note: ${widget.meetup.note}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.error, fontSize: 11),
                  ),
                ],

                const SizedBox(height: 12),

                // Action area
                if (isConfirmed) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      key: Key('view_qr_button_${widget.meetup.orderId}'),
                      onPressed: _openQrScreen,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text(
                        'View Meetup QR Code',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else if (isProposed) ...[
                  if (widget.isMine) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for response...',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _declineMeetup,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            key: Key(
                              'accept_meetup_button_${widget.meetup.orderId}',
                            ),
                            onPressed: _isLoading ? null : _acceptMeetup,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
