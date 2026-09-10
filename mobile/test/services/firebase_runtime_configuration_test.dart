import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/services/firebase_runtime_configuration.dart';

void main() {
  test('placeholder FlutterFire options disable Firebase safely', () {
    const options = FirebaseOptions(
      apiKey: 'placeholder-api-key',
      appId: 'placeholder-app-id',
      messagingSenderId: 'placeholder-sender-id',
      projectId: 'placeholder-project-id',
    );

    expect(hasUsableFirebaseOptions(options), isFalse);
  });

  test(
    'complete non-placeholder FlutterFire options enable initialization',
    () {
      const options = FirebaseOptions(
        apiKey: 'test-api-key-not-a-real-credential',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project-id',
      );

      expect(hasUsableFirebaseOptions(options), isTrue);
    },
  );
}
