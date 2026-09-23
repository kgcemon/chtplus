import 'dart:convert';

import '../storage/prefs.dart';

/// A tiny disk cache for GET responses, keyed by path + query.
///
/// It exists so reference data the site barely changes (categories, districts,
/// banners) renders instantly on a cold start while the network copy is fetched
/// in the background, instead of showing a spinner every time.
class ResponseCache {
  const ResponseCache._();

  static const cache = ResponseCache._();

  static String keyFor(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return path;
    final parts = query.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    return '$path?${parts.join('&')}';
  }

  /// Returns the cached body, or null when absent or older than [ttl].
  dynamic read(String key, Duration ttl) {
    final entry = Prefs.instance.getJson('${PrefKeys.httpCachePrefix}$key');
    if (entry == null) return null;
    final savedAt = entry['at'];
    if (savedAt is! int) return null;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (age > ttl.inMilliseconds) return null;
    final body = entry['body'];
    if (body is! String) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached body whatever its age — used as a last resort when the
  /// network fails, so the screen shows something rather than an error.
  dynamic readStale(String key) {
    final entry = Prefs.instance.getJson('${PrefKeys.httpCachePrefix}$key');
    final body = entry?['body'];
    if (body is! String) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, dynamic body) async {
    try {
      await Prefs.instance.setJson('${PrefKeys.httpCachePrefix}$key', {
        'at': DateTime.now().millisecondsSinceEpoch,
        'body': jsonEncode(body),
      });
    } catch (_) {
      // A body that will not encode simply is not cached.
    }
  }

  /// Drops everything. Called on sign-out so the next account never sees the
  /// previous one's cached lists.
  Future<void> clear() async {
    final keys = Prefs.instance.keysWithPrefix(PrefKeys.httpCachePrefix).toList();
    for (final key in keys) {
      await Prefs.instance.remove(key);
    }
  }
}

class CacheTtl {
  const CacheTtl._();

  /// Categories, districts, departments — effectively static.
  static const reference = Duration(hours: 12);

  /// `/api/app-config`: the Google client id and OneSignal app id. Admins
  /// change these to fix sign-in or push, and a stale copy keeps the app
  /// broken until it expires — so it is re-checked often. The body is tiny,
  /// and a cached copy is still used when the network is down.
  static const config = Duration(minutes: 15);

  /// Home feed, listings — fresh enough to feel live, cached enough to be instant.
  static const feed = Duration(minutes: 5);

  /// Banners and popups.
  static const promo = Duration(hours: 2);
}
