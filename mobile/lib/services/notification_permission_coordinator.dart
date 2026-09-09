import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/notification_permission_dialog.dart';
import 'app_settings_launcher.dart';
import 'push_notification_service.dart';

Future<void> offerContextualNotificationPermission(
  BuildContext context, {
  NotificationPermissionCoordinator? coordinator,
}) async {
  if (!context.mounted) return;
  final NotificationPermissionCoordinator resolved;
  try {
    resolved = coordinator ?? context.read<NotificationPermissionCoordinator>();
  } on ProviderNotFoundException {
    return;
  }
  try {
    await resolved.requestContextualPermission(context);
  } catch (error) {
    debugPrint('Contextual notification permission flow failed: $error');
  }
}

abstract interface class NotificationPermissionStorage {
  Future<int?> getNextEligibleAtMs();
  Future<void> setNextEligibleAtMs(int millisecondsSinceEpoch);
  Future<void> removeObsoleteDismissal();
}

class SharedPrefsNotificationPermissionStorage
    implements NotificationPermissionStorage {
  static const nextEligibleAtKey =
      'kiwishare_notification_rationale_next_eligible_at_ms';
  static const obsoleteDismissedKey =
      'kiwishare_notification_rationale_dismissed';

  @override
  Future<int?> getNextEligibleAtMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(nextEligibleAtKey);
  }

  @override
  Future<void> setNextEligibleAtMs(int millisecondsSinceEpoch) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await prefs.setInt(
      nextEligibleAtKey,
      millisecondsSinceEpoch,
    );
    if (!stored) throw StateError('Notification prompt state was not saved.');
  }

  @override
  Future<void> removeObsoleteDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(obsoleteDismissedKey)) return;
    final removed = await prefs.remove(obsoleteDismissedKey);
    if (!removed) {
      throw StateError('Obsolete notification state was not removed.');
    }
  }
}

/// Coordinates contextual and explicit notification-permission requests.
class NotificationPermissionCoordinator {
  NotificationPermissionCoordinator({
    this.permissionController,
    NotificationPermissionStorage? storage,
    AppSettingsLauncher? appSettingsLauncher,
    DateTime Function()? now,
  }) : _storage = storage ?? SharedPrefsNotificationPermissionStorage(),
       _appSettingsLauncher =
           appSettingsLauncher ?? DeviceAppSettingsLauncher(),
       _now = now ?? DateTime.now;

  static const automaticPromptCooldown = Duration(days: 7);

  final PushPermissionController? permissionController;
  final NotificationPermissionStorage _storage;
  final AppSettingsLauncher _appSettingsLauncher;
  final DateTime Function() _now;
  bool _isPrompting = false;
  bool _storageInitialized = false;
  DateTime? _inMemoryNextEligibleAt;

  bool get isPrompting => _isPrompting;

  Future<PushPermissionStatus> getPermissionStatus() async {
    final controller = permissionController;
    if (controller == null) return PushPermissionStatus.unavailable;
    try {
      return await controller.getPermissionStatus();
    } catch (error) {
      debugPrint('Notification permission status lookup failed: $error');
      return PushPermissionStatus.unavailable;
    }
  }

  Future<PushPermissionStatus> requestContextualPermission(
    BuildContext context,
  ) => _requestPermission(context, ignoreCooldown: false);

  Future<PushPermissionStatus> requestFromSettings(BuildContext context) =>
      _requestPermission(context, ignoreCooldown: true);

  Future<PushPermissionStatus> refreshStatusAndSynchronize() async {
    final controller = permissionController;
    final generation = controller?.activeSessionGeneration;
    if (controller == null || generation == null) {
      return PushPermissionStatus.unavailable;
    }
    return controller.synchronizeIfAuthorized(
      expectedSessionGeneration: generation,
      expectedUserId: controller.activeUserId,
    );
  }

  Future<bool> openAppSettings() async {
    try {
      return await _appSettingsLauncher.openAppSettings();
    } catch (error) {
      debugPrint('Unable to open application settings: $error');
      return false;
    }
  }

  Future<PushPermissionStatus> _requestPermission(
    BuildContext context, {
    required bool ignoreCooldown,
  }) async {
    if (_isPrompting) return PushPermissionStatus.unavailable;
    _isPrompting = true;
    try {
      final controller = permissionController;
      final sessionGeneration = controller?.activeSessionGeneration;
      final sessionUserId = controller?.activeUserId;
      if (controller == null || sessionGeneration == null) {
        return PushPermissionStatus.unavailable;
      }

      final currentStatus = await getPermissionStatus();
      if (currentStatus == PushPermissionStatus.authorized ||
          currentStatus == PushPermissionStatus.provisional ||
          currentStatus == PushPermissionStatus.denied ||
          currentStatus == PushPermissionStatus.unavailable) {
        return currentStatus;
      }

      if (!ignoreCooldown && !await _isAutomaticallyEligible()) {
        return currentStatus;
      }
      if (!context.mounted ||
          !_isSameSession(controller, sessionGeneration, sessionUserId)) {
        return PushPermissionStatus.unavailable;
      }

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const KiwiShareNotificationPermissionDialog(),
      );
      if (accepted != true) {
        await _recordCooldown();
        return currentStatus;
      }
      if (!context.mounted ||
          !_isSameSession(controller, sessionGeneration, sessionUserId)) {
        return PushPermissionStatus.unavailable;
      }

      final result = await controller.requestPermissionAndSync(
        expectedSessionGeneration: sessionGeneration,
        expectedUserId: sessionUserId,
      );
      if (result != PushPermissionStatus.authorized &&
          result != PushPermissionStatus.provisional) {
        await _recordCooldown();
      }
      return result;
    } catch (error) {
      debugPrint('Contextual notification permission flow failed: $error');
      await _recordCooldown();
      return PushPermissionStatus.unavailable;
    } finally {
      _isPrompting = false;
    }
  }

  bool _isSameSession(
    PushPermissionController controller,
    int generation,
    String? userId,
  ) =>
      controller.activeSessionGeneration == generation &&
      controller.activeUserId == userId;

  Future<bool> _isAutomaticallyEligible() async {
    final now = _now().toUtc();
    final inMemory = _inMemoryNextEligibleAt;
    if (inMemory != null && now.isBefore(inMemory)) return false;
    try {
      if (!_storageInitialized) {
        await _storage.removeObsoleteDismissal();
        _storageInitialized = true;
      }
      final stored = await _storage.getNextEligibleAtMs();
      if (stored == null) return true;
      final nextEligible = DateTime.fromMillisecondsSinceEpoch(
        stored,
        isUtc: true,
      );
      _inMemoryNextEligibleAt = nextEligible;
      return !now.isBefore(nextEligible);
    } catch (error) {
      debugPrint('Notification prompt state could not be read: $error');
      return false;
    }
  }

  Future<void> _recordCooldown() async {
    final nextEligible = _now().toUtc().add(automaticPromptCooldown);
    _inMemoryNextEligibleAt = nextEligible;
    try {
      await _storage.setNextEligibleAtMs(nextEligible.millisecondsSinceEpoch);
    } catch (error) {
      debugPrint('Notification prompt state could not be saved: $error');
    }
  }
}
