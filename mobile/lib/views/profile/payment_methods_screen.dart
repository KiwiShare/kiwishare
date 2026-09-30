import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedCard> _cards = [];
  bool _loading = true;
  String? _error;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to manage your wallet.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await PaymentService.instance.listCards(token: token);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(String cardId) async {
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove card'),
        content: const Text('Are you sure you want to remove this saved card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = cardId);
    try {
      await PaymentService.instance.deleteCard(cardId: cardId, token: token);
      if (!mounted) return;
      setState(() {
        _cards.removeWhere((c) => c.id == cardId);
        _deletingId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card removed successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
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
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // ── Security note ─────────────────────────────────
                  _SecurityBanner(isDark: isDark, colors: colors),
                  const SizedBox(height: 24),

                  // ── Saved Cards ───────────────────────────────────
                  if (_cards.isEmpty) ...[
                    _EmptyState(colors: colors),
                  ] else ...[
                    Text(
                      'SAVED CARDS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._cards.map(
                      (card) => _CardTile(
                        key: ValueKey(card.id),
                        card: card,
                        isDeleting: _deletingId == card.id,
                        onDelete: () => _delete(card.id),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Info note ─────────────────────────────────────
                  _InfoNote(colors: colors, isDark: isDark),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security Banner
// ---------------------------------------------------------------------------

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({required this.isDark, required this.colors});
  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F3D26) : const Color(0xFFF0FDF4);
    final border = isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, color: colors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cards secured by Stripe',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'Your card details are encrypted and stored securely. KiwiShare never stores raw card numbers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Tile
// ---------------------------------------------------------------------------

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.card,
    required this.isDeleting,
    required this.onDelete,
  });

  final SavedCard card;
  final bool isDeleting;
  final VoidCallback onDelete;

  String get _brandLabel {
    switch (card.brand.toLowerCase()) {
      case 'visa':
        return 'Visa';
      case 'mastercard':
        return 'Mastercard';
      case 'amex':
        return 'American Express';
      case 'unionpay':
        return 'UnionPay';
      case 'jcb':
        return 'JCB';
      default:
        return card.brand.toUpperCase();
    }
  }

  Color get _brandColor {
    switch (card.brand.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
        return const Color(0xFF2E77BC);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Brand badge
          Container(
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: _brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _brandColor.withOpacity(0.25)),
            ),
            alignment: Alignment.center,
            child: Text(
              card.brand == 'mastercard'
                  ? 'MC'
                  : _brandLabel.substring(0, _brandLabel.length.clamp(0, 4)),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _brandColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_brandLabel •••• ${card.last4}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Expires ${card.expMonth.toString().padLeft(2, '0')} / ${card.expYear}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Delete button
          if (isDeleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              key: Key('delete_card_${card.id}'),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.error,
                size: 20,
              ),
              onPressed: onDelete,
              tooltip: 'Remove card',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card_outlined,
                size: 36,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved cards',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Cards saved during checkout will appear here\nfor faster future payments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info Note
// ---------------------------------------------------------------------------

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.colors, required this.isDark});
  final ColorScheme colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'About saved cards',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Cards are saved securely with Stripe and can be used for future purchases on KiwiShare.\n'
            '• Removing a card only removes it from your KiwiShare profile. It does not affect any existing payment methods on your bank or Stripe account.',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
