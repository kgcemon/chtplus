import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/utils/json.dart';
import '../models/engagement.dart';
import '../models/public_profile.dart';
import '../models/user.dart';

/// Everything under `/api/me`, plus the public profile and follow endpoints.
class MeRepository {
  const MeRepository(this._api);

  final ApiClient _api;

  Future<MeProfile> profile() async {
    final body = await _api.get('/api/me');
    return MeProfile.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<AuthUser> updateBasics({
    String? name,
    String? email,
    String? phone,
    String? area,
  }) async {
    final body = await _api.patch('/api/me', body: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (area != null) 'area': area,
    });
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return AuthUser.fromJson(map.mapOrNull('user') ?? const {});
  }

  Future<void> updateDetails({
    String? bio,
    String? currentCity,
    String? hometown,
    String? relationshipStatus,
  }) =>
      _api.post('/api/me/details', body: {
        'bio': bio ?? '',
        'currentCity': currentCity ?? '',
        'hometown': hometown ?? '',
        if (relationshipStatus != null) 'relationshipStatus': relationshipStatus,
      });

  /// `field` is one of currentCity / hometown / relationshipStatus,
  /// `privacy` one of public / followers / only_me.
  Future<void> updatePrivacy({required String field, required String privacy}) =>
      _api.post('/api/me/details/privacy', body: {'field': field, 'privacy': privacy});

  Future<String> uploadPhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final body = await _api.upload('/api/me/photo', form);
    return body is Map<String, dynamic> ? body.str('photoUrl') : '';
  }

  Future<String> uploadCoverPhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final body = await _api.upload('/api/me/cover-photo', form);
    return body is Map<String, dynamic> ? body.str('coverPhotoUrl') : '';
  }

  Future<void> saveHomeInterests(List<String> interests) =>
      _api.post('/api/me/home-preferences', body: {'interests': interests});

  // --- Work & education ---------------------------------------------------

  Future<WorkEntry> addWork({
    required String company,
    String? position,
    String? location,
    bool isCurrent = false,
    String? startDate,
    String? endDate,
  }) async {
    final body = await _api.post('/api/me/work', body: {
      'company': company,
      if (position != null) 'position': position,
      if (location != null) 'location': location,
      'isCurrent': isCurrent,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    });
    return WorkEntry.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<void> deleteWork(int id) => _api.delete('/api/me/work/$id');

  Future<EducationEntry> addEducation({
    required String institution,
    String level = 'university',
    String? fieldOfStudy,
    String? passingYear,
  }) async {
    final body = await _api.post('/api/me/education', body: {
      'institution': institution,
      'level': level,
      if (fieldOfStudy != null) 'fieldOfStudy': fieldOfStudy,
      if (passingYear != null) 'passingYear': passingYear,
    });
    return EducationEntry.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<void> deleteEducation(int id) => _api.delete('/api/me/education/$id');

  // --- Social -------------------------------------------------------------

  Future<PublicProfile> publicProfile(String userId) async {
    final body = await _api.get('/api/users/$userId');
    return PublicProfile.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<UserAbout> about(String userId) async {
    final body = await _api.get('/api/users/$userId/about');
    return UserAbout.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<bool> isFollowing(String userId) async {
    final body = await _api.get('/api/users/$userId/follow');
    return body is Map<String, dynamic> && body.flag('following');
  }

  Future<({bool following, int followerCount})> toggleFollow(String userId) async {
    final body = await _api.post('/api/users/$userId/follow');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (following: map.flag('following'), followerCount: map.intOr('followerCount'));
  }

  Future<FollowLists> follows() async {
    final body = await _api.get('/api/me/follows');
    return FollowLists.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  // --- Notifications ------------------------------------------------------

  Future<List<AppNotification>> notifications() async {
    final body = await _api.get('/api/me/notifications');
    return parseList(body, AppNotification.fromJson);
  }

  Future<void> markNotificationRead(int id) =>
      _api.post('/api/me/notifications/$id/read');

  Future<void> markAllNotificationsRead() =>
      _api.post('/api/me/notifications/read-all');

  // --- Saved items --------------------------------------------------------

  Future<List<SavedItem>> saved() async {
    final body = await _api.get('/api/saved');
    return parseList(body, SavedItem.fromJson);
  }

  /// Toggling is the server's behaviour: posting an already-saved item removes
  /// it. Returns the resulting state.
  Future<bool> toggleSaved({required String targetType, required String targetId}) async {
    final body = await _api.post('/api/saved', body: {
      'targetType': targetType,
      'targetId': targetId,
    });
    return body is Map<String, dynamic> && body.flag('saved');
  }

  // --- Reviews I wrote ----------------------------------------------------

  Future<List<Review>> myReviews() async {
    final body = await _api.get('/api/me/reviews');
    return parseList(body, Review.fromJson);
  }

  // --- Account ------------------------------------------------------------

  /// Play Store requires an in-app account deletion. The server anonymizes the
  /// account: login becomes impossible and personal fields are cleared.
  Future<void> deleteAccount() => _api.delete('/api/me/account');
}
