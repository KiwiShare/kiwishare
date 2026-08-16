import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Custom base URL passed at build/run time via:
  /// `--dart-define=API_BASE_URL=http://<YOUR_IP>:3000`
  static const String _customBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resolves the Koa backend server URL dynamically depending on platform
  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator loopback interface address
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://localhost:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  static String get sendOtpUrl => '$baseUrl/api/auth/send-otp';
  static String get verifyOtpUrl => '$baseUrl/api/auth/verify-otp';
  static String get googleAuthUrl => '$baseUrl/api/auth/google';
}
