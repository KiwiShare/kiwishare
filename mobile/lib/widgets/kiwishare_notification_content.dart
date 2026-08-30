import 'package:flutter/material.dart';

/// Branded, scalable content for foreground notification SnackBars.
class KiwiShareNotificationContent extends StatelessWidget {
  const KiwiShareNotificationContent({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final contentColor =
        Theme.of(context).snackBarTheme.contentTextStyle?.color ?? Colors.white;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: contentColor, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).snackBarTheme.contentTextStyle
                      ?.copyWith(color: contentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
