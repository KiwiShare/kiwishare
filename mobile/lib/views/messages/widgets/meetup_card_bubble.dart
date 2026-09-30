import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_message_model.dart';
import '../../../models/meetup_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/meetup_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../theme/app_theme.dart';

import '../../../services/map_launcher_service.dart';
import '../../profile/payment_checkout_screen.dart';
import '../../scanner/qr_scanner_screen.dart';

class MeetupCardBubble extends StatefulWidget {
  const MeetupCardBubble({
    super.key,
    required this.meetup,
    required this.isMine,
    required this.createdAt,
    this.messageId,
    this.isBuyer,
    this.onViewQrCode,
    this.onStatusChanged,
    this.onBeforeAccept,
  });

  final ChatMeetupPayload meetup;
  final bool isMine;
  final DateTime createdAt;
  final String? messageId;
  final bool? isBuyer;
  final ValueChanged<String>? onViewQrCode;
  final VoidCallback? onStatusChanged;
  final Future<bool> Function()? onBeforeAccept;

  @override
  State<MeetupCardBubble> createState() => _MeetupCardBubbleState();
}

class _MeetupCardBubbleState extends State<MeetupCardBubble> {
  bool _isLoading = false;
  String? _error;
  String? _localStatus;

  String get _currentStatus => _localStatus ?? widget.meetup.proposalStatus;

  @override
  void didUpdateWidget(MeetupCardBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetup.proposalStatus != widget.meetup.proposalStatus) {
      _localStatus = null;
    }
  }

  Future<void> _acceptMeetup() async {
    if (widget.onBeforeAccept != null) {
      final canAccept = await widget.onBeforeAccept!();
      if (!canAccept) return;
    }

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
        messageId: widget.messageId,
        scheduledAt: widget.meetup.scheduledAt,
        locationName: widget.meetup.locationName,
      );
      if (mounted) {
        setState(() {
          _localStatus = 'confirmed';
        });
      }
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
      if (mounted) {
        setState(() {
          _localStatus = 'declined';
        });
      }
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

    final isConfirmed =
        _currentStatus == 'confirmed' || widget.meetup.isConfirmed;
    final isCancelled =
        _currentStatus == 'cancelled' ||
        _currentStatus == 'superseded' ||
        widget.meetup.isCancelled;
    final isDeclined =
        _currentStatus == 'declined' || widget.meetup.isDeclined || isCancelled;
    final isProposed = !isConfirmed && !isDeclined;

    final date = widget.meetup.scheduledAt.toLocal();
    final formattedDate =
        '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      key: Key('meetup_card_${widget.meetup.orderId}'),
      width: MediaQuery.sizeOf(context).width * 0.86,
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(vertical: 6),
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
                      : isCancelled
                      ? 'Meetup Cancelled'
                      : isDeclined
                      ? 'Meetup Declined'
                      : widget.isMine
                      ? 'Meetup Proposal Sent'
                      : 'Meetup Proposal',
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

                if (widget.meetup.latitude != null &&
                    widget.meetup.longitude != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      key: Key('meetup_map_${widget.meetup.orderId}'),
                      height: 148,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    widget.meetup.latitude!,
                                    widget.meetup.longitude!,
                                  ),
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: MarkerId(
                                      'meetup-${widget.meetup.orderId}',
                                    ),
                                    position: LatLng(
                                      widget.meetup.latitude!,
                                      widget.meetup.longitude!,
                                    ),
                                  ),
                                },
                                mapType: MapType.normal,
                                compassEnabled: false,
                                mapToolbarEnabled: false,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                liteModeEnabled: true,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: Key(
                                  'meetup_map_open_${widget.meetup.orderId}',
                                ),
                                onTap: () {
                                  MapLauncherService.instance
                                      .showNavigationSheet(
                                        context: context,
                                        locationName:
                                            widget.meetup.locationName,
                                        latitude: widget.meetup.latitude,
                                        longitude: widget.meetup.longitude,
                                      );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.navigation_rounded,
                                      size: 12,
                                      color: AppColors.brandPrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Open map',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Location with navigation launcher
                InkWell(
                  key: Key('meetup_location_nav_${widget.meetup.orderId}'),
                  onTap: () {
                    MapLauncherService.instance.showNavigationSheet(
                      context: context,
                      locationName: widget.meetup.locationName,
                      latitude: widget.meetup.latitude,
                      longitude: widget.meetup.longitude,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.meetup.locationName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.navigation_rounded,
                          size: 15,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                  ),
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

                const SizedBox(height: 10),

                // Agreed price display
                if (widget.meetup.agreedPriceNzd != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Agreed: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'NZ\$${widget.meetup.agreedPriceNzd}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                        if (widget.meetup.originalPriceNzd != null &&
                            widget.meetup.originalPriceNzd !=
                                widget.meetup.agreedPriceNzd) ...[
                          const SizedBox(width: 6),
                          Text(
                            'NZ\$${widget.meetup.originalPriceNzd}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Action area
                if (isConfirmed) ...[
                  Builder(
                    builder: (ctx) {
                      // Check if order is paid
                      OrderProvider? orderProvider;
                      try {
                        orderProvider = context.read<OrderProvider>();
                      } catch (_) {}
                      final order = orderProvider?.orders
                          .where((o) => o.id == widget.meetup.orderId)
                          .firstOrNull;
                      MeetupModel? cachedMeetup;
                      try {
                        cachedMeetup = context
                            .read<MeetupProvider>()
                            .meetupById(widget.meetup.orderId);
                      } catch (_) {}
                      final isPaid =
                          (order != null &&
                              (order.isPaid || order.isCompleted)) ||
                          (cachedMeetup != null && cachedMeetup.isPaid);
                      final buyerNeedsPay = widget.isBuyer == true && !isPaid;
                      final sellerNeedsWait = widget.isBuyer != true && !isPaid;

                      if (buyerNeedsPay) {
                        // Show Pay Now button for buyer
                        return SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton.icon(
                            key: Key(
                              'pay_now_meetup_btn_${widget.meetup.orderId}',
                            ),
                            onPressed: () {
                              if (order != null) {
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        PaymentCheckoutScreen(order: order),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please use Buy Now from chat to complete payment.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text(
                              'Pay to unlock QR',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        );
                      }

                      if (sellerNeedsWait) {
                        // Seller waiting for buyer payment
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A1C0B)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF854D0E)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Awaiting buyer payment to unlock handover QR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Both confirmed and paid — show Order Progress button
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: FilledButton.icon(
                              key: Key(
                                'view_qr_button_${widget.meetup.orderId}',
                              ),
                              onPressed: () {
                                context.push('/orders');
                              },
                              icon: const Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'View Order Progress',
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
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                if (widget.isBuyer == true) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const QrScannerScreen(),
                                    ),
                                  );
                                } else {
                                  _openQrScreen();
                                }
                              },
                              icon: Icon(
                                widget.isBuyer == true
                                    ? Icons.qr_code_scanner_rounded
                                    : Icons.verified_user_outlined,
                                size: 15,
                                color: colors.primary,
                              ),
                              label: Text(
                                widget.isBuyer == true
                                    ? 'Scan at handover'
                                    : 'Handover check-in',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else if (isCancelled) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This proposal was superseded or cancelled.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isProposed) ...[
                  if (widget.isMine) ...[
                    Container(
                      key: Key('meetup_proposal_sent_${widget.meetup.orderId}'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 17,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Proposal sent. The other person can accept or decline it.',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      key: Key(
                        'meetup_response_needed_${widget.meetup.orderId}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your response is needed',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _declineMeetup,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
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
                              padding: const EdgeInsets.symmetric(vertical: 9),
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
