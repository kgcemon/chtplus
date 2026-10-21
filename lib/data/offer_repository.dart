import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/utils/json.dart';
import '../models/offer.dart';

/// Partner offers (`/api/offers…`). Errors come back as ApiException codes
/// such as limit_reached, cooldown, sold_out, not_partner, code_not_found.
class OfferRepository {
  const OfferRepository(this._api);

  final ApiClient _api;

  Future<({List<Offer> offers, List<String> categories})> list({String q = '', String category = ''}) async {
    final body = await _api.get('/api/offers', query: {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (category.isNotEmpty) 'category': category,
    });
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (offers: parseList(map['offers'], Offer.fromJson), categories: map.stringList('categories'));
  }

  Future<OfferDetail> detail(String id) async {
    final body = await _api.get('/api/offers/$id');
    return OfferDetail.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  /// "Get offer": the user's code (their unused one, or a new one).
  Future<OfferClaim> claim(String id) async {
    final body = await _api.post('/api/offers/$id/claim');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return OfferClaim.fromJson(map.mapOrNull('claim') ?? const {});
  }

  Future<List<OfferClaim>> myClaims() async {
    final body = await _api.get('/api/me/offer-claims');
    return parseList(body, OfferClaim.fromJson);
  }

  // --- partner -------------------------------------------------------------

  Future<PartnerState> partner() async {
    final body = await _api.get('/api/me/offer-partner');
    return PartnerState.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<void> applyAsPartner(Map<String, String> fields, {String? logoPath}) async {
    final form = FormData.fromMap({
      ...fields,
      if (logoPath != null) 'logo': await MultipartFile.fromFile(logoPath),
    });
    await _api.upload('/api/me/offer-partner', form);
  }

  /// Creates an offer, or edits it when [id] is set.
  Future<void> save(Map<String, String> fields, {String? id, String? photoPath}) async {
    final form = FormData.fromMap({
      ...fields,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });
    await _api.upload(id == null ? '/api/offers' : '/api/offers/$id', form, method: id == null ? 'POST' : 'PUT');
  }

  Future<void> setStatus(String id, String status) => _api.post('/api/offers/$id/status', body: {'status': status});

  /// Looks a customer's code up; with [redeem] marks it used.
  Future<CodeCheck?> verify(String code, {bool redeem = false}) async {
    final body = await _api.post('/api/me/offer-partner/verify', body: {'code': code, 'redeem': redeem});
    return body is Map<String, dynamic> ? CodeCheck.fromJson(body) : null;
  }
}
