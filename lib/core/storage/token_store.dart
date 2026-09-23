import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bearer token the backend issues at login. It is kept in the platform
/// keystore rather than in plain preferences, and mirrored in memory so the
/// request interceptor never has to await a platform channel.
class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  static const _key = 'cht_plus_auth_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cached;
  bool _loaded = false;

  String? get token => _cached;
  bool get hasToken => _cached != null && _cached!.isNotEmpty;

  Future<String?> load() async {
    if (_loaded) return _cached;
    try {
      _cached = await _storage.read(key: _key);
    } catch (_) {
      // A keystore that cannot be read (wiped app data, restored backup) is
      // treated as "signed out" rather than crashing startup.
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    _loaded = true;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Keeping the in-memory copy still gets the user through this session.
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // ignore
    }
  }
}
