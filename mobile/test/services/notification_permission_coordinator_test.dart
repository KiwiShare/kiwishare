import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/services/app_settings_launcher.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/widgets/notification_permission_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePermissionController implements PushPermissionController {
  @override
  int? activeSessionGeneration = 1;
  @override
  String? activeUserId = 'user-1';
  PushPermissionStatus status = PushPermissionStatus.notDetermined;
  PushPermissionStatus requestedStatus = PushPermissionStatus.authorized;
  Completer<PushPermissionStatus>? statusCompleter;
  Completer<PushPermissionStatus>? requestCompleter;
  bool throwOnRequest = false;
  int statusCalls = 0;
  int requestCalls = 0;
  int synchronizationCalls = 0;
  int? requestedGeneration;
  String? requestedUserId;

  @override
  Future<PushPermissionStatus> getPermissionStatus() {
    statusCalls += 1;
    return statusCompleter?.future ?? Future.value(status);
  }

  @override
  Future<PushPermissionStatus> requestPermissionAndSync({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) {
    requestCalls += 1;
    requestedGeneration = expectedSessionGeneration;
    requestedUserId = expectedUserId;
    if (throwOnRequest) throw StateError('Native permission unavailable');
    return requestCompleter?.future ?? Future.value(requestedStatus);
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

class _MemoryStorage implements NotificationPermissionStorage {
  int? nextEligibleAtMs;
  bool obsoleteDismissal = false;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnRemove = false;
  int writes = 0;
  int obsoleteRemovals = 0;

  @override
  Future<int?> getNextEligibleAtMs() async {
    if (throwOnRead) throw StateError('read failed');
    return nextEligibleAtMs;
  }

  @override
  Future<void> setNextEligibleAtMs(int value) async {
    writes += 1;
    if (throwOnWrite) throw StateError('write failed');
    nextEligibleAtMs = value;
  }

  @override
  Future<void> removeObsoleteDismissal() async {
    obsoleteRemovals += 1;
    if (throwOnRemove) throw StateError('remove failed');
    obsoleteDismissal = false;
  }
}

class _FakeAppSettingsLauncher implements AppSettingsLauncher {
  int calls = 0;
  bool result = true;

  @override
  Future<bool> openAppSettings() async {
    calls += 1;
    return result;
  }
}

void main() {
  late _FakePermissionController controller;
  late _MemoryStorage storage;
  late _FakeAppSettingsLauncher settingsLauncher;
  late DateTime now;
  late NotificationPermissionCoordinator coordinator;

  setUp(() {
    controller = _FakePermissionController();
    storage = _MemoryStorage();
    settingsLauncher = _FakeAppSettingsLauncher();
    now = DateTime.utc(2026, 9, 9, 12);
    coordinator = NotificationPermissionCoordinator(
      permissionController: controller,
      storage: storage,
      appSettingsLauncher: settingsLauncher,
      now: () => now,
    );
  });

  Widget app({required Widget child, double textScale = 1}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  Future<BuildContext> pumpAction(WidgetTester tester) async {
    late BuildContext actionContext;
    await tester.pumpWidget(
      app(
        child: Builder(
          builder: (context) {
            actionContext = context;
            return const Text('Ready');
          },
        ),
      ),
    );
    return actionContext;
  }

  testWidgets('primary action requests once for the captured session', (
    tester,
  ) async {
    final context = await pumpAction(tester);
    final result = coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();

    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    expect(controller.requestCalls, 0);
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.enable));
    await tester.pumpAndSettle();

    expect(await result, PushPermissionStatus.authorized);
    expect(controller.requestCalls, 1);
    expect(controller.requestedGeneration, 1);
    expect(controller.requestedUserId, 'user-1');
  });

  testWidgets('Not now starts a seven-day UTC cooldown', (tester) async {
    final context = await pumpAction(tester);
    final first = coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    await first;

    expect(
      storage.nextEligibleAtMs,
      now
          .add(NotificationPermissionCoordinator.automaticPromptCooldown)
          .millisecondsSinceEpoch,
    );

    await coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);

    now = now.add(const Duration(days: 7));
    final eligible = coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    await eligible;
  });

  testWidgets('explicit settings recovery bypasses the cooldown', (
    tester,
  ) async {
    storage.nextEligibleAtMs = now
        .add(const Duration(days: 6))
        .millisecondsSinceEpoch;
    final context = await pumpAction(tester);

    final result = coordinator.requestFromSettings(context);
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    await result;
  });

  testWidgets(
    'obsolete local boolean is removed once without affecting state',
    (tester) async {
      storage.obsoleteDismissal = true;
      final context = await pumpAction(tester);
      final result = coordinator.requestContextualPermission(context);
      await tester.pumpAndSettle();

      expect(storage.obsoleteRemovals, 1);
      expect(storage.obsoleteDismissal, isFalse);
      expect(
        find.byKey(NotificationPermissionDialogKeys.dialog),
        findsOneWidget,
      );
      await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
      await tester.pumpAndSettle();
      await result;
    },
  );

  for (final status in [
    PushPermissionStatus.authorized,
    PushPermissionStatus.provisional,
  ]) {
    testWidgets('$status bypasses rationale and native request', (
      tester,
    ) async {
      controller.status = status;
      final context = await pumpAction(tester);
      expect(await coordinator.requestContextualPermission(context), status);
      await tester.pumpAndSettle();
      expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
      expect(controller.requestCalls, 0);
    });
  }

  for (final status in [
    PushPermissionStatus.denied,
    PushPermissionStatus.unavailable,
  ]) {
    testWidgets('$status never opens rationale or requests permission', (
      tester,
    ) async {
      controller.status = status;
      final context = await pumpAction(tester);
      await coordinator.requestContextualPermission(context);
      await coordinator.requestFromSettings(context);
      await tester.pumpAndSettle();
      expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
      expect(controller.requestCalls, 0);
    });
  }

  testWidgets('concurrent entry points create one rationale', (tester) async {
    final context = await pumpAction(tester);
    final first = coordinator.requestContextualPermission(context);
    final second = coordinator.requestFromSettings(context);
    await tester.pumpAndSettle();

    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    expect(await second, PushPermissionStatus.unavailable);
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    await first;
  });

  testWidgets('automatic storage read errors fail closed', (tester) async {
    storage.throwOnRead = true;
    final context = await pumpAction(tester);
    expect(
      await coordinator.requestContextualPermission(context),
      PushPermissionStatus.notDetermined,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
    expect(controller.requestCalls, 0);
  });

  testWidgets('failed cooldown write still suppresses this process', (
    tester,
  ) async {
    storage.throwOnWrite = true;
    final context = await pumpAction(tester);
    final first = coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
    await tester.pumpAndSettle();
    await first;

    await coordinator.requestContextualPermission(context);
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
  });

  testWidgets(
    'account switch while rationale is visible cancels native request',
    (tester) async {
      final context = await pumpAction(tester);
      final result = coordinator.requestContextualPermission(context);
      await tester.pumpAndSettle();
      controller
        ..activeSessionGeneration = 2
        ..activeUserId = 'user-2';
      await tester.tap(find.byKey(NotificationPermissionDialogKeys.enable));
      await tester.pumpAndSettle();

      expect(await result, PushPermissionStatus.unavailable);
      expect(controller.requestCalls, 0);
    },
  );

  testWidgets('route disposal while status is pending shows no UI', (
    tester,
  ) async {
    controller.statusCompleter = Completer<PushPermissionStatus>();
    final context = await pumpAction(tester);
    final result = coordinator.requestContextualPermission(context);
    await tester.pumpWidget(app(child: const Text('Different route')));
    controller.statusCompleter!.complete(PushPermissionStatus.notDetermined);
    await tester.pumpAndSettle();

    expect(await result, PushPermissionStatus.unavailable);
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('settings refresh synchronizes the active session', () async {
    controller.status = PushPermissionStatus.authorized;
    expect(
      await coordinator.refreshStatusAndSynchronize(),
      PushPermissionStatus.authorized,
    );
    expect(controller.synchronizationCalls, 1);
  });

  test('app-settings launch uses the injected boundary', () async {
    expect(await coordinator.openAppSettings(), isTrue);
    expect(settingsLauncher.calls, 1);
  });

  test(
    'SharedPreferences stores the timestamp and removes obsolete state',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsNotificationPermissionStorage.obsoleteDismissedKey: true,
      });
      final preferences = SharedPrefsNotificationPermissionStorage();

      await preferences.removeObsoleteDismissal();
      await preferences.setNextEligibleAtMs(123456);

      final values = await SharedPreferences.getInstance();
      expect(
        values.containsKey(
          SharedPrefsNotificationPermissionStorage.obsoleteDismissedKey,
        ),
        isFalse,
      );
      expect(await preferences.getNextEligibleAtMs(), 123456);
    },
  );

  testWidgets('rationale remains accessible at 200 percent text scaling', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        textScale: 2,
        child: Builder(
          builder: (value) {
            context = value;
            return const Text('Ready');
          },
        ),
      ),
    );
    unawaited(coordinator.requestContextualPermission(context));
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationPermissionDialogKeys.enable), findsOneWidget);
    expect(
      find.byKey(NotificationPermissionDialogKeys.dismiss),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
