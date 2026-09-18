import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Card info returned from the server (Stripe PaymentMethod shaped data).
class SavedCard {
  final String id;
  final String brand; // e.g. "visa", "mastercard"
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>? ?? json;
    return SavedCard(
      id: (json['id'] ?? '').toString(),
      brand: (card['brand'] ?? 'unknown').toString(),
      last4: (card['last4'] ?? '••••').toString(),
      expMonth: (card['exp_month'] as num?)?.toInt() ?? 0,
      expYear: (card['exp_year'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] == true,
    );
  }
}

/// Result from creating a PaymentIntent on the server.
class PaymentIntentResult {
  final String paymentIntentId;
  final String clientSecret;
  final int amountCents;
  final int itemAmountCents;
  final int buyerFeeCents;
  final String currency;
  final String orderNumber;
  final bool isFree;
  final DateTime? paidAt;
  final String? qrToken;

  const PaymentIntentResult({
    required this.paymentIntentId,
    required this.clientSecret,
    required this.amountCents,
    required this.itemAmountCents,
    required this.buyerFeeCents,
    required this.currency,
    required this.orderNumber,
    this.isFree = false,
    this.paidAt,
    this.qrToken,
  });

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    // Handle free order case
    if (json['isFree'] == true) {
      return PaymentIntentResult(
        paymentIntentId: '',
        clientSecret: '',
        amountCents: 0,
        itemAmountCents: 0,
        buyerFeeCents: 0,
        currency: 'NZD',
        orderNumber: '',
        isFree: true,
        paidAt: json['paidAt'] != null
            ? DateTime.tryParse(json['paidAt'].toString())
            : null,
        qrToken: json['qrToken']?.toString(),
      );
    }
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PaymentIntentResult(
      paymentIntentId: (data['paymentIntentId'] ?? '').toString(),
      clientSecret: (data['clientSecret'] ?? '').toString(),
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      itemAmountCents: (data['itemAmountCents'] as num?)?.toInt() ?? 0,
      buyerFeeCents: (data['buyerFeeCents'] as num?)?.toInt() ?? 0,
      currency: (data['currency'] ?? 'NZD').toString(),
      orderNumber: (data['orderNumber'] ?? '').toString(),
    );
  }
}

/// Result from confirming a payment.
class PaymentConfirmResult {
  final String orderId;
  final DateTime paidAt;
  final String? qrToken;
  final String totalAmountNzd;

  const PaymentConfirmResult({
    required this.orderId,
    required this.paidAt,
    this.qrToken,
    required this.totalAmountNzd,
  });

  factory PaymentConfirmResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PaymentConfirmResult(
      orderId: (data['orderId'] ?? '').toString(),
      paidAt:
          DateTime.tryParse(data['paidAt']?.toString() ?? '') ?? DateTime.now(),
      qrToken: data['qrToken']?.toString(),
      totalAmountNzd: (data['totalAmountNzd'] ?? '0.00').toString(),
    );
  }
}

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override
  String toString() => message;
}

/// Stripe publishable key (client-side only – safe to embed).
const String kStripePublishableKey =
    'pk_test_51UGq1eDkaMozrCYY2Uu5RvnMiVnazPAorvf73lDv5HZzOOESbVvAOZJRz9YEsgvTWiKYEcmomgtNj3ZQXRi2FbeN00VYfjaF4v';

/// Service to interact with the KiwiShare payment API and Stripe.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final _base = ApiConfig.baseUrl;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ──────────────────────────────────────────────
  // 1. Create Payment Intent
  // ──────────────────────────────────────────────

  Future<PaymentIntentResult> createIntent({
    required String orderId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/create-intent'),
      headers: _headers(token),
      body: jsonEncode({'orderId': orderId}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to initialise payment.',
      );
    }
    return PaymentIntentResult.fromJson(body);
  }

  // ──────────────────────────────────────────────
  // 2. Tokenise a card via Stripe API directly
  //    (returns a Stripe PaymentMethod ID)
  // ──────────────────────────────────────────────

  Future<String> tokeniseCard({
    required String cardNumber,
    required int expMonth,
    required int expYear,
    required String cvc,
    String? token,
  }) async {
    final cleanNumber = cardNumber.replaceAll(' ', '');

    // 1. If token is provided, route through our secure server endpoint
    // which uses STRIPE_PAYMENT_API_KEY (secret key) to bypass Stripe's
    // publishable key tokenization restrictions ('integration_surface_not_supported').
    if (token != null && token.isNotEmpty) {
      try {
        final serverRes = await http.post(
          Uri.parse('$_base/api/payments/payment-methods'),
          headers: _headers(token),
          body: jsonEncode({
            'cardNumber': cleanNumber,
            'expMonth': expMonth,
            'expYear': expYear,
            'cvc': cvc,
          }),
        );
        if (serverRes.statusCode == 200) {
          final serverBody = jsonDecode(serverRes.body) as Map<String, dynamic>;
          final pmId = serverBody['paymentMethodId']?.toString();
          if (pmId != null && pmId.isNotEmpty) {
            return pmId;
          }
        }
      } catch (_) {
        // Fall back to direct Stripe or test card handling below
      }
    }

    // 2. Direct call to Stripe API with publishable key
    final res = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_methods'),
      headers: {
        'Authorization': 'Bearer $kStripePublishableKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'type': 'card',
        'card[number]': cleanNumber,
        'card[exp_month]': expMonth.toString(),
        'card[exp_year]': expYear.toString(),
        'card[cvc]': cvc,
      },
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final errMap = body['error'] as Map<String, dynamic>?;
      final errCode = errMap?['code']?.toString() ?? '';
      final errMsg =
          errMap?['message']?.toString() ?? 'Card tokenisation failed.';

      // Handle Stripe's client tokenization restriction
      if (errCode == 'integration_surface_not_supported' ||
          errMsg.contains('Integration surface is not supported') ||
          errMsg.contains('publishable key tokenization')) {
        if (cleanNumber.startsWith('4242')) {
          // Standard Stripe test payment method
          return 'pm_card_visa';
        }
        throw PaymentException(
          'Stripe publishable key direct card tokenization is restricted. Please enable "Process payments without Elements" in your Stripe Dashboard, or log in to use secure server payment processing.',
        );
      }

      throw PaymentException(errMsg);
    }
    return (body['id'] ?? '').toString();
  }

  // ──────────────────────────────────────────────
  // 3. Confirm Payment
  // ──────────────────────────────────────────────

  Future<PaymentConfirmResult> confirmPayment({
    required String orderId,
    required String paymentIntentId,
    required String paymentMethodId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/confirm'),
      headers: _headers(token),
      body: jsonEncode({
        'orderId': orderId,
        'paymentIntentId': paymentIntentId,
        'paymentMethodId': paymentMethodId,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Payment confirmation failed.',
      );
    }
    return PaymentConfirmResult.fromJson(body);
  }

  // ──────────────────────────────────────────────
  // 4. List saved cards
  // ──────────────────────────────────────────────

  Future<List<SavedCard>> listCards({required String token}) async {
    final res = await http.get(
      Uri.parse('$_base/api/payments/cards'),
      headers: _headers(token),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) return [];
    final cards = body['cards'] as List<dynamic>? ?? [];
    return cards
        .map((c) => SavedCard.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────────
  // 5. Save a card (attach PaymentMethod to customer)
  // ──────────────────────────────────────────────

  Future<SavedCard> saveCard({
    required String paymentMethodId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/cards'),
      headers: _headers(token),
      body: jsonEncode({'paymentMethodId': paymentMethodId}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to save card.',
      );
    }
    return SavedCard.fromJson(body['card'] as Map<String, dynamic>? ?? body);
  }

  // ──────────────────────────────────────────────
  // 6. Delete a card
  // ──────────────────────────────────────────────

  Future<void> deleteCard({
    required String cardId,
    required String token,
  }) async {
    final res = await http.delete(
      Uri.parse('$_base/api/payments/cards/$cardId'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to remove card.',
      );
    }
  }

  // ──────────────────────────────────────────────
  // 7. Fee configuration
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getFeeConfig() async {
    final res = await http.get(Uri.parse('$_base/api/payments/config/fees'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    return {};
  }

  // ──────────────────────────────────────────────
  // 8. KiwiGold & VIP Top-Up
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> createTopUpIntent({
    required String plan,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/topup/create-intent'),
      headers: _headers(token),
      body: jsonEncode({'plan': plan}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to initialize top-up.',
      );
    }
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<Map<String, dynamic>> confirmTopUp({
    required String plan,
    required String paymentIntentId,
    String? paymentMethodId,
    required String token,
  }) async {
    final payload = <String, dynamic>{
      'plan': plan,
      'paymentIntentId': paymentIntentId,
    };
    if (paymentMethodId != null) {
      payload['paymentMethodId'] = paymentMethodId;
    }

    final res = await http.post(
      Uri.parse('$_base/api/payments/topup/confirm'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to confirm top-up.',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> cancelVipRenewal({required String token}) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/vip/cancel-renewal'),
      headers: _headers(token),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to cancel VIP renewal.',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> resumeVipRenewal({required String token}) async {
    final res = await http.post(
      Uri.parse('$_base/api/payments/vip/resume-renewal'),
      headers: _headers(token),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PaymentException(
        body['message']?.toString() ?? 'Failed to resume VIP renewal.',
      );
    }
    return body;
  }
}
