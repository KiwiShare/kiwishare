import 'package:flutter/material.dart';

import '../../../models/chat_message_model.dart';
import '../../../services/map_launcher_service.dart';
import '../../../theme/app_theme.dart';

class LocationBubble extends StatelessWidget {
  const LocationBubble({
    super.key,
    required this.location,
    required this.isMine,
    required this.createdAt,
  });

  final ChatLocationPayload location;
  final bool isMine;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: () {
        MapLauncherService.instance.showNavigationSheet(
          context: context,
          locationName: location.name,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map header preview / icon
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: isMine
                    ? colors.primaryContainer.withOpacity(0.3)
                    : colors.primary.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.medium),
                  topRight: Radius.circular(AppRadius.medium),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: isMine ? Colors.white : colors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Shared Spot',
                      style: TextStyle(
                        color: isMine ? Colors.white : colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isMine ? Colors.white : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMine
                          ? Colors.white.withOpacity(0.75)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
