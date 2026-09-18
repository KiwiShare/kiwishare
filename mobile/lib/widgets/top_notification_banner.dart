import 'dart:async';
import 'package:flutter/material.dart';

/// Active top notification entry controller.
OverlayEntry? _activeTopNotificationEntry;
Timer? _activeTopNotificationTimer;

/// Dismisses any currently visible top notification banner immediately.
void dismissCurrentTopNotification() {
  _activeTopNotificationTimer?.cancel();
  _activeTopNotificationTimer = null;
  if (_activeTopNotificationEntry != null) {
    try {
      _activeTopNotificationEntry?.remove();
    } catch (_) {}
    _activeTopNotificationEntry = null;
  }
}

/// Displays an in-app push notification banner at the top of the phone screen.
///
/// Features:
/// - Positioned inside [SafeArea(top: true)] at the very top of the mobile display.
/// - Smooth entrance slide-down and fade animation.
/// - Swipe up to dismiss or tap to trigger action/destination.
/// - Auto-dismisses after [duration] (defaults to 4 seconds).
/// - Gracefully falls back to [fallbackMessenger] if overlay is unavailable.
void showTopNotification({
  BuildContext? context,
  GlobalKey<NavigatorState>? navigatorKey,
  ScaffoldMessengerState? fallbackMessenger,
  required String title,
  required String body,
  required IconData icon,
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  dismissCurrentTopNotification();

  final overlay = navigatorKey?.currentState?.overlay ??
      (context != null ? Navigator.maybeOf(context)?.overlay : null);

  if (overlay == null) {
    // Fallback if overlay is not mounted (e.g. in certain widget tests)
    if (fallbackMessenger != null) {
      fallbackMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        body,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: actionLabel != null
                ? SnackBarAction(
                    label: actionLabel,
                    onPressed: onAction ?? onTap ?? () {},
                  )
                : null,
            duration: duration,
          ),
        );
    }
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopNotificationCard(
      title: title,
      body: body,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      onTap: onTap,
      onDismiss: () {
        if (_activeTopNotificationEntry == entry) {
          dismissCurrentTopNotification();
        }
      },
    ),
  );

  _activeTopNotificationEntry = entry;
  overlay.insert(entry);

  _activeTopNotificationTimer = Timer(duration, () {
    if (_activeTopNotificationEntry == entry) {
      dismissCurrentTopNotification();
    }
  });
}

class _TopNotificationCard extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _TopNotificationCard({
    required this.title,
    required this.body,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationCard> createState() => _TopNotificationCardState();
}

class _TopNotificationCardState extends State<_TopNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return SafeArea(
      top: true,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null &&
                      details.primaryDelta! < -4) {
                    _handleDismiss();
                  }
                },
                onTap: () {
                  _handleDismiss();
                  if (widget.onTap != null) {
                    widget.onTap!();
                  } else if (widget.onAction != null) {
                    widget.onAction!();
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.12,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: subtextColor,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: isDark ? 0.25 : 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _handleDismiss();
                              if (widget.onAction != null) {
                                widget.onAction!();
                              } else if (widget.onTap != null) {
                                widget.onTap!();
                              }
                            },
                            child: Text(
                              widget.actionLabel!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
