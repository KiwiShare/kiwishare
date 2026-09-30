import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/watchlist_provider.dart';
import '../../../services/notification_permission_coordinator.dart';

/// Compact, reusable watchlist control for product imagery.
///
/// The heart remains visible for signed-out users so every product card has
/// the same layout. Signed-out taps explain why the action is unavailable.
class WatchlistHeartButton extends StatelessWidget {
  const WatchlistHeartButton({
    super.key,
    required this.item,
    this.permissionCoordinator,
    this.diameter = 30,
    this.iconSize = 16,
  });

  final ItemModel item;
  final NotificationPermissionCoordinator? permissionCoordinator;
  final double diameter;
  final double iconSize;

  Future<void> _toggle(
    BuildContext context,
    FavoritesProvider favorites,
  ) async {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    if (auth != null && !auth.isLoggedIn) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Log in to add items to your Watchlist.')),
      );
      return;
    }

    WatchlistMutationResult result;
    try {
      result = await favorites.toggleFavorite(item.id);
    } catch (error) {
      debugPrint('Watchlist update failed: $error');
      return;
    }
    if (!context.mounted || result != WatchlistMutationResult.added) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await offerContextualNotificationPermission(
      context,
      coordinator: permissionCoordinator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final auth = context.watch<AuthProvider?>();
    final currentUserId = auth?.currentUser?.id.trim();
    final sellerId = item.seller?.id.trim();
    final ownerId = item.ownerId.trim();
    final isOwnItem =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        ((ownerId.isNotEmpty && ownerId == currentUserId) ||
            (sellerId != null &&
                sellerId.isNotEmpty &&
                sellerId == currentUserId));
    final isFavorite = !isOwnItem && favorites.isFavorite(item.id);

    return Semantics(
      button: true,
      enabled: !isOwnItem,
      label: isOwnItem
          ? '${item.title} is your listing'
          : isFavorite
          ? 'Remove ${item.title} from Watchlist'
          : 'Add ${item.title} to Watchlist',
      child: Tooltip(
        message: isOwnItem
            ? 'This is your listing'
            : isFavorite
            ? 'Remove from Watchlist'
            : 'Add to Watchlist',
        child: SizedBox.square(
          dimension: diameter,
          child: Material(
            color: const Color(0x990F1720),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('watchlist-heart-${item.id}'),
              customBorder: const CircleBorder(),
              onTap: isOwnItem
                  ? null
                  : () => unawaited(_toggle(context, favorites)),
              child: Center(
                child: Icon(
                  isOwnItem
                      ? Icons.favorite_border_rounded
                      : isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: iconSize,
                  color: isOwnItem
                      ? Colors.white54
                      : isFavorite
                      ? const Color(0xFFEF4444)
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
