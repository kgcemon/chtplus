import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/service.dart';

class ServiceFilters {
  const ServiceFilters({
    this.categoryId,
    this.district,
    this.area,
    this.search,
    this.paidOnly = false,
  });

  final String? categoryId;
  final String? district;
  final String? area;
  final String? search;
  final bool paidOnly;

  Map<String, dynamic> toQuery() => {
        'categoryId': categoryId,
        'district': district,
        'area': area,
        'search': search,
        if (paidOnly) 'paidOnly': 'true',
      };

  ServiceFilters copyWith({
    Object? categoryId = _unset,
    Object? district = _unset,
    Object? area = _unset,
    Object? search = _unset,
    bool? paidOnly,
  }) =>
      ServiceFilters(
        categoryId: categoryId == _unset ? this.categoryId : categoryId as String?,
        district: district == _unset ? this.district : district as String?,
        area: area == _unset ? this.area : area as String?,
        search: search == _unset ? this.search : search as String?,
        paidOnly: paidOnly ?? this.paidOnly,
      );

  bool get hasActiveFilters =>
      categoryId != null ||
      district != null ||
      area != null ||
      (search != null && search!.isNotEmpty) ||
      paidOnly;

  static const _unset = Object();
}

class ServiceRepository {
  const ServiceRepository(this._api);

  final ApiClient _api;

  Future<List<ServiceItem>> list(ServiceFilters filters, {bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/services',
      query: filters.toQuery(),
      cacheTtl: CacheTtl.feed,
      forceRefresh: forceRefresh,
    );
    return parseList(body, ServiceItem.fromJson);
  }

  Future<ServiceItem> detail(String id) async {
    final body = await _api.get('/api/services/$id');
    return ServiceItem.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<List<ServiceItem>> mine() async {
    final body = await _api.get('/api/me/services');
    return parseList(body, ServiceItem.fromJson);
  }

  /// Creates a service. It lands as `pending` and appears publicly once an
  /// admin approves it.
  Future<String> create({
    required String categoryId,
    required String providerName,
    required String description,
    required String district,
    required String area,
    required String phone,
    List<String> photoPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'categoryId': categoryId,
      'providerName': providerName,
      'description': description,
      'district': district,
      'area': area,
      'phone': phone,
    });
    for (final path in photoPaths.take(2)) {
      form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    final body = await _api.upload('/api/services', form);
    return body is Map<String, dynamic> ? body.str('id') : '';
  }

  Future<void> update({
    required String id,
    required String categoryId,
    required String providerName,
    required String description,
    required String district,
    required String area,
    required String phone,
    List<String> keepPhotoUrls = const [],
    List<String> newPhotoPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'categoryId': categoryId,
      'providerName': providerName,
      'description': description,
      'district': district,
      'area': area,
      'phone': phone,
      'keepPhotoUrls': jsonEncode(keepPhotoUrls),
    });
    for (final path in newPhotoPaths) {
      form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    await _api.upload('/api/services/$id', form, method: 'PATCH');
  }

  Future<void> delete(String id) => _api.delete('/api/services/$id');

  /// Spends coins to boost a service to the top of the listings.
  Future<Map<String, dynamic>> sponsor({
    required String id,
    required String packageId,
  }) async {
    final body = await _api.post(
      '/api/services/$id/sponsor',
      body: {'packageId': packageId},
    );
    return body is Map<String, dynamic> ? body : const {};
  }
}
