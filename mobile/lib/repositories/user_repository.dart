import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/api_config.dart';

abstract class UserRepository {
  Future<void> sendOtp(String email);
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
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
  });
}

class RestUserRepository implements UserRepository {
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
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'displayName': ?displayName, 'avatarUrl': ?avatarUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not update your profile. Please try again.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
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
        throw Exception(
          error['message'] ?? 'Failed to send verification code.',
        );
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
}

class MockUserRepository implements UserRepository {
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
  Future<void> sendOtp(String email) async {
    // Simulate latency
    await Future.delayed(const Duration(milliseconds: 500));
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
}
