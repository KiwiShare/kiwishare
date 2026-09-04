import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Predefined client-side Feature Flags for the KiwiShare mobile app.
enum FeatureFlag {
  /// Toggle AI-powered semantic search & recommendation filter
  aiSearch('feature_enable_ai_search', defaultValue: false),

  /// Toggle door-to-door courier delivery filter & options
  itemDelivery('feature_enable_item_delivery', defaultValue: false),

  /// Toggle one-click listing social media sharing action
  socialShare('feature_enable_social_share', defaultValue: true);

  final String key;
  final bool defaultValue;
  const FeatureFlag(this.key, {this.defaultValue = false});
}

/// Extensible Service to manage Firebase Remote Config and Feature Flags
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;

  /// In-app fallback defaults
  final Map<String, dynamic> _defaults = {
    FeatureFlag.aiSearch.key: FeatureFlag.aiSearch.defaultValue,
    FeatureFlag.itemDelivery.key: FeatureFlag.itemDelivery.defaultValue,
    FeatureFlag.socialShare.key: FeatureFlag.socialShare.defaultValue,
    'announcement_banner': jsonEncode({
      'enabled': false,
      'message': 'Welcome to KiwiShare! Buy, Sell, Share, Sustain.',
      'type': 'info',
    }),
  };

  /// Initialize Firebase Remote Config with best-practice cache settings
  Future<void> initialize({
    Duration fetchTimeout = const Duration(seconds: 10),
    Duration? minimumFetchInterval,
  }) async {
    if (_isInitialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Debug mode uses 0-second fetch interval for immediate testing
      // Release mode defaults to 1-hour cache
      final interval =
          minimumFetchInterval ??
          (kDebugMode ? Duration.zero : const Duration(hours: 1));

      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: interval,
        ),
      );

      await _remoteConfig!.setDefaults(_defaults);
      await _remoteConfig!.fetchAndActivate();

      // Listen for real-time config updates if supported
      _remoteConfig!.onConfigUpdated.listen((event) async {
        debugPrint(
          '🔥 [RemoteConfig] Config updated for keys: ${event.updatedKeys}',
        );
        await _remoteConfig!.activate();
      });

      _isInitialized = true;
      debugPrint('✅ [RemoteConfig] Initialized successfully.');
    } catch (e) {
      debugPrint(
        '⚠️ [RemoteConfig] Failed to initialize: $e (Falling back to in-app defaults)',
      );
    }
  }

  /// Extensible Feature Flag evaluation: should(FeatureFlag.aiSearch) or should('custom_flag')
  bool should(dynamic flagOrKey, {bool? defaultValue}) {
    if (flagOrKey is FeatureFlag) {
      if (_remoteConfig == null || !_isInitialized) {
        return defaultValue ?? flagOrKey.defaultValue;
      }
      return _remoteConfig!.getBool(flagOrKey.key);
    } else if (flagOrKey is String) {
      if (_remoteConfig == null || !_isInitialized) {
        return defaultValue ?? (_defaults[flagOrKey] as bool? ?? false);
      }
      return _remoteConfig!.getBool(flagOrKey);
    }

    return defaultValue ?? false;
  }

  /// Get String configuration with fallback
  String getString(String key, {String? defaultValue}) {
    if (_remoteConfig == null || !_isInitialized) {
      return defaultValue ?? (_defaults[key]?.toString() ?? '');
    }
    final value = _remoteConfig!.getString(key);
    return value.isNotEmpty
        ? value
        : (defaultValue ?? (_defaults[key]?.toString() ?? ''));
  }

  /// Get Integer configuration with fallback
  int getInt(String key, {int? defaultValue}) {
    if (_remoteConfig == null || !_isInitialized) {
      return defaultValue ?? (_defaults[key] as int? ?? 0);
    }
    return _remoteConfig!.getInt(key);
  }

  /// Get parsed JSON configuration with fallback
  Map<String, dynamic> getJson(
    String key, {
    Map<String, dynamic>? defaultValue,
  }) {
    final rawString = getString(key);
    if (rawString.isEmpty) return defaultValue ?? {};
    try {
      final decoded = jsonDecode(rawString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ [RemoteConfig] Error parsing JSON for key "$key": $e');
    }
    return defaultValue ?? {};
  }
}

/// Global, developer-friendly top-level helper function:
/// Usage:
/// ```dart
/// if (should(FeatureFlag.aiSearch)) { ... }
/// if (should('any_new_experiment_toggle')) { ... }
/// ```
bool should(dynamic flagOrKey, {bool? defaultValue}) =>
    RemoteConfigService.instance.should(flagOrKey, defaultValue: defaultValue);
