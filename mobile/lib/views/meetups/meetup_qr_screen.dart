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
import '../scanner/qr_scanner_screen.dart';

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
              color: isDark
                  ? const Color(0xFF064E3B).withOpacity(0.4)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF059669)
                    : const Color(0xFF10B981),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: isDark
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFF047857),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meetup.isConfirmed
                            ? 'Confirmed In-Person Meetup'
                            : 'Meetup Pending Confirmation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF047857),
                        ),
                      ),
                      Text(
                        'Order #${meetup.orderNumber}',
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

          // 4. Transaction QR Code Card
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
                        ? 'Meet the seller, inspect the item in person, and scan the seller\'s QR code to confirm handover.'
                        : 'Present this QR code to the buyer during in-person inspection to complete the handover.',
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
                            child: Icon(
                              Icons.help_outline_rounded,
                              size: 15,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Camera issue? Show this backup QR to the seller instead.',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Payment Gate / Confirmation
          _PaymentGateSection(
            meetup: meetup,
            orderId: widget.orderId,
            onPaymentSuccess: () {
              // Reload meetup details so the QR section updates
              _loadDetails();
            },
          ),
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

// ---------------------------------------------------------------------------
// Payment Gate Section
// Shows a "Pay to unlock QR" card for buyers with unpaid orders.
// Shows a "Payment confirmed" banner once paid.
// Sellers never need to pay so this section is hidden for them.
// ---------------------------------------------------------------------------

class _PaymentGateSection extends StatelessWidget {
  const _PaymentGateSection({
    required this.meetup,
    required this.orderId,
    required this.onPaymentSuccess,
  });

  final MeetupModel meetup;
  final String orderId;
  final VoidCallback onPaymentSuccess;

  @override
  Widget build(BuildContext context) {
    // Sellers don't pay — skip entirely
    if (!meetup.isBuying) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If qrToken exists on meetup, payment is confirmed
    final isPaid = meetup.qrToken != null && meetup.qrToken!.isNotEmpty;

    if (isPaid) {
      // Payment confirmed banner
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F3D26) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isDark
                ? const Color(0xFF166534)
                : const Color(0xFF86EFAC),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF059669),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment confirmed',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    'NZ\$${meetup.itemPriceNzd} · Your QR code is active above.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Unpaid — show pay to unlock card
    final order = context
        .read<OrderProvider>()
        .orders
        .where((o) => o.id == orderId)
        .firstOrNull;

    return Card(
      key: const Key('payment_gate_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF854D0E)
              : const Color(0xFFFDE68A),
          width: 1.2,
        ),
      ),
      color: isDark
          ? const Color(0xFF1C1308).withOpacity(0.6)
          : const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment required to unlock QR',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Complete your payment to unlock the handover QR code and confirm this meetup.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount due',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  'NZ\$${meetup.itemPriceNzd}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                key: const Key('pay_to_unlock_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                onPressed: order == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PaymentCheckoutScreen(
                              order: order,
                              onSuccess: onPaymentSuccess,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text(
                  'Pay & Unlock QR Code',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
