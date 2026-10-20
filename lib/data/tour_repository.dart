import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/utils/json.dart';
import '../models/tour.dart';

/// Group tours (`/api/tours…`). Errors come back as ApiException codes such
/// as not_enough_seats, already_requested, own_tour, not_organizer.
class TourRepository {
  const TourRepository(this._api);

  final ApiClient _api;

  Future<List<Tour>> list({String q = ''}) async {
    final body = await _api.get('/api/tours', query: {if (q.trim().isNotEmpty) 'q': q.trim()});
    return parseList(body, Tour.fromJson);
  }

  Future<TourDetail> detail(String id) async {
    final body = await _api.get('/api/tours/$id');
    return TourDetail.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<void> join(String id, {required int seats, required String phone, String? note}) =>
      _api.post('/api/tours/$id/join', body: {'seats': seats, 'phone': phone, if (note != null) 'note': note});

  Future<void> cancelMyBooking(String id) => _api.delete('/api/tours/$id/join');

  Future<void> decide(String id, int bookingId, {required bool accept}) =>
      _api.post('/api/tours/$id/bookings/$bookingId', body: {'action': accept ? 'accept' : 'reject'});

  Future<void> cancelTour(String id) => _api.post('/api/tours/$id/cancel');

  Future<List<Tour>> myTrips() async {
    final body = await _api.get('/api/me/tour-bookings');
    return parseList(body, Tour.fromJson);
  }

  Future<OrganizerState> organizer() async {
    final body = await _api.get('/api/me/tour-organizer');
    return OrganizerState.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<void> applyAsOrganizer({required String orgName, required String phone, String? link, required String about}) =>
      _api.post('/api/me/tour-organizer', body: {
        'orgName': orgName,
        'phone': phone,
        if (link != null && link.isNotEmpty) 'link': link,
        'about': about,
      });

  /// Returns the new tour's status: "approved" (live) or "pending".
  Future<String> create(Map<String, String> fields, {String? photoPath}) async {
    final form = FormData.fromMap({
      ...fields,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    final body = await _api.upload('/api/tours', form);
    return body is Map<String, dynamic> ? body.str('status', fallback: 'pending') : 'pending';
  }
}
