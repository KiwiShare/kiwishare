import 'package:firebase_core/firebase_core.dart';

/// Returns whether FlutterFire supplied the minimum non-placeholder options
/// needed to initialize Firebase. Keeping this outside `firebase_options.dart`
/// means a normal `flutterfire configure` regeneration cannot remove the gate.
bool hasUsableFirebaseOptions(FirebaseOptions options) {
  final requiredValues = [
    options.apiKey,
    options.appId,
    options.messagingSenderId,
    options.projectId,
  ];
  return requiredValues.every((value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && !normalized.contains('placeholder');
  });
}
