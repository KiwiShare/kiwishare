import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/services/app_settings_launcher.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/profile/notification_settings_screen.dart';
import 'package:kiwishare/widgets/notification_permission_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  late _PermissionController controller;
  late _Storage storage;
  late _SettingsLauncher launcher;

  setUp(() {
    controller = _PermissionController();
    storage = _Storage();
    launcher = _SettingsLauncher();
  });

  Widget subject({double textScale = 1}) {
    final coordinator = NotificationPermissionCoordinator(
      permissionController: controller,
      storage: storage,
      appSettingsLauncher: launcher,
      now: () => DateTime.utc(2026, 9, 9),
    );
    return Provider<NotificationPermissionCoordinator>.value(
      value: coordinator,
      child: MaterialApp(
        theme: buildKiwiShareTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NotificationSettingsScreen(),
      ),
    );
  }

  testWidgets('notDetermined recovery explicitly opens the rationale', (
    tester,
  ) async {
    storage.nextEligibleAtMs = DateTime.utc(2026, 9, 15).millisecondsSinceEpoch;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Notifications not enabled yet'), findsOneWidget);
    await tester.tap(find.byKey(NotificationSettingsKeys.enable));
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    expect(controller.requestCalls, 0);
  });

  testWidgets('denied permission directs the user to application settings', (
    tester,
  ) async {
    controller.status = PushPermissionStatus.denied;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(
      find.text('Notifications blocked in device settings'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(NotificationSettingsKeys.openSettings));
    await tester.pumpAndSettle();
    expect(launcher.calls, 1);
    expect(controller.requestCalls, 0);
  });

  testWidgets('returning from settings refreshes and synchronizes a grant', (
    tester,
  ) async {
    controller.status = PushPermissionStatus.denied;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(NotificationSettingsKeys.openSettings));
    await tester.pumpAndSettle();

    controller.status = PushPermissionStatus.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Notifications enabled'), findsOneWidget);
    expect(controller.synchronizationCalls, 1);
  });

  testWidgets('unavailable state is clear and has no permission action', (
    tester,
  ) async {
    controller.status = PushPermissionStatus.unavailable;
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Notifications unavailable'), findsOneWidget);
    expect(find.byKey(NotificationSettingsKeys.enable), findsNothing);
    expect(find.byKey(NotificationSettingsKeys.openSettings), findsNothing);
  });

  testWidgets('settings content remains usable at 200 percent text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(subject(textScale: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationSettingsKeys.status), findsOneWidget);
    expect(find.byKey(NotificationSettingsKeys.enable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PermissionController implements PushPermissionController {
  @override
  int? activeSessionGeneration = 1;
  @override
  String? activeUserId = 'user-1';
  PushPermissionStatus status = PushPermissionStatus.notDetermined;
  int requestCalls = 0;
  int synchronizationCalls = 0;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<PushPermissionStatus> requestPermissionAndSync({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async {
    requestCalls += 1;
    return status;
  }

  @override
  Future<PushPermissionStatus> synchronizeIfAuthorized({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async {
    synchronizationCalls += 1;
    return status;
  }
}

class _Storage implements NotificationPermissionStorage {
  int? nextEligibleAtMs;

  @override
  Future<int?> getNextEligibleAtMs() async => nextEligibleAtMs;

  @override
  Future<void> setNextEligibleAtMs(int value) async => nextEligibleAtMs = value;

  @override
  Future<void> removeObsoleteDismissal() async {}
}

class _SettingsLauncher implements AppSettingsLauncher {
  int calls = 0;

  @override
  Future<bool> openAppSettings() async {
    calls += 1;
    return true;
  }
}
