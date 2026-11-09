import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/mobile_app_settings.dart';

/// Loads the public store configuration used by the app before authentication.
class AppSettingsService {
  static const String _cacheKey = 'mobile_app_settings_v1';

  final ApiClient _apiClient;

  AppSettingsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Returns the last-known-good configuration, if one has been cached.
  Future<MobileAppSettings?> getCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_cacheKey);
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      return MobileAppSettings.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Fetches and stores the latest public configuration. Returns null on
  /// network/parse failure so callers can retain the cache or bundled defaults.
  Future<MobileAppSettings?> refreshSettings() async {
    try {
      final response = await _apiClient.get(ApiConfig.appSettings);
      final data = response['data'];
      if (response['success'] != true || data is! Map<String, dynamic>) {
        return null;
      }

      final settings = MobileAppSettings.fromApiData(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(settings.toJson()));
      return settings;
    } catch (_) {
      return null;
    }
  }

  /// Returns cached data first when present; callers can explicitly request a
  /// refresh when the app resumes or the user opens a relevant screen.
  Future<MobileAppSettings> loadSettings({bool forceRefresh = false}) async {
    final cached = await getCachedSettings();
    if (!forceRefresh && cached != null) return cached;
    return await refreshSettings() ?? cached ?? MobileAppSettings.defaults;
  }

  /// Backward-compatible convenience method for the login logo.
  Future<String?> getMobileAuthLogo() async {
    final settings = await loadSettings();
    return settings.authLogoUrl;
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {
      // Cache removal must not block logout or app startup.
    }
  }
}
