import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/doctor.dart';

class DoctorFilters {
  const DoctorFilters({
    this.specialty,
    this.departmentId,
    this.organizationId,
    this.district,
    this.area,
    this.q,
  });

  final String? specialty;
  final String? departmentId;
  final String? organizationId;
  final String? district;
  final String? area;
  final String? q;

  Map<String, dynamic> toQuery() => {
        'specialty': specialty,
        'departmentId': departmentId,
        'organizationId': organizationId,
        'district': district,
        'area': area,
        'q': q,
      };

  DoctorFilters copyWith({
    Object? specialty = _unset,
    Object? departmentId = _unset,
    Object? organizationId = _unset,
    Object? district = _unset,
    Object? area = _unset,
    Object? q = _unset,
  }) =>
      DoctorFilters(
        specialty: specialty == _unset ? this.specialty : specialty as String?,
        departmentId: departmentId == _unset ? this.departmentId : departmentId as String?,
        organizationId:
            organizationId == _unset ? this.organizationId : organizationId as String?,
        district: district == _unset ? this.district : district as String?,
        area: area == _unset ? this.area : area as String?,
        q: q == _unset ? this.q : q as String?,
      );

  bool get hasActiveFilters =>
      departmentId != null ||
      organizationId != null ||
      district != null ||
      area != null ||
      (q != null && q!.isNotEmpty);

  static const _unset = Object();
}

class DoctorRepository {
  const DoctorRepository(this._api);

  final ApiClient _api;

  Future<List<DoctorSummary>> list(DoctorFilters filters, {bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/doctors',
      query: filters.toQuery(),
      cacheTtl: CacheTtl.feed,
      forceRefresh: forceRefresh,
    );
    return parseList(body, DoctorSummary.fromJson);
  }

  Future<DoctorDetail> detail(String id) async {
    final body = await _api.get('/api/doctors/$id');
    return DoctorDetail.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  /// Toggles the like; returns the new state and count.
  Future<({bool liked, int likeCount})> toggleLike(String id) async {
    final body = await _api.post('/api/doctors/$id/like');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (liked: map.flag('liked'), likeCount: map.intOr('likeCount'));
  }

  Future<List<AvailableDate>> availability({
    required String doctorId,
    required String chamberId,
    int days = 30,
  }) async {
    final body = await _api.get(
      '/api/doctors/$doctorId/chambers/$chamberId/availability',
      query: {'days': days},
    );
    return parseList(body, AvailableDate.fromJson);
  }

  /// Books a serial. The server re-checks availability, so a date that was
  /// taken while the wizard was open fails with `date_unavailable`.
  Future<String> bookSerial({
    required String chamberId,
    required String date,
    required String patientName,
    required String patientPhone,
    int? patientAge,
    String? patientGender,
    String? note,
  }) async {
    final body = await _api.post('/api/serials', body: {
      'chamberId': chamberId,
      'date': date,
      'patientName': patientName,
      'patientPhone': patientPhone,
      if (patientAge != null) 'patientAge': patientAge,
      if (patientGender != null) 'patientGender': patientGender,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return body is Map<String, dynamic> ? body.str('id') : '';
  }

  Future<List<Serial>> myAppointments() async {
    final body = await _api.get('/api/me/serials');
    return parseList(body, Serial.fromJson);
  }

  Future<void> cancelAppointment(String id) =>
      _api.post('/api/me/serials/$id/cancel');

  Future<List<String>> likedDoctorIds() async {
    final body = await _api.get('/api/me/doctor-likes');
    return body is List ? body.map((e) => e.toString()).toList() : const [];
  }
}
