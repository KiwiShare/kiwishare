import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/item_model.dart';

class ShareService {
  const ShareService();

  static const ShareService instance = ShareService();

  /// Generates the canonical public web URL for an item.
  ///
  /// This intentionally uses the website route instead of the API origin.
  /// Native deep links can be added later without changing the shared URL.
  String getItemShareUrl(String itemId) {
    final encodedId = Uri.encodeComponent(itemId.trim());
    return '${ApiConfig.webBaseUrl}/products/$encodedId';
  }

  /// Generates standard share text for an item
  String getItemShareText(ItemModel item) {
    return 'Check out "${item.title}" for \$${item.priceNzd} NZD on KiwiShare!';
  }

  /// Generates full text including URL
  String getItemCombinedShareText(ItemModel item) {
    final text = getItemShareText(item);
    final url = getItemShareUrl(item.id);
    return '$text\n$url';
  }

  /// Copies link to clipboard and notifies user
  Future<void> copyLink({
    required BuildContext context,
    required String url,
  }) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    _showSnackBar(context, 'Link copied to clipboard!');
  }

  /// Shares via WhatsApp with pre-filled message
  Future<void> shareViaWhatsApp({
    required BuildContext context,
    required String text,
    required String url,
  }) async {
    final message = '$text\n$url';
    final appUri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback if WhatsApp is not installed/reachable
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    _showSnackBar(context, 'WhatsApp not installed. Info copied to clipboard!');
  }

  /// Shares via SMS messages app
  Future<void> shareViaSms({
    required BuildContext context,
    required String text,
    required String url,
  }) async {
    final message = '$text\n$url';
    final smsUri = Uri(scheme: 'sms', queryParameters: {'body': message});

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    _showSnackBar(context, 'Unable to open SMS. Info copied to clipboard!');
  }

  /// Shares via Facebook web dialog or app
  Future<void> shareViaFacebook({
    required BuildContext context,
    required String url,
  }) async {
    final fbUri = Uri.parse(
      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}',
    );

    try {
      if (await canLaunchUrl(fbUri)) {
        await launchUrl(fbUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    _showSnackBar(context, 'Link copied to clipboard!');
  }

  /// Instagram does not allow pre-filling text via deep link.
  /// Standard practice: copy info to clipboard, notify user, and launch Instagram.
  Future<void> shareViaInstagram({
    required BuildContext context,
    required String text,
    required String url,
  }) async {
    final message = '$text\n$url';
    await Clipboard.setData(ClipboardData(text: message));

    if (!context.mounted) return;
    _showSnackBar(context, 'Link copied! Opening Instagram...');

    final appUri = Uri.parse('instagram://app');
    final webUri = Uri.parse('https://www.instagram.com');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
  }

  /// WeChat requires native registered SDK to send cards directly.
  /// Standard practice: copy info to clipboard, notify user, and launch WeChat.
  Future<void> shareViaWeChat({
    required BuildContext context,
    required String text,
    required String url,
  }) async {
    final message = '$text\n$url';
    await Clipboard.setData(ClipboardData(text: message));

    final wechatUri = Uri.parse('weixin://');
    try {
      if (await canLaunchUrl(wechatUri)) {
        if (!context.mounted) return;
        _showSnackBar(context, 'Listing copied! Opening WeChat...');
        await launchUrl(wechatUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (!context.mounted) return;
    _showSnackBar(context, 'WeChat not installed. Info copied to clipboard!');
  }

  /// Invokes system native share sheet (UIActivityViewController on iOS, Intent.ACTION_SEND on Android)
  Future<void> shareViaSystem({
    required String text,
    required String url,
    Rect? sharePositionOrigin,
  }) async {
    final message = '$text\n$url';
    await Share.share(
      message,
      subject: text,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
