import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Resolves the Koa backend server URL dynamically depending on platform
  static String get baseUrl {
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
