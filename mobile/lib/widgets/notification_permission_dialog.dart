import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

abstract final class NotificationPermissionDialogKeys {
  static const dialog = Key('notification-rationale-dialog');
  static const title = Key('notification-rationale-title');
  static const message = Key('notification-rationale-message');
  static const enable = Key('notification-rationale-enable');
  static const dismiss = Key('notification-rationale-dismiss');
}

/// Branded, accessible rationale dialog explaining notification benefits
/// before requesting native OS notification permissions.
class KiwiShareNotificationPermissionDialog extends StatelessWidget {
  const KiwiShareNotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isScaled = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    final enableButton = FilledButton(
      key: NotificationPermissionDialogKeys.enable,
      autofocus: true,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      onPressed: () => Navigator.of(context).pop(true),
      child: Text('Enable notifications', style: theme.textTheme.labelLarge),
    );

    final dismissButton = TextButton(
      key: NotificationPermissionDialogKeys.dismiss,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      onPressed: () => Navigator.of(context).pop(false),
      child: Text('Not now', style: theme.textTheme.labelLarge),
    );

    return Dialog(
      key: NotificationPermissionDialogKeys.dialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      elevation: 4,
      backgroundColor: theme.colorScheme.surface,
      child: Semantics(
        container: true,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Stay updated',
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    'Stay updated',
                    key: NotificationPermissionDialogKeys.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enable notifications to receive new messages and saved-item price-drop alerts.',
                  key: NotificationPermissionDialogKeys.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (isScaled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      enableButton,
                      const SizedBox(height: AppSpacing.sm),
                      dismissButton,
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      dismissButton,
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: enableButton),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
