import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Default deployed Render production/staging server URL
  static const String remoteBaseUrl = 'https://kiwishare.onrender.com';

  /// Custom base URL passed at build/run time via:
  /// `--dart-define=API_BASE_URL=https://kiwishare.onrender.com` or `--dart-define=API_BASE_URL=local`
  static const String _customBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resolves the Koa backend server URL dynamically depending on platform and configuration
  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      if (_customBaseUrl == 'local') {
        return localBaseUrl;
      }
      return _customBaseUrl.endsWith('/')
          ? _customBaseUrl.substring(0, _customBaseUrl.length - 1)
          : _customBaseUrl;
    }
    return remoteBaseUrl;
  }

  /// Resolves the local development server URL depending on platform
  static String get localBaseUrl {
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
  static String get loginUrl => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
}
