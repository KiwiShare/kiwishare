import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/kiwigold_coin_icon.dart';

enum TopUpPlanType { gold100, vipMonthly }

/// A modal sheet allowing users to top up KiwiGold or subscribe to VIP Membership.
class KiwiGoldTopUpSheet extends StatefulWidget {
  final TopUpPlanType initialPlan;

  const KiwiGoldTopUpSheet({
    super.key,
    this.initialPlan = TopUpPlanType.gold100,
  });

  static Future<bool?> show(
    BuildContext context, {
    TopUpPlanType initialPlan = TopUpPlanType.gold100,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => KiwiGoldTopUpSheet(initialPlan: initialPlan),
    );
  }

  @override
  State<KiwiGoldTopUpSheet> createState() => _KiwiGoldTopUpSheetState();
}

class _KiwiGoldTopUpSheetState extends State<KiwiGoldTopUpSheet> {
  late TopUpPlanType _selectedPlan;
  bool _isLoading = false;
  String? _errorMessage;
  bool _useSavedCard = true;
  List<SavedCard> _savedCards = [];
  String? _selectedCardId;

  // New card fields
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
    _loadCards();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null) return;

    try {
      final cards = await PaymentService.instance.listCards(token: token);
      if (mounted) {
        setState(() {
          _savedCards = cards;
          if (cards.isNotEmpty) {
            _selectedCardId = cards.first.id;
            _useSavedCard = true;
          } else {
            _useSavedCard = false;
          }
        });
      }
    } catch (_) {
      // Ignore card listing failure in mock/dev
    }
  }

  void _fillTestCard() {
    setState(() {
      _cardNumberController.text = '4242 4242 4242 4242';
      _expiryController.text = '12/28';
      _cvcController.text = '123';
      _useSavedCard = false;
    });
  }

  Future<void> _handlePayment() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null) {
      setState(() => _errorMessage = 'Please log in to continue.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final planKey = _selectedPlan == TopUpPlanType.gold100
        ? 'gold_100'
        : 'vip_monthly';

    try {
      // 1. Create top-up PaymentIntent
      final intentData = await PaymentService.instance.createTopUpIntent(
        plan: planKey,
        token: token,
      );

      final paymentIntentId = intentData['paymentIntentId']?.toString() ?? '';

      // 2. Tokenize card if using new card and not in mock mode
      String? paymentMethodId;
      if (_useSavedCard && _selectedCardId != null) {
        paymentMethodId = _selectedCardId;
      } else if (_cardNumberController.text.isNotEmpty) {
        final expParts = _expiryController.text.trim().split('/');
        final expMonth = expParts.isNotEmpty
            ? int.tryParse(expParts[0]) ?? 12
            : 12;
        final expYear = expParts.length > 1
            ? (int.tryParse(expParts[1]) ?? 28) +
                  (expParts[1].length == 2 ? 2000 : 0)
            : 2028;

        try {
          paymentMethodId = await PaymentService.instance.tokeniseCard(
            cardNumber: _cardNumberController.text,
            expMonth: expMonth,
            expYear: expYear,
            cvc: _cvcController.text.trim().isEmpty
                ? '123'
                : _cvcController.text.trim(),
            token: token,
          );
        } catch (_) {
          // If tokeniseCard fails in simulator/offline, proceed to server confirm which has fallback
        }
      }

      // 3. Confirm top-up on server
      final confirmRes = await PaymentService.instance.confirmTopUp(
        plan: planKey,
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethodId,
        token: token,
      );

      // 4. Update local user state
      final newGold = confirmRes['kiwiGold'] as int?;
      final isVip = confirmRes['isVip'] as bool?;
      final vipExpiresAt = confirmRes['vipExpiresAt'] != null
          ? DateTime.tryParse(confirmRes['vipExpiresAt'].toString())
          : null;

      final vipAutoRenew = confirmRes['vipAutoRenew'] as bool?;

      auth.applyTopUpResult(
        kiwiGold: newGold,
        isVip: isVip,
        vipExpiresAt: vipExpiresAt,
        vipAutoRenew: vipAutoRenew ?? (isVip == true ? true : null),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const KiwiGoldCoinIcon(size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmRes['message']?.toString() ??
                        'Purchase completed successfully!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final goldBalance = user?.kiwiGold ?? 0;
    final isVipActive = user?.isVip == true;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title Row
            Row(
              children: [
                const KiwiGoldCoinIcon(size: 26),
                const SizedBox(width: 10),
                const Text(
                  'KiwiGold & VIP Perks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Current Status Header Card
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Current Balance:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 6),
                  const KiwiGoldCoinIcon(size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$goldBalance KiwiGold',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const Spacer(),
                  if (isVipActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 13,
                            color: Color(0xFFFFDF73),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIP Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const Text(
              'Select a Boost Plan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),

            // Plan 1: 100 KiwiGold ($5.99 NZD)
            _buildPlanCard(
              type: TopUpPlanType.gold100,
              badgeIcon: Icons.toll_rounded,
              badgeText: 'Most Flexible',
              badgeColor: const Color(0xFFD97706),
              title: '100 KiwiGold Coins',
              priceText: '\$5.99 NZD',
              subPrice: 'One-time payment',
              features: [
                'Boost up to 20 listings (5 gold per boost)',
                'Permanent balance · Never expires',
                'Instantly bumps listings to top ranking',
              ],
              icon: const KiwiGoldCoinIcon(size: 28),
            ),
            const SizedBox(height: 10),

            // Plan 2: VIP Monthly Membership ($9.00 NZD/mo)
            _buildPlanCard(
              type: TopUpPlanType.vipMonthly,
              badgeIcon: Icons.auto_awesome,
              badgeText: 'Most Valuable',
              badgeColor: const Color(0xFF7C3AED),
              title: 'VIP Monthly Membership',
              priceText: '\$9.00 NZD / mo',
              subPrice: '30-day access · Auto-boost ready',
              features: [
                'Unlimited Listing Boosts (0 KiwiGold cost!)',
                'Exclusive VIP Golden Crown Badge',
                'Priority ranking in campus feed',
              ],
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFDF73).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFDF73),
                    size: 22,
                  ),
                ),
              ),
              isVipGradient: true,
            ),

            const SizedBox(height: 16),

            // Payment method selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Card',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                TextButton.icon(
                  onPressed: _fillTestCard,
                  icon: const Icon(
                    Icons.flash_on,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                  label: const Text(
                    'Use Test Card',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),

            if (_savedCards.isNotEmpty) ...[
              RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: _useSavedCard,
                onChanged: (val) => setState(() => _useSavedCard = true),
                title: Text(
                  'Saved card ending in ${_savedCards.first.last4} (${_savedCards.first.brand.toUpperCase()})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: false,
                groupValue: _useSavedCard,
                onChanged: (val) => setState(() => _useSavedCard = false),
                title: const Text(
                  'Use a different card',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],

            if (!_useSavedCard || _savedCards.isEmpty) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  hintText: '4242 4242 4242 4242',
                  prefixIcon: const Icon(Icons.credit_card_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'MM/YY',
                        hintText: '12/28',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _cvcController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'CVC',
                        hintText: '123',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Pay Button
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _selectedPlan == TopUpPlanType.vipMonthly
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFD97706),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handlePayment,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selectedPlan == TopUpPlanType.vipMonthly
                          ? 'Subscribe to VIP · \$9.00 NZD / mo'
                          : 'Get 100 KiwiGold · \$5.99 NZD',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required TopUpPlanType type,
    required String badgeText,
    required Color badgeColor,
    IconData? badgeIcon,
    required String title,
    required String priceText,
    required String subPrice,
    required List<String> features,
    required Widget icon,
    bool isVipGradient = false,
  }) {
    final isSelected = _selectedPlan == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isVipGradient
                    ? const Color(0xFFF5F3FF)
                    : const Color(0xFFFFFBEB))
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isVipGradient
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFF59E0B))
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        (isVipGradient ? const Color(0xFF8B5CF6) : Colors.amber)
                            .withOpacity(0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badgeIcon != null) ...[
                              Icon(badgeIcon, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isVipGradient
                            ? const Color(0xFF6D28D9)
                            : const Color(0xFFB45309),
                      ),
                    ),
                    Text(
                      subPrice,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: isVipGradient
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
