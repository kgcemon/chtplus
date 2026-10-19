import 'dart:async';

import '../core/api/api_client.dart';

/// 👁 View counts on cards (`/api/views`, see the site's lib/views.js).
///
/// Every card asks for its own number, but the asks of one type that arrive
/// together are sent as a single request, so a screen of 20 cards costs one
/// call per type, not 20.
class ViewsRepository {
  ViewsRepository(this._api);

  final ApiClient _api;
  final Map<String, Map<String, List<Completer<int>>>> _pending = {};
  Timer? _flushTimer;

  /// type: service · donor · listing · biodata
  Future<int> count(String type, String id) {
    final completer = Completer<int>();
    _pending.putIfAbsent(type, () => {}).putIfAbsent(id, () => []).add(completer);
    _flushTimer ??= Timer(const Duration(milliseconds: 40), _flush);
    return completer.future;
  }

  Future<void> _flush() async {
    _flushTimer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    for (final entry in batch.entries) {
      final type = entry.key;
      final ids = entry.value.keys.toList();
      for (var i = 0; i < ids.length; i += 100) {
        final chunk = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
        Map<String, dynamic> counts = const {};
        try {
          final body = await _api.get('/api/views', query: {'type': type, 'ids': chunk.join(',')});
          if (body is Map<String, dynamic>) counts = body;
        } catch (_) {
          // Offline: the cards show 0 rather than an error.
        }
        for (final id in chunk) {
          final value = counts[id];
          final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
          for (final c in entry.value[id]!) {
            if (!c.isCompleted) c.complete(n);
          }
        }
      }
    }
  }

  /// Someone opened the item. The server counts each person once a day per
  /// item, and never the owner. Returns the new total.
  Future<int?> record(String type, String id) async {
    try {
      final body = await _api.post('/api/views', body: {'type': type, 'id': id});
      if (body is Map<String, dynamic>) {
        final value = body['count'];
        return value is num ? value.toInt() : null;
      }
    } catch (_) {
      // Not worth bothering the user about.
    }
    return null;
  }
}
