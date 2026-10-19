import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/storage/prefs.dart';
import '../core/storage/token_store.dart';
import '../core/utils/json.dart';
import '../models/user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> login({required String email, required String password}) async {
    final body = await _api.post('/api/auth/login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return _persist(body);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? area,
    String? referralCode,
  }) async {
    final code = cleanReferralCode(referralCode);
    final body = await _api.post('/api/auth/register', body: {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (area != null && area.trim().isNotEmpty) 'area': area.trim(),
      if (code.isNotEmpty) 'referralCode': code,
    });
    await clearPendingReferralCode();
    return _persist(body);
  }

  /// Exchanges a Google ID token for a CHT Plus session. A Refer & Win code
  /// from an opened invite link goes along; the server only uses it when this
  /// creates a new account.
  Future<AuthResult> googleSignIn(String credential) async {
    final code = pendingReferralCode();
    final body = await _api.post('/api/auth/google', body: {
      'credential': credential,
      if (code.isNotEmpty) 'referralCode': code,
    });
    await clearPendingReferralCode();
    return _persist(body);
  }

  // --- Refer & Win invite code -------------------------------------------

  static String cleanReferralCode(String? value) {
    final code = (value ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return code.length > 12 ? code.substring(0, 12) : code;
  }

  String pendingReferralCode() =>
      cleanReferralCode(Prefs.instance.getString(PrefKeys.pendingReferralCode));

  Future<void> savePendingReferralCode(String code) async {
    final cleaned = cleanReferralCode(code);
    if (cleaned.isNotEmpty) await Prefs.instance.setString(PrefKeys.pendingReferralCode, cleaned);
  }

  Future<void> clearPendingReferralCode() => Prefs.instance.remove(PrefKeys.pendingReferralCode);

  /// Always succeeds, whether or not the email is registered — the server
  /// deliberately does not reveal which addresses exist.
  Future<void> requestPasswordReset(String email) async {
    await _api.post('/api/auth/forgot-password', body: {
      'email': email.trim().toLowerCase(),
    });
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final body = await _api.post('/api/auth/reset-password', body: {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
    return _persist(body);
  }

  Future<void> signOut() async {
    await TokenStore.instance.clear();
    await Prefs.instance.remove(PrefKeys.cachedUser);
    // Personal lists (my listings, chat, notifications) must not survive into
    // the next account signed in on this device.
    await ResponseCache.cache.clear();
  }

  /// The last known user, shown immediately at startup while `/api/me`
  /// refreshes in the background.
  AuthUser? cachedUser() {
    final json = Prefs.instance.getJson(PrefKeys.cachedUser);
    return json == null ? null : AuthUser.fromJson(json);
  }

  Future<void> cacheUser(AuthUser user) =>
      Prefs.instance.setJson(PrefKeys.cachedUser, user.toJson());

  Future<AuthResult> _persist(dynamic body) async {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final token = map.str('token');
    final user = AuthUser.fromJson(map.mapOrNull('user') ?? const {});
    if (token.isNotEmpty) await TokenStore.instance.save(token);
    await cacheUser(user);
    return AuthResult(token: token, user: user);
  }
}
