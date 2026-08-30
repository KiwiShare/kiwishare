import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final UserRepository userRepository;

  AuthProvider({required this.userRepository, this.pushNotifications}) {
    _loadSession();
  }

  final PushNotificationSession? pushNotifications;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoggingIn = false;
  bool get isLoggingIn => _isLoggingIn;

  String? _jwtToken;
  String? get jwtToken => _jwtToken;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _jwtToken = prefs.getString('jwt_token');
      final userJson = prefs.getString('current_user');
      if (_jwtToken != null && userJson != null) {
        _currentUser = UserModel.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        _isLoggedIn = true;
        notifyListeners();
        unawaited(
          pushNotifications?.activate(_jwtToken!, userId: _currentUser!.id) ??
              Future.value(),
        );
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

  Future<void> login(String email, String password) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final result = await userRepository.loginWithPassword(
        email: email,
        password: password,
      );
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
      unawaited(
        pushNotifications?.activate(token, userId: user.id) ?? Future.value(),
      );
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final result = await userRepository.registerWithPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
      unawaited(
        pushNotifications?.activate(token, userId: user.id) ?? Future.value(),
      );
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> sendOtp(String email) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      await userRepository.sendOtp(email);
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(
    String email,
    String code, {
    String? displayName,
  }) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final result = await userRepository.verifyOtp(
        email,
        code,
        displayName: displayName,
      );
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
      unawaited(
        pushNotifications?.activate(token, userId: user.id) ?? Future.value(),
      );
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoggingIn = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-in failed: Could not retrieve ID Token.');
      }

      final result = await userRepository.loginWithGoogle(idToken);
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
      unawaited(
        pushNotifications?.activate(token, userId: user.id) ?? Future.value(),
      );
    } catch (e) {
      debugPrint('Google Login Provider Error: $e');
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await clearSession();

    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> clearSession() async {
    final token = _jwtToken;
    final pushDeactivation = token == null
        ? null
        : pushNotifications?.deactivate(token);
    _isLoggedIn = false;
    _currentUser = null;
    _jwtToken = null;
    // Account-scoped providers must stop exposing the previous session before
    // storage and push-token cleanup, which may take an arbitrary amount of
    // time.
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('current_user');
    if (pushDeactivation != null) await pushDeactivation;
  }

  Future<void> updateDisplayName(String value) async {
    final name = value.trim();
    if (name.length < 2 || name.length > 30) {
      throw ArgumentError('Name must be between 2 and 30 characters.');
    }
    final token = _jwtToken;
    if (!_isLoggedIn || token == null) {
      throw StateError('Please log in to edit your profile.');
    }
    final updated = await userRepository.updateProfile(
      token: token,
      displayName: name,
    );
    _currentUser = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(updated.toJson()));
    notifyListeners();
  }
}
