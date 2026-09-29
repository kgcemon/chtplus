import '../core/api/api_client.dart';
import '../core/utils/json.dart';

/// What a report can point at — the same values the server accepts.
enum ReportTarget {
  user('user'),
  service('service'),
  donor('donor'),
  listing('marketplace_listing'),
  biodata('biodata'),
  review('review'),
  chat('chat');

  const ReportTarget(this.apiValue);
  final String apiValue;
}

/// Why something is being reported. Keys match `REPORT_REASONS` on the server.
const reportReasons = <String, String>{
  'spam': 'Spam or scam',
  'fake': 'Fake or misleading',
  'harassment': 'Harassment or hate',
  'sexual': 'Sexual or inappropriate content',
  'violence': 'Violence or dangerous content',
  'illegal': 'Illegal item or activity',
  'other': 'Something else',
};

class BlockedUser {
  const BlockedUser({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: json.str('id'),
        name: json.str('name'),
        photoUrl: json.strOrNull('photoUrl'),
      );
}

/// Reporting objectionable content and blocking users.
class ModerationRepository {
  const ModerationRepository(this._api);

  final ApiClient _api;

  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required String reason,
    String? details,
  }) =>
      _api.post('/api/reports', body: {
        'targetType': target.apiValue,
        'targetId': targetId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      });

  Future<bool> isBlocked(String userId) async {
    final body = await _api.get('/api/users/$userId/block');
    return body is Map<String, dynamic> && body['blocked'] == true;
  }

  Future<void> block(String userId) => _api.post('/api/users/$userId/block');

  Future<void> unblock(String userId) => _api.delete('/api/users/$userId/block');

  Future<List<BlockedUser>> blocked() async {
    final body = await _api.get('/api/me/blocks');
    return parseList(body, BlockedUser.fromJson);
  }
}
