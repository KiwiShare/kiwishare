import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/api_config.dart';

abstract class UserRepository {
  Future<void> sendOtp(String email);
  Future<Map<String, dynamic>> verifyOtp(String email, String code);
  Future<Map<String, dynamic>> loginWithGoogle(String idToken);
}

class RestUserRepository implements UserRepository {
  @override
  Future<void> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse(ApiConfig.sendOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        throw Exception(
          error['message'] ?? 'Failed to send verification code.',
        );
      } catch (_) {
        throw Exception('Failed to send verification code.');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final response = await http.post(
      Uri.parse(ApiConfig.verifyOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
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
      } catch (_) {
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
      } catch (_) {
        throw Exception('Google authentication failed.');
      }
    }
  }
}

class MockUserRepository implements UserRepository {
  @override
  Future<void> sendOtp(String email) async {
    // Simulate latency
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (code == '123456' || code == '888888') {
      final user = UserModel(
        id: 'mock_user_1',
        displayName: email.split('@')[0],
        avatarUrl: null,
        trustScore: 100,
        isVerified: false,
      );
      return {'token': 'mock_jwt_token', 'user': user};
    }
    throw Exception('Invalid verification code.');
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
