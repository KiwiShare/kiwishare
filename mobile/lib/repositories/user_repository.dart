import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/api_config.dart';

class UserAuthenticationException implements Exception {
  const UserAuthenticationException([
    this.message = 'Your session has expired. Please sign in again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class UserNetworkException implements Exception {
  const UserNetworkException([
    this.message = 'Could not connect to the server. Check your connection.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OtpCooldownException implements Exception {
  const OtpCooldownException(this.message, {this.cooldownSeconds = 60});

  final String message;
  final int cooldownSeconds;

  @override
  String toString() => message;
}

abstract class UserRepository {
  Future<void> sendOtp(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    String? displayName,
  });
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  });
  Future<Map<String, dynamic>> registerWithPassword({
    required String email,
    required String password,
    required String displayName,
  });
  Future<Map<String, dynamic>> loginWithGoogle(String idToken);
  Future<UserModel> fetchProfile(String token);
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
  });
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  });
  Future<String> sendStudentVerificationOtp({
    required String email,
    required String token,
  });
  Future<UserModel> verifyStudentOtp({
    required String email,
    required String code,
    required String token,
  });
}

class RestUserRepository implements UserRepository {
  RestUserRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<UserModel> fetchProfile(String token) async {
    late final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      throw const UserNetworkException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UserAuthenticationException();
    }
    if (response.statusCode != 200) {
      throw const UserRepositoryException(
        'Profile is temporarily unavailable. Try again later.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'platform': 'mobile',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return {'token': token, 'user': user};
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(
          error['message'] ?? 'Login failed. Please check your credentials.',
        );
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Login failed. Please check your credentials.');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> registerWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.registerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'displayName': displayName.trim(),
        'platform': 'mobile',
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return {'token': token, 'user': user};
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed.');
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Registration failed.');
      }
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
  }) async {
    late final http.Response response;
    try {
      response = await _client.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'displayName': ?displayName,
          'avatarUrl': ?avatarUrl,
        }),
      );
    } catch (_) {
      throw const UserNetworkException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UserAuthenticationException();
    }
    if (response.statusCode != 200) {
      throw const UserRepositoryException(
        'Could not update your profile. Please try again.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    late final http.Response response;
    try {
      response = await _client.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/users/me/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
    } catch (_) {
      throw const UserNetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    if (response.statusCode == 204) return;
    if (response.statusCode == 403) {
      throw const UserAuthenticationException();
    }
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 401) {
        final message = (error['message'] as String?) ?? '';
        if (message.toLowerCase().contains('authorization token') ||
            message.toLowerCase().contains('expired')) {
          throw const UserAuthenticationException();
        }
      }
      throw Exception(error['message'] ?? 'Could not change your password.');
    } catch (e) {
      if (e is Exception &&
          !e.toString().startsWith('Exception: FormatException')) {
        rethrow;
      }
      throw Exception('Could not change your password.');
    }
  }

  @override
  Future<void> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse(ApiConfig.sendOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );

    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        final message =
            (error['message'] as String?) ??
            'Failed to send verification code.';
        if (response.statusCode == 429) {
          final cooldown = (error['cooldownSeconds'] as num?)?.toInt() ?? 60;
          throw OtpCooldownException(message, cooldownSeconds: cooldown);
        }
        throw Exception(message);
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Failed to send verification code.');
      }
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.requestPasswordResetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );
    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        final message =
            (error['message'] as String?) ?? 'Failed to send reset code.';
        if (response.statusCode == 429) {
          final cooldown = (error['cooldownSeconds'] as num?)?.toInt() ?? 60;
          throw OtpCooldownException(message, cooldownSeconds: cooldown);
        }
        throw Exception(message);
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Failed to send reset code.');
      }
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.resetPasswordUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Could not reset your password.');
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Could not reset your password.');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    String? displayName,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
    }

    final response = await http.post(
      Uri.parse(ApiConfig.verifyOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return {'token': token, 'user': user};
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(
          error['message'] ?? 'Failed to verify verification code.',
        );
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Failed to verify verification code.');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse(ApiConfig.googleAuthUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return {'token': token, 'user': user};
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Google authentication failed.');
      } catch (e) {
        if (e is Exception &&
            !e.toString().startsWith('Exception: FormatException')) {
          rethrow;
        }
        throw Exception('Google authentication failed.');
      }
    }
  }

  @override
  Future<String> sendStudentVerificationOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users/student-verification/send-otp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (data['institution'] ?? 'NZ University').toString();
    } else {
      throw Exception(
        data['message'] ?? 'Failed to send student verification code.',
      );
    }
  }

  @override
  Future<UserModel> verifyStudentOtp({
    required String email,
    required String code,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/users/student-verification/verify-otp',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } else {
      throw Exception(data['message'] ?? 'Failed to verify student code.');
    }
  }
}

class MockUserRepository implements UserRepository {
  @override
  Future<UserModel> fetchProfile(String token) async => const UserModel(
    id: 'mock_user_1',
    displayName: 'Mock User',
    trustScore: 100,
    isVerified: false,
  );
  @override
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = UserModel(
      id: 'mock_user_1',
      displayName: email.split('@')[0],
      avatarUrl: null,
      trustScore: 100,
      isVerified: true,
    );
    return {'token': 'mock_jwt_token', 'user': user};
  }

  @override
  Future<Map<String, dynamic>> registerWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = UserModel(
      id: 'mock_user_1',
      displayName: displayName.trim().isNotEmpty
          ? displayName.trim()
          : email.split('@')[0],
      avatarUrl: null,
      trustScore: 100,
      isVerified: true,
    );
    return {'token': 'mock_jwt_token', 'user': user};
  }

  @override
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return UserModel(
      id: 'mock_user_1',
      displayName: displayName ?? 'Mock User',
      avatarUrl: avatarUrl,
      trustScore: 100,
      isVerified: false,
    );
  }

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> sendOtp(String email) async {
    // Simulate latency
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (code != '123456' && code != '888888') {
      throw Exception('Invalid or expired password reset code.');
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    String? displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (code == '123456' || code == '888888') {
      final user = UserModel(
        id: 'mock_user_1',
        displayName: (displayName != null && displayName.trim().isNotEmpty)
            ? displayName.trim()
            : email.split('@')[0],
        avatarUrl: null,
        trustScore: 100,
        isVerified: false,
      );
      return {'token': 'mock_jwt_token', 'user': user};
    }
    throw Exception('Invalid or expired verification code.');
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final user = UserModel(
      id: 'mock_google_uid_123',
      displayName: 'Google User',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
      trustScore: 100,
      isVerified: true,
    );
    return {'token': 'mock_jwt_token', 'user': user};
  }

  @override
  Future<String> sendStudentVerificationOtp({
    required String email,
    required String token,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!email.toLowerCase().endsWith('.ac.nz')) {
      throw Exception('Only NZ universities are supported.');
    }
    return 'University of Auckland';
  }

  @override
  Future<UserModel> verifyStudentOtp({
    required String email,
    required String code,
    required String token,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const UserModel(
      id: 'mock_user_1',
      displayName: 'Mock Student',
      trustScore: 100,
      isVerified: true,
      isStudentVerified: true,
      studentInstitution: 'University of Auckland',
    );
  }
}
