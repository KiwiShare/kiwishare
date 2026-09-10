import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/notification_permission_coordinator.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_theme.dart';

abstract final class NotificationSettingsKeys {
  static const status = Key('notification-settings-status');
  static const enable = Key('notification-settings-enable');
  static const openSettings = Key('notification-settings-open-app-settings');
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  PushPermissionStatus? _status;
  bool _isWorking = false;
  bool _openedAppSettings = false;

  NotificationPermissionCoordinator get _coordinator =>
      context.read<NotificationPermissionCoordinator>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshStatus());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedAppSettings) {
      _openedAppSettings = false;
      unawaited(_refreshStatus(synchronize: true));
    }
  }

  Future<void> _refreshStatus({bool synchronize = false}) async {
    final status = synchronize
        ? await _coordinator.refreshStatusAndSynchronize()
        : await _coordinator.getPermissionStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _requestPermission() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final status = await _coordinator.requestFromSettings(context);
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error) {
      debugPrint('Notification settings permission request failed: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _openAppSettings() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final opened = await _coordinator.openAppSettings();
      if (!mounted) return;
      _openedAppSettings = opened;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Open your device settings and allow notifications for KiwiShare.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final presentation = _presentationFor(status);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Semantics(
            container: true,
            label: 'System notification permission: ${presentation.title}',
            child: Card(
              key: NotificationSettingsKeys.status,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      presentation.icon,
                      size: 36,
                      color: presentation.color(theme.colorScheme),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      presentation.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      presentation.message,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (status == PushPermissionStatus.notDetermined) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        key: NotificationSettingsKeys.enable,
                        onPressed: _isWorking
                            ? null
                            : () => unawaited(_requestPermission()),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Enable notifications'),
                      ),
                    ] else if (status == PushPermissionStatus.denied ||
                        status == PushPermissionStatus.authorized ||
                        status == PushPermissionStatus.provisional) ...[
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        key: NotificationSettingsKeys.openSettings,
                        onPressed: _isWorking
                            ? null
                            : () => unawaited(_openAppSettings()),
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(
                          status == PushPermissionStatus.denied
                              ? 'Open device settings'
                              : 'Manage in device settings',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'System permission controls whether KiwiShare can display notifications. Business notification preferences are managed separately.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

_PermissionPresentation _presentationFor(PushPermissionStatus? status) {
  return switch (status) {
    null => const _PermissionPresentation(
      title: 'Checking notification access',
      message: 'KiwiShare is checking your device notification settings.',
      icon: Icons.hourglass_top_outlined,
      color: _statusNeutral,
    ),
    PushPermissionStatus.authorized => const _PermissionPresentation(
      title: 'Notifications enabled',
      message: 'KiwiShare can display notifications on this device.',
      icon: Icons.notifications_active_outlined,
      color: _statusPrimary,
    ),
    PushPermissionStatus.provisional => const _PermissionPresentation(
      title: 'Notifications enabled quietly',
      message: 'KiwiShare can deliver notifications quietly on this device.',
      icon: Icons.notifications_none_outlined,
      color: _statusPrimary,
    ),
    PushPermissionStatus.notDetermined => const _PermissionPresentation(
      title: 'Notifications not enabled yet',
      message: 'Enable notifications when you are ready to stay updated.',
      icon: Icons.notifications_none_outlined,
      color: _statusNeutral,
    ),
    PushPermissionStatus.denied => const _PermissionPresentation(
      title: 'Notifications blocked in device settings',
      message:
          'Allow notifications for KiwiShare in your device settings to receive updates.',
      icon: Icons.notifications_off_outlined,
      color: _statusError,
    ),
    PushPermissionStatus.unavailable => const _PermissionPresentation(
      title: 'Notifications unavailable',
      message:
          'Notification access is unavailable on this device or in this app configuration.',
      icon: Icons.info_outline,
      color: _statusNeutral,
    ),
  };
}

Color _statusPrimary(ColorScheme scheme) => scheme.primary;
Color _statusNeutral(ColorScheme scheme) => scheme.onSurfaceVariant;
Color _statusError(ColorScheme scheme) => scheme.error;

class _PermissionPresentation {
  const _PermissionPresentation({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color Function(ColorScheme) color;
}
