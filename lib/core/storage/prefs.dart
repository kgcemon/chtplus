import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value store for non-secret local state: the cached user, the
/// welcome-popup dismissal, the onboarding flag and the HTTP response cache.
class Prefs {
  Prefs._(this._prefs);

  final SharedPreferences _prefs;
  static Prefs? _instance;

  static Prefs get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('Prefs.init() must be awaited before use.');
    }
    return value;
  }

  static Future<Prefs> init() async {
    final value = _instance;
    if (value != null) return value;
    final created = Prefs._(await SharedPreferences.getInstance());
    _instance = created;
    return created;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) => _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Iterable<String> keysWithPrefix(String prefix) =>
      _prefs.getKeys().where((k) => k.startsWith(prefix));
}

class PrefKeys {
  const PrefKeys._();
  static const cachedUser = 'cached_user';
  static const onboardingSeen = 'onboarding_seen';
  static const welcomePopupSeenAt = 'welcome_popup_seen_at';
  static const chatNoticeSeen = 'chat_notice_seen';
  static const httpCachePrefix = 'http_cache:';
}
