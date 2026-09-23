import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/meetup_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meetup_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../profile/payment_checkout_screen.dart';
import '../profile/payment_methods_screen.dart';
import '../scanner/qr_scanner_screen.dart';
import '../shared/widgets/review_bottom_sheet.dart';
import '../../services/payment_service.dart';

class MeetupQrScreen extends StatefulWidget {
  const MeetupQrScreen({super.key, required this.orderId, this.initialMeetup});

  final String orderId;
  final MeetupModel? initialMeetup;

  @override
  State<MeetupQrScreen> createState() => _MeetupQrScreenState();
}

class _MeetupQrScreenState extends State<MeetupQrScreen> {
  MeetupModel? _meetup;
  bool _isLoading = false;
  String? _error;
  bool _isConfirmingHandover = false;

  @override
  void initState() {
    super.initState();
    _meetup = widget.initialMeetup;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;

    if (_meetup == null) {
      setState(() => _isLoading = true);
    }

    try {
      final provider = context.read<MeetupProvider>();
      final loaded = await provider.loadMeetupDetails(widget.orderId, token);
      if (mounted) {
        setState(() {
          _meetup = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDirectConfirmHandover({required bool isBuyer}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBuyer ? 'Confirm Receipt?' : 'Confirm Handover?'),
        content: Text(
          isBuyer
              ? 'Have you received and inspected the item in person? This will confirm receipt and complete the transaction.'
              : 'Have you handed over the item to the buyer in person? This will complete the transaction and release funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBuyer ? 'Confirm Receipt' : 'Confirm Handover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || token.isEmpty) return;

    setState(() => _isConfirmingHandover = true);

    try {
      final meetupProvider = context.read<MeetupProvider>();
      final result = await meetupProvider.confirmHandover(
        orderId: widget.orderId,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(
              result['message'] as String? ??
                  (isBuyer ? 'Receipt confirmed!' : 'Handover confirmed!'),
            ),
          ),
        );
        await _loadDetails();
        if (mounted && _meetup != null) {
          final isBuyerTarget = isBuyer;
          final targetUserId = isBuyerTarget
              ? _meetup!.sellerId
              : _meetup!.buyerId;
          final targetName = isBuyerTarget
              ? _meetup!.sellerName
              : _meetup!.buyerName;
          final targetAvatar = isBuyerTarget
              ? _meetup!.sellerAvatarUrl
              : _meetup!.buyerAvatarUrl;
          if (targetUserId.isNotEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              await ReviewBottomSheet.show(
                context,
                targetUserId: targetUserId,
                targetName: targetName,
                targetAvatarUrl: targetAvatar,
                orderId: widget.orderId,
                itemId: _meetup!.itemId,
                itemTitle: _meetup!.itemTitle,
                itemImageUrl: _meetup!.itemImageUrl,
                role: isBuyerTarget ? 'seller' : 'buyer',
              );
            }
          }
        }
        if (!isBuyer) {
          unawaited(
            _checkSellerPayoutNotice(
              token: token,
              priceNzd: _meetup?.itemPriceNzd ?? '',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to confirm: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingHandover = false);
      }
    }
  }

  Future<void> _checkSellerPayoutNotice({
    required String token,
    required String priceNzd,
  }) async {
    try {
      final cards = await PaymentService.instance.listCards(token: token);
      if (!mounted) return;
      if (cards.isNotEmpty) {
        final card = cards.first;
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text('Payout Scheduled'),
              ],
            ),
            content: Text(
              'Your earnings of NZ\$$priceNzd will be deposited into your saved card (•••• ${card.last4}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF2563EB),
                ),
                SizedBox(width: 8),
                Text('Bind Payout Card'),
              ],
            ),
            content: Text(
              'Sale completed! Please bind a payout card in your Wallet so your earnings of NZ\$$priceNzd can be transferred to you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  );
                },
                child: const Text('Go to Wallet'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Claim code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final meetup = _meetup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetup & QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && meetup == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && meetup == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colors.error),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadDetails,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : meetup == null
          ? const Center(child: Text('Meetup details unavailable.'))
          : _buildContent(context, meetup, colors, isDark),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MeetupModel meetup,
    ColorScheme colors,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final date = meetup.scheduledAt.toLocal();
    final formattedDate =
        '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)} ${date.year}';
    final formattedTime =
        '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

    final isCompleted = meetup.status == 'completed';
    final isConfirmed =
        meetup.isConfirmed ||
        meetup.proposalStatus == 'confirmed' ||
        meetup.proposalStatus == 'accepted';
    final isPaid =
        meetup.isPaid || (meetup.qrToken != null && meetup.qrToken!.isNotEmpty);

    final qrData = meetup.qrToken ?? 'QR_HANDOVER_TOKEN_${meetup.id}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Status & Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? (isDark
                        ? const Color(0xFF064E3B).withOpacity(0.4)
                        : const Color(0xFFECFDF5))
                  : (!isConfirmed || !isPaid)
                  ? (isDark ? const Color(0xFF2A1C0B) : const Color(0xFFFFFBEB))
                  : (isDark
                        ? const Color(0xFF064E3B).withOpacity(0.4)
                        : const Color(0xFFECFDF5)),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: isCompleted
                    ? (isDark
                          ? const Color(0xFF059669)
                          : const Color(0xFF10B981))
                    : (!isConfirmed || !isPaid)
                    ? (isDark
                          ? const Color(0xFF854D0E)
                          : const Color(0xFFFDE68A))
                    : (isDark
                          ? const Color(0xFF059669)
                          : const Color(0xFF10B981)),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : (!isConfirmed)
                      ? Icons.schedule_rounded
                      : (!isPaid)
                      ? Icons.lock_outline_rounded
                      : Icons.verified_outlined,
                  color: isCompleted
                      ? (isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF047857))
                      : (!isConfirmed || !isPaid)
                      ? (isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFB45309))
                      : (isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF047857)),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? 'Transaction Completed'
                            : (!isConfirmed)
                            ? 'Meetup Pending Confirmation'
                            : (!isPaid)
                            ? 'Location Confirmed · Payment Required'
                            : 'Ready for Handover · QR Code Unlocked',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? (isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF047857))
                              : (!isConfirmed || !isPaid)
                              ? (isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFB45309))
                              : (isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF047857)),
                        ),
                      ),
                      Text(
                        isCompleted
                            ? 'Order #${meetup.orderNumber} · Handover verified & complete'
                            : (!isConfirmed)
                            ? 'Order #${meetup.orderNumber} · Agree on location in chat'
                            : (!isPaid)
                            ? 'Order #${meetup.orderNumber} · Pay to unlock QR code'
                            : 'Order #${meetup.orderNumber} · Both parties confirmed & paid',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Item Summary Card
          Card(
            elevation: 0,
            color: colors.surfaceContainerHighest.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              side: BorderSide(color: colors.outline.withOpacity(0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: meetup.itemImageUrl.isNotEmpty
                        ? Image.network(
                            meetup.itemImageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 60,
                              height: 60,
                              color: colors.surfaceContainerHighest,
                              child: const Icon(Icons.inventory_2_outlined),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: colors.surfaceContainerHighest,
                            child: const Icon(Icons.inventory_2_outlined),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meetup.itemTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${meetup.itemPriceNzd} NZD',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Confirmed Meetup Details Card (Time & Location)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              side: BorderSide(color: colors.outline.withOpacity(0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmed Meetup Schedule',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date & Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.event,
                          color: colors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.place_outlined,
                          color: colors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meetup.locationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Auckland, New Zealand',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Counterparty
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: colors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meetup.counterpartyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              meetup.counterpartyRole,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Handover / QR Code State Machine Section
          if (isCompleted) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF059669)
                      : const Color(0xFF10B981),
                  width: 1.2,
                ),
              ),
              color: isDark
                  ? const Color(0xFF064E3B).withOpacity(0.3)
                  : const Color(0xFFECFDF5),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration_rounded,
                      size: 48,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Transaction Completed!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The item handover has been verified and ownership transferred. Both parties have been awarded 10 trust score points!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        key: const Key('leave_counterpart_review_button'),
                        onPressed: () {
                          final isBuyer = meetup.isBuying;
                          final targetUserId = isBuyer
                              ? meetup.sellerId
                              : meetup.buyerId;
                          final targetName = isBuyer
                              ? meetup.sellerName
                              : meetup.buyerName;
                          final targetAvatar = isBuyer
                              ? meetup.sellerAvatarUrl
                              : meetup.buyerAvatarUrl;
                          ReviewBottomSheet.show(
                            context,
                            targetUserId: targetUserId,
                            targetName: targetName,
                            targetAvatarUrl: targetAvatar,
                            orderId: widget.orderId,
                            itemId: meetup.itemId,
                            itemTitle: meetup.itemTitle,
                            itemImageUrl: meetup.itemImageUrl,
                            role: isBuyer ? 'seller' : 'buyer',
                          );
                        },
                        icon: const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: Colors.amber,
                        ),
                        label: Text(
                          'Rate & Review ${meetup.counterpartyName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!isConfirmed) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF854D0E)
                      : const Color(0xFFFDE68A),
                  width: 1.2,
                ),
              ),
              color: isDark ? const Color(0xFF2A1C0B) : const Color(0xFFFFFBEB),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 48,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Meetup Location Pending',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Both parties must agree on a meetup time and location before the handover QR code can be generated.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        key: const Key('schedule_meetup_from_qr_screen_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Schedule Meetup in Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!isPaid) ...[
            Card(
              key: const Key('payment_required_gate_card'),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF854D0E)
                      : const Color(0xFFFDE68A),
                  width: 1.2,
                ),
              ),
              color: isDark ? const Color(0xFF2A1C0B) : const Color(0xFFFFFBEB),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      meetup.isBuying
                          ? 'Payment Required to Unlock QR'
                          : 'Awaiting Buyer\'s Payment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meetup.isBuying
                          ? 'Meetup schedule is confirmed! Complete payment of NZ\$${meetup.itemPriceNzd} via KiwiShare Safe Pay to unlock the handover QR code.'
                          : 'Meetup schedule is confirmed. The handover verification QR code will appear here once the buyer completes payment.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF78350F),
                      ),
                    ),
                    if (meetup.isBuying) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          key: const Key('pay_to_unlock_qr_screen_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            final order = context
                                .read<OrderProvider>()
                                .orders
                                .where((o) => o.id == widget.orderId)
                                .firstOrNull;
                            if (order != null) {
                              final res = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute<bool>(
                                  builder: (_) =>
                                      PaymentCheckoutScreen(order: order),
                                ),
                              );
                              if (res == true) _loadDetails();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please open chat to proceed with checkout.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.payment_rounded, size: 20),
                          label: Text(
                            'Pay Now (NZ\$${meetup.itemPriceNzd})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // BOTH CONFIRMED AND PAID: Display QR Code and Direct Confirmation Buttons
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(color: colors.outline.withOpacity(0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Text(
                      meetup.isBuying
                          ? 'Handover Verification'
                          : 'Seller\'s Handover QR Code',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meetup.isBuying
                          ? 'Meet the seller, inspect the item in person, and scan the seller\'s QR code or tap Confirm Receipt below.'
                          : 'Present this QR code to the buyer during in-person inspection or tap Confirm Handover below.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (meetup.isBuying) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          key: const Key('buyer_scan_qr_button'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const QrScannerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Scan Seller\'s QR Code',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Backup verification code',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message:
                                'If your camera cannot scan the seller\'s QR code, show this backup QR or the 6-digit code below to the seller to verify handover.',
                            triggerMode: TooltipTriggerMode.tap,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.help_outline_rounded, size: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0D2538)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E4976)
                                : Colors.blue.shade200,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Camera issue? Show this backup QR to the seller instead.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // QR Code image
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        key: const Key('meetup_qr_image'),
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF064B3A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF064B3A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Token backup & Copy
                    InkWell(
                      onTap: () => _copyToken(qrData),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_outlined,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Copy verification token',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Direct Confirmation Buttons
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (meetup.isBuying)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          key: const Key('buyer_confirm_receipt_button'),
                          onPressed: _isConfirmingHandover
                              ? null
                              : () =>
                                    _handleDirectConfirmHandover(isBuyer: true),
                          icon: _isConfirmingHandover
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                ),
                          label: Text(
                            _isConfirmingHandover
                                ? 'Confirming...'
                                : 'Confirm Receipt',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          key: const Key('seller_confirm_handover_button'),
                          onPressed: _isConfirmingHandover
                              ? null
                              : () => _handleDirectConfirmHandover(
                                  isBuyer: false,
                                ),
                          icon: _isConfirmingHandover
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.handshake_rounded, size: 20),
                          label: Text(
                            _isConfirmingHandover
                                ? 'Confirming...'
                                : 'Confirm Handover',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _weekday(int day) => switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    _ => 'Sunday',
  };

  static String _month(int month) => switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
}
