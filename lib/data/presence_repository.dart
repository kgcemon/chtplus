import 'dart:async';

import '../core/api/api_client.dart';

/// Who is online right now (`/api/presence`, see the site's lib/presence.js),
/// for the green dot on profile pictures. The questions for every dot on the
/// screen that arrive together go out as one request.
class PresenceRepository {
  PresenceRepository(this._api);

  final ApiClient _api;
  final Map<String, List<Completer<bool>>> _pending = {};
  Timer? _flushTimer;

  Future<bool> isOnline(String userId) {
    final completer = Completer<bool>();
    _pending.putIfAbsent(userId, () => []).add(completer);
    _flushTimer ??= Timer(const Duration(milliseconds: 40), _flush);
    return completer.future;
  }

  Future<void> _flush() async {
    _flushTimer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    final ids = batch.keys.toList();
    for (var i = 0; i < ids.length; i += 150) {
      final chunk = ids.sublist(i, i + 150 > ids.length ? ids.length : i + 150);
      var online = <String>{};
      try {
        final body = await _api.get('/api/presence', query: {'ids': chunk.join(',')});
        if (body is Map<String, dynamic> && body['online'] is List) {
          online = (body['online'] as List).map((e) => e.toString()).toSet();
        }
      } catch (_) {
        // Offline: no dots rather than an error.
      }
      for (final id in chunk) {
        for (final c in batch[id]!) {
          if (!c.isCompleted) c.complete(online.contains(id));
        }
      }
    }
  }
}
