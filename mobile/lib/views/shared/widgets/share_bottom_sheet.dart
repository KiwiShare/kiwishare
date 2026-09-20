import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/item_model.dart';
import '../../../services/share_service.dart';
import '../../../theme/app_theme.dart';

class ShareBottomSheet extends StatelessWidget {
  final ItemModel item;
  final Rect? sharePositionOrigin;

  const ShareBottomSheet({
    super.key,
    required this.item,
    this.sharePositionOrigin,
  });

  static Future<void> show(
    BuildContext context, {
    required ItemModel item,
    Rect? sharePositionOrigin,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareBottomSheet(
        item: item,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shareService = ShareService.instance;
    final shareUrl = shareService.getItemShareUrl(item.id);
    final shareText = shareService.getItemShareText(item);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Text(
                'Share listing',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Item snippet card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: Colors.white,
                    child: item.images.isNotEmpty
                        ? Image.network(
                            item.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textSecondary,
                                ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.brandPrimary,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${item.priceNzd} NZD',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Channel grid / action list
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShareChannelButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_rounded,
                  background: const Color(0xFF25D366),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).pop();
                    shareService.shareViaWhatsApp(
                      context: context,
                      text: shareText,
                      url: shareUrl,
                    );
                  },
                ),
                const SizedBox(width: 14),
                _ShareChannelButton(
                  label: 'SMS',
                  icon: Icons.textsms_rounded,
                  background: const Color(0xFF34C759),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).pop();
                    shareService.shareViaSms(
                      context: context,
                      text: shareText,
                      url: shareUrl,
                    );
                  },
                ),
                const SizedBox(width: 14),
                _ShareChannelButton(
                  label: 'WeChat',
                  icon: Icons.forum_rounded,
                  background: const Color(0xFF07C160),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).pop();
                    shareService.shareViaWeChat(
                      context: context,
                      text: shareText,
                      url: shareUrl,
                    );
                  },
                ),
                const SizedBox(width: 14),
                _ShareChannelButton(
                  label: 'Instagram',
                  icon: Icons.camera_alt_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF833AB4),
                      Color(0xFFFD1D1D),
                      Color(0xFFFCB045),
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).pop();
                    shareService.shareViaInstagram(
                      context: context,
                      text: shareText,
                      url: shareUrl,
                    );
                  },
                ),
                const SizedBox(width: 14),
                _ShareChannelButton(
                  label: 'Facebook',
                  icon: Icons.facebook_rounded,
                  background: const Color(0xFF1877F2),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.of(context).pop();
                    shareService.shareViaFacebook(
                      context: context,
                      url: shareUrl,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),

          // Secondary actions: Copy link & System share
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textPrimary,
                  ),
                  icon: const Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  label: const Text(
                    'Copy link',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    shareService.copyLink(context: context, url: shareUrl);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(CupertinoIcons.share, size: 18),
                  label: const Text(
                    'System share',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    shareService.shareViaSystem(
                      text: shareText,
                      url: shareUrl,
                      sharePositionOrigin: sharePositionOrigin,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareChannelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? background;
  final Gradient? gradient;
  final Color iconColor;
  final VoidCallback onTap;

  const _ShareChannelButton({
    required this.label,
    required this.icon,
    this.background,
    this.gradient,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: background,
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
