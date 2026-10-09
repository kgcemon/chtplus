import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/donor.dart';

class DonorFilters {
  const DonorFilters({
    this.bloodGroup,
    this.district,
    this.area,
    this.availableOnly = false,
  });

  final String? bloodGroup;
  final String? district;
  final String? area;
  final bool availableOnly;

  Map<String, dynamic> toQuery() => {
        'bloodGroup': bloodGroup,
        'district': district,
        'area': area,
        if (availableOnly) 'availableOnly': 'true',
      };

  DonorFilters copyWith({
    Object? bloodGroup = _unset,
    Object? district = _unset,
    Object? area = _unset,
    bool? availableOnly,
  }) =>
      DonorFilters(
        bloodGroup: bloodGroup == _unset ? this.bloodGroup : bloodGroup as String?,
        district: district == _unset ? this.district : district as String?,
        area: area == _unset ? this.area : area as String?,
        availableOnly: availableOnly ?? this.availableOnly,
      );

  bool get hasActiveFilters =>
      bloodGroup != null || district != null || area != null || availableOnly;

  static const _unset = Object();
}

class DonorRepository {
  const DonorRepository(this._api);

  final ApiClient _api;

  Future<List<Donor>> list(DonorFilters filters, {bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/donors',
      query: filters.toQuery(),
      cacheTtl: CacheTtl.feed,
      forceRefresh: forceRefresh,
    );
    return parseList(body, Donor.fromJson);
  }

  Future<Donor> detail(String id) async {
    final body = await _api.get('/api/donors/$id');
    return Donor.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  /// Creates the signed-in user's donor profile, or updates it if one exists —
  /// the endpoint handles both.
  Future<String> saveMyProfile({
    required String name,
    required String bloodGroup,
    required String phone,
    required String area,
    String? district,
    String? lastDonationDate,
    String? photoUrl,
  }) async {
    final body = await _api.post('/api/donors', body: {
      'name': name,
      'bloodGroup': bloodGroup,
      'phone': phone,
      'area': area,
      if (district != null && district.isNotEmpty) 'district': district,
      if (lastDonationDate != null && lastDonationDate.isNotEmpty)
        'lastDonationDate': lastDonationDate,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return body is Map<String, dynamic> ? body.str('id') : '';
  }

  Future<({bool liked, int likeCount})> toggleLike(String id) async {
    final body = await _api.post('/api/donors/$id/like');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (liked: map.flag('liked'), likeCount: map.intOr('likeCount'));
  }

  /// Names of the people who sent this donor a love reaction, newest first.
  /// Who loved a donor, newest first, as (name, has blue tick) pairs.
  Future<List<({String name, bool blueBadge})>> likers(String id) async {
    final body = await _api.get('/api/donors/$id/likes?withBadge=1');
    if (body is! List) return const [];
    return [
      for (final e in body)
        if (e is Map<String, dynamic>)
          (name: e.str('name'), blueBadge: e.flag('blueBadge'))
        else
          (name: e.toString(), blueBadge: false),
    ];
  }

  Future<List<String>> likedDonorIds() async {
    final body = await _api.get('/api/me/donor-likes');
    return body is List ? body.map((e) => e.toString()).toList() : const [];
  }
}
