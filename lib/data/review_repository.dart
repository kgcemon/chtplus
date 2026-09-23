import '../core/api/api_client.dart';
import '../core/utils/json.dart';
import '../models/engagement.dart';

/// Reviews attach to a service or a blood-donor profile. The route prefix
/// differs, so the target type picks it.
class ReviewRepository {
  const ReviewRepository(this._api);

  final ApiClient _api;

  String _base(String targetType, String targetId) =>
      targetType == 'donor'
          ? '/api/donors/$targetId/reviews'
          : '/api/services/$targetId/reviews';

  Future<List<Review>> list({
    required String targetType,
    required String targetId,
  }) async {
    final body = await _api.get(_base(targetType, targetId));
    return parseList(body, Review.fromJson);
  }

  /// Posting returns the refreshed list, so the caller does not need a second
  /// request.
  Future<List<Review>> create({
    required String targetType,
    required String targetId,
    required int rating,
    required String comment,
  }) async {
    final body = await _api.post(
      _base(targetType, targetId),
      body: {'rating': rating, 'comment': comment},
    );
    if (body is Map<String, dynamic>) {
      return parseList(body['reviews'], Review.fromJson);
    }
    return const [];
  }

  Future<({bool loved, int loveCount})> toggleLove(int reviewId) async {
    final body = await _api.post('/api/reviews/$reviewId/love');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (loved: map.flag('loved'), loveCount: map.intOr('loveCount'));
  }

  Future<List<ReviewReply>> replies(int reviewId) async {
    final body = await _api.get('/api/reviews/$reviewId/replies');
    return parseList(body, ReviewReply.fromJson);
  }

  Future<List<ReviewReply>> reply(int reviewId, String text) async {
    final body = await _api.post(
      '/api/reviews/$reviewId/replies',
      body: {'replyText': text},
    );
    // The route answers with either the refreshed list or a wrapper holding it.
    if (body is List) return parseList(body, ReviewReply.fromJson);
    if (body is Map<String, dynamic>) {
      return parseList(body['replies'], ReviewReply.fromJson);
    }
    return const [];
  }
}
