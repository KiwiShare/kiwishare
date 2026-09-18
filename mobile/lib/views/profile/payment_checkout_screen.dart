import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/payment_service.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({super.key, required this.order, this.onSuccess});

  final OrderModel order;
  final VoidCallback? onSuccess;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen>
    with TickerProviderStateMixin {
  // Page controller for 2-step flow: 1=summary, 2=card entry
  final _pageController = PageController();
  int _page = 0;

  // Intent data from server
  PaymentIntentResult? _intent;
  bool _intentLoading = false;
  String? _intentError;

  // Card form
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saveCard = true;

  // Saved cards
  List<SavedCard> _savedCards = [];
  String? _selectedCardId; // null = new card

  // Payment state
  bool _paying = false;
  String? _payError;

  // Animation
  late final AnimationController _checkAnim;

  // Card brand detection
  String get _detectedBrand {
    final n = _cardNumberCtrl.text.replaceAll(' ', '');
    if (n.startsWith('4')) return 'visa';
    if (n.startsWith('5') || n.startsWith('2')) return 'mastercard';
    if (n.startsWith('3')) return 'amex';
    return 'unknown';
  }

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    _nameCtrl.dispose();
    _checkAnim.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadIntent(), _loadSavedCards()]);
  }

  Future<void> _loadIntent() async {
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) return;
    setState(() {
      _intentLoading = true;
      _intentError = null;
    });
    try {
      final intent = await PaymentService.instance.createIntent(
        orderId: widget.order.id,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _intentLoading = false;
      });
      // Free order – auto-success
      if (intent.isFree) {
        _onPaymentSuccess();
      }
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _intentError = e.message;
        _intentLoading = false;
      });
    }
  }

  Future<void> _loadSavedCards() async {
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) return;
    try {
      final cards = await PaymentService.instance.listCards(token: token);
      if (!mounted) return;
      setState(() {
        _savedCards = cards;
        if (cards.isNotEmpty) {
          _selectedCardId = cards.first.id;
        }
      });
    } catch (_) {}
  }

  // ── PAYMENT LOGIC ─────────────────────────────────────────────────────────

  Future<void> _pay() async {
    if (_intent == null) return;
    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) return;

    if (_selectedCardId == null &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _paying = true;
      _payError = null;
    });

    try {
      String paymentMethodId;

      if (_selectedCardId != null) {
        // Use saved card ID directly as the PM id
        paymentMethodId = _selectedCardId!;
      } else {
        // Tokenise new card via Stripe
        final expiry = _expiryCtrl.text.replaceAll(' ', '');
        final parts = expiry.split('/');
        final month = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
        int year = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
        if (year < 100) year += 2000;

        paymentMethodId = await PaymentService.instance.tokeniseCard(
          cardNumber: _cardNumberCtrl.text,
          expMonth: month,
          expYear: year,
          cvc: _cvcCtrl.text,
          token: token,
        );

        // Optionally save card to profile
        if (_saveCard) {
          try {
            await PaymentService.instance.saveCard(
              paymentMethodId: paymentMethodId,
              token: token,
            );
          } catch (_) {
            // Non-critical
          }
        }
      }

      await PaymentService.instance.confirmPayment(
        orderId: widget.order.id,
        paymentIntentId: _intent!.paymentIntentId,
        paymentMethodId: paymentMethodId,
        token: token,
      );

      if (!mounted) return;
      setState(() => _paying = false);
      _onPaymentSuccess();
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _payError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _payError = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  void _onPaymentSuccess() {
    // Refresh orders
    final token = context.read<AuthProvider>().jwtToken;
    if (token != null) {
      context.read<OrderProvider>().loadMyOrders(token);
    }
    _checkAnim.forward();
    _showSuccessSheet();
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        orderNumber: widget.order.orderNumber,
        totalNzd: _intent == null
            ? widget.order.item.priceNzd
            : (_intent!.amountCents / 100).toStringAsFixed(2),
        onDone: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context, true); // close checkout with success result
          widget.onSuccess?.call();
        },
      ),
    );
  }

  // ── NAVIGATION ────────────────────────────────────────────────────────────

  void _nextPage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    setState(() => _page = 1);
  }

  void _prevPage() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    setState(() => _page = 0);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _StepProgressBar(step: _page, total: 2),
        ),
      ),
      body: _intentLoading
          ? const Center(child: CircularProgressIndicator())
          : _intentError != null
          ? _ErrorView(message: _intentError!, onRetry: _loadIntent)
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SummaryPage(
                  order: widget.order,
                  intent: _intent,
                  onNext: _nextPage,
                ),
                _CardEntryPage(
                  intent: _intent,
                  savedCards: _savedCards,
                  selectedCardId: _selectedCardId,
                  onCardSelected: (id) => setState(() => _selectedCardId = id),
                  cardNumberCtrl: _cardNumberCtrl,
                  expiryCtrl: _expiryCtrl,
                  cvcCtrl: _cvcCtrl,
                  nameCtrl: _nameCtrl,
                  formKey: _formKey,
                  saveCard: _saveCard,
                  onSaveCardChanged: (v) => setState(() => _saveCard = v),
                  brand: _detectedBrand,
                  onCardNumberChanged: () => setState(() {}),
                  paying: _paying,
                  error: _payError,
                  onBack: _prevPage,
                  onPay: _pay,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step Progress Bar
// ---------------------------------------------------------------------------

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            color: i <= step
                ? colors.primary
                : colors.outline.withOpacity(0.25),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 – Order Summary
// ---------------------------------------------------------------------------

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.order,
    required this.intent,
    required this.onNext,
  });

  final OrderModel order;
  final PaymentIntentResult? intent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final itemCents = intent?.itemAmountCents ?? 0;
    final feeCents = intent?.buyerFeeCents ?? 0;
    final totalCents = intent?.amountCents ?? 0;

    String centsToNzd(int c) => (c / 100).toStringAsFixed(2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Merchant banner ────────────────────────────────────────────
          _SectionLabel(label: 'Paying to'),
          const SizedBox(height: 10),
          _MerchantBanner(isDark: isDark, colors: colors),
          const SizedBox(height: 24),

          // ── Item ───────────────────────────────────────────────────────
          _SectionLabel(label: 'Item'),
          const SizedBox(height: 10),
          _ItemCard(order: order, isDark: isDark, colors: colors),
          const SizedBox(height: 24),

          // ── Breakdown ──────────────────────────────────────────────────
          _SectionLabel(label: 'Payment breakdown'),
          const SizedBox(height: 10),
          _BreakdownCard(
            isDark: isDark,
            colors: colors,
            rows: [
              ('Item price', 'NZ\$${centsToNzd(itemCents)}', false),
              (
                'Platform fee (incl. 15% NZ GST)',
                'NZ\$${centsToNzd(feeCents)}',
                false,
              ),
              ('Total', 'NZ\$${centsToNzd(totalCents)}', true),
            ],
          ),
          const SizedBox(height: 12),
          _SecureNote(),
          const SizedBox(height: 32),

          // ── CTA ────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const Key('proceed_to_payment_btn'),
              onPressed: onNext,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(
                'Continue to Payment   NZ\$${centsToNzd(totalCents)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 – Card Entry
// ---------------------------------------------------------------------------

class _CardEntryPage extends StatelessWidget {
  const _CardEntryPage({
    required this.intent,
    required this.savedCards,
    required this.selectedCardId,
    required this.onCardSelected,
    required this.cardNumberCtrl,
    required this.expiryCtrl,
    required this.cvcCtrl,
    required this.nameCtrl,
    required this.formKey,
    required this.saveCard,
    required this.onSaveCardChanged,
    required this.brand,
    required this.onCardNumberChanged,
    required this.paying,
    required this.error,
    required this.onBack,
    required this.onPay,
  });

  final PaymentIntentResult? intent;
  final List<SavedCard> savedCards;
  final String? selectedCardId;
  final ValueChanged<String?> onCardSelected;
  final TextEditingController cardNumberCtrl;
  final TextEditingController expiryCtrl;
  final TextEditingController cvcCtrl;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState> formKey;
  final bool saveCard;
  final ValueChanged<bool> onSaveCardChanged;
  final String brand;
  final VoidCallback onCardNumberChanged;
  final bool paying;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final totalCents = intent?.amountCents ?? 0;
    final totalNzd = (totalCents / 100).toStringAsFixed(2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accepted providers ─────────────────────────────────────────
          _SectionLabel(label: 'Accepted payment methods'),
          const SizedBox(height: 10),
          _AcceptedProviders(),
          const SizedBox(height: 24),

          // ── Saved cards ────────────────────────────────────────────────
          if (savedCards.isNotEmpty) ...[
            _SectionLabel(label: 'Saved cards'),
            const SizedBox(height: 10),
            ...savedCards.map(
              (card) => _SavedCardTile(
                card: card,
                selected: selectedCardId == card.id,
                onTap: () => onCardSelected(card.id),
              ),
            ),
            _SavedCardTile.newCard(
              selected: selectedCardId == null,
              onTap: () => onCardSelected(null),
            ),
            const SizedBox(height: 24),
          ],

          // ── New card form ──────────────────────────────────────────────
          if (savedCards.isEmpty || selectedCardId == null) ...[
            _SectionLabel(label: 'Card details'),
            const SizedBox(height: 10),
            _CardForm(
              isDark: isDark,
              colors: colors,
              cardNumberCtrl: cardNumberCtrl,
              expiryCtrl: expiryCtrl,
              cvcCtrl: cvcCtrl,
              nameCtrl: nameCtrl,
              formKey: formKey,
              brand: brand,
              onCardNumberChanged: onCardNumberChanged,
              saveCard: saveCard,
              onSaveCardChanged: onSaveCardChanged,
            ),
            const SizedBox(height: 20),
          ],

          // ── Error ──────────────────────────────────────────────────────
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _SecureNote(),
          const SizedBox(height: 28),

          // ── Pay button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('confirm_payment_btn'),
              onPressed: paying ? null : onPay,
              child: paying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Pay NZ\$$totalNzd',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: paying ? null : onBack,
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accepted Providers Widget
// ---------------------------------------------------------------------------

class AcceptedPaymentProvidersWidget extends StatelessWidget {
  const AcceptedPaymentProvidersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _VisaBrandLogo(),
                _MastercardBrandLogo(),
                _AmexBrandLogo(),
                _ApplePayBrandLogo(),
                _GooglePayBrandLogo(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '256-Bit SSL Encrypted & Protected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF635BFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF635BFF).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Powered by ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFA5B4FC)
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                      Text(
                        'stripe',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.3,
                          color: isDark
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFF635BFF),
                        ),
                      ),
                    ],
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

typedef _AcceptedProviders = AcceptedPaymentProvidersWidget;

class _VisaBrandLogo extends StatelessWidget {
  const _VisaBrandLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'V',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: 'ISA',
              style: TextStyle(
                color: Color(0xFF1A1F71),
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MastercardBrandLogo extends StatelessWidget {
  const _MastercardBrandLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 32,
        height: 20,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFEB001B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmexBrandLogo extends StatelessWidget {
  const _AmexBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF006FCF),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        'AMEX',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ApplePayBrandLogo extends StatelessWidget {
  const _ApplePayBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apple, size: 15, color: Colors.white),
          SizedBox(width: 1),
          Text(
            'Pay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GooglePayBrandLogo extends StatelessWidget {
  const _GooglePayBrandLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'Pay',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF5F6368),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Form
// ---------------------------------------------------------------------------

class _CardForm extends StatelessWidget {
  const _CardForm({
    required this.isDark,
    required this.colors,
    required this.cardNumberCtrl,
    required this.expiryCtrl,
    required this.cvcCtrl,
    required this.nameCtrl,
    required this.formKey,
    required this.brand,
    required this.onCardNumberChanged,
    required this.saveCard,
    required this.onSaveCardChanged,
  });

  final bool isDark;
  final ColorScheme colors;
  final TextEditingController cardNumberCtrl;
  final TextEditingController expiryCtrl;
  final TextEditingController cvcCtrl;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState> formKey;
  final String brand;
  final VoidCallback onCardNumberChanged;
  final bool saveCard;
  final ValueChanged<bool> onSaveCardChanged;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Form(
      key: formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: [
            // Card number with brand icon
            _CardField(
              controller: cardNumberCtrl,
              label: 'Card number',
              hint: '1234 5678 9012 3456',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
              maxLength: 19,
              suffixIcon: _BrandIcon(brand: brand),
              onChanged: (_) => onCardNumberChanged(),
              validator: (v) {
                final digits = (v ?? '').replaceAll(' ', '');
                if (digits.length < 13) return 'Enter a valid card number';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Expiry
                Expanded(
                  child: _CardField(
                    controller: expiryCtrl,
                    label: 'Expiry',
                    hint: 'MM / YY',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryFormatter(),
                    ],
                    maxLength: 7,
                    validator: (v) {
                      final clean = (v ?? '')
                          .replaceAll(' ', '')
                          .replaceAll('/', '');
                      if (clean.length < 4) return 'Invalid expiry';
                      final month = int.tryParse(clean.substring(0, 2)) ?? 0;
                      if (month < 1 || month > 12) return 'Invalid month';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // CVC
                Expanded(
                  child: _CardField(
                    controller: cvcCtrl,
                    label: 'CVC',
                    hint: '•••',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    obscureText: true,
                    suffixIcon: const Icon(Icons.info_outline, size: 16),
                    validator: (v) {
                      if ((v ?? '').length < 3) return 'Invalid CVC';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CardField(
              controller: nameCtrl,
              label: 'Cardholder name',
              hint: 'Name on card',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Enter cardholder name';
                return null;
              },
            ),
            const SizedBox(height: 10),
            // Save card toggle
            InkWell(
              onTap: () => onSaveCardChanged(!saveCard),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: saveCard,
                        onChanged: (v) => onSaveCardChanged(v ?? false),
                        activeColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Save this card for future payments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

class _CardField extends StatelessWidget {
  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand Icon
// ---------------------------------------------------------------------------

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    if (brand == 'visa') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'VISA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1A1F71),
            letterSpacing: 1,
          ),
        ),
      );
    }
    if (brand == 'mastercard') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEB001B),
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF79E1B),
                ),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.credit_card_outlined, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Saved Card Tile
// ---------------------------------------------------------------------------

class _SavedCardTile extends StatelessWidget {
  const _SavedCardTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedCard card;
  final bool selected;
  final VoidCallback onTap;

  static Widget newCard({required bool selected, required VoidCallback onTap}) {
    return _NewCardTile(selected: selected, onTap: onTap);
  }

  String get _brandLabel {
    switch (card.brand.toLowerCase()) {
      case 'visa':
        return 'Visa';
      case 'mastercard':
        return 'Mastercard';
      case 'amex':
        return 'Amex';
      default:
        return card.brand.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
          color: selected ? colors.primary.withOpacity(0.05) : colors.surface,
        ),
        child: Row(
          children: [
            Icon(
              Icons.credit_card_rounded,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_brandLabel ending in ${card.last4}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? colors.primary : null,
                    ),
                  ),
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
            if (selected) Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _NewCardTile extends StatelessWidget {
  const _NewCardTile({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
          color: selected ? colors.primary.withOpacity(0.05) : colors.surface,
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_card_outlined,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use a new card',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected ? colors.primary : null,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small Widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MerchantBanner extends StatelessWidget {
  const _MerchantBanner({required this.isDark, required this.colors});
  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F3D26) : const Color(0xFFF0FDF4);
    final border = isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KiwiShare Marketplace',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Campus peer-to-peer exchange · NZ',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: colors.primary, size: 18),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.order,
    required this.isDark,
    required this.colors,
  });

  final OrderModel order;
  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: order.item.imageUrl.isNotEmpty
                ? Image.network(
                    order.item.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 56,
                      height: 56,
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.inventory_2_outlined, size: 24),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: colors.surfaceContainerHighest,
                    child: const Icon(Icons.inventory_2_outlined, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Seller: ${order.counterparty.displayName}',
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.isDark,
    required this.colors,
    required this.rows,
  });
  final bool isDark;
  final ColorScheme colors;
  final List<(String, String, bool)> rows; // (label, value, isBold)

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              if (isLast) ...[
                Divider(color: colors.outline.withOpacity(0.2), height: 20),
              ],
              Padding(
                padding: EdgeInsets.symmetric(vertical: isLast ? 2 : 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.$1,
                      style: TextStyle(
                        fontWeight: row.$3 ? FontWeight.w700 : FontWeight.w500,
                        fontSize: row.$3 ? 15 : 13,
                        color: row.$3 ? null : colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      row.$2,
                      style: TextStyle(
                        fontWeight: row.$3 ? FontWeight.w800 : FontWeight.w600,
                        fontSize: row.$3 ? 16 : 13,
                        color: row.$3 ? colors.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline,
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          'Secured by Stripe · 256-bit SSL encryption',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Input Formatters
// ---------------------------------------------------------------------------

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '').replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write(' / ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Error View
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success Bottom Sheet
// ---------------------------------------------------------------------------

class _SuccessSheet extends StatefulWidget {
  const _SuccessSheet({
    required this.orderNumber,
    required this.totalNzd,
    required this.onDone,
  });
  final String orderNumber;
  final String totalNzd;
  final VoidCallback onDone;

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment successful!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${widget.orderNumber}',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'NZ\$${widget.totalNzd} paid',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your meetup QR code is now unlocked. Go to Meetups to view it.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const Key('payment_done_btn'),
                onPressed: widget.onDone,
                child: const Text(
                  'View Meetup QR Code',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
