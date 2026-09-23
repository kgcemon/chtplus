import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/listing.dart';

class ListingFilters {
  const ListingFilters({
    this.categoryId,
    this.condition,
    this.district,
    this.area,
    this.search,
    this.sort = ListingSort.newest,
  });

  final String? categoryId;
  final String? condition;
  final String? district;
  final String? area;
  final String? search;
  final ListingSort sort;

  Map<String, dynamic> toQuery() => {
        'categoryId': categoryId,
        'condition': condition,
        'district': district,
        'area': area,
        'search': search,
        if (sort.value.isNotEmpty) 'sort': sort.value,
      };

  ListingFilters copyWith({
    Object? categoryId = _unset,
    Object? condition = _unset,
    Object? district = _unset,
    Object? area = _unset,
    Object? search = _unset,
    ListingSort? sort,
  }) =>
      ListingFilters(
        categoryId: categoryId == _unset ? this.categoryId : categoryId as String?,
        condition: condition == _unset ? this.condition : condition as String?,
        district: district == _unset ? this.district : district as String?,
        area: area == _unset ? this.area : area as String?,
        search: search == _unset ? this.search : search as String?,
        sort: sort ?? this.sort,
      );

  bool get hasActiveFilters =>
      categoryId != null ||
      condition != null ||
      district != null ||
      area != null ||
      (search != null && search!.isNotEmpty) ||
      sort != ListingSort.newest;

  static const _unset = Object();
}

class MarketplaceRepository {
  const MarketplaceRepository(this._api);

  final ApiClient _api;

  Future<List<Listing>> list(ListingFilters filters, {bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/marketplace-listings',
      query: filters.toQuery(),
      cacheTtl: CacheTtl.feed,
      forceRefresh: forceRefresh,
    );
    return parseList(body, Listing.fromJson);
  }

  /// The two promoted adverts the site shows in its sponsor panel.
  Future<List<Listing>> promoted() async {
    final body = await _api.get(
      '/api/marketplace-listings',
      query: {'promotedOnly': 'true'},
      cacheTtl: CacheTtl.feed,
    );
    return parseList(body, Listing.fromJson);
  }

  Future<Listing> detail(String id) async {
    final body = await _api.get('/api/marketplace-listings/$id');
    return Listing.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<List<Listing>> mine() async {
    final body = await _api.get('/api/me/marketplace-listings');
    return parseList(body, Listing.fromJson);
  }

  Future<({String id, String adNumber})> create({
    required String categoryId,
    required String title,
    required String description,
    required num price,
    required String condition,
    required String district,
    required String area,
    required String sellerName,
    required String sellerPhone,
    bool negotiable = false,
    Map<String, dynamic>? extraAttributes,
    List<String> photoPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'categoryId': categoryId,
      'title': title,
      'description': description,
      'price': price.toString(),
      'condition': condition,
      'district': district,
      'area': area,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'negotiable': negotiable ? '1' : '0',
      if (extraAttributes != null && extraAttributes.isNotEmpty)
        'extraAttributes': jsonEncode(extraAttributes),
    });
    for (final path in photoPaths.take(4)) {
      form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    final body = await _api.upload('/api/marketplace-listings', form);
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (id: map.str('id'), adNumber: map.str('adNumber'));
  }

  /// Any edit sends the advert back to `pending` for admin review.
  Future<void> update({
    required String id,
    required String categoryId,
    required String title,
    required String description,
    required num price,
    required String condition,
    required String district,
    required String area,
    required String sellerName,
    required String sellerPhone,
    bool negotiable = false,
    Map<String, dynamic>? extraAttributes,
    List<String> keepPhotoUrls = const [],
    List<String> newPhotoPaths = const [],
  }) async {
    final form = FormData.fromMap({
      'categoryId': categoryId,
      'title': title,
      'description': description,
      'price': price.toString(),
      'condition': condition,
      'district': district,
      'area': area,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'negotiable': negotiable ? '1' : '0',
      'keepPhotoUrls': jsonEncode(keepPhotoUrls),
      if (extraAttributes != null && extraAttributes.isNotEmpty)
        'extraAttributes': jsonEncode(extraAttributes),
    });
    for (final path in newPhotoPaths) {
      form.files.add(MapEntry('photos', await MultipartFile.fromFile(path)));
    }
    await _api.upload('/api/marketplace-listings/$id', form, method: 'PATCH');
  }

  Future<void> delete(String id) => _api.delete('/api/marketplace-listings/$id');

  Future<Map<String, dynamic>> sponsor({
    required String id,
    required String packageId,
  }) async {
    final body = await _api.post(
      '/api/marketplace-listings/$id/sponsor',
      body: {'packageId': packageId},
    );
    return body is Map<String, dynamic> ? body : const {};
  }
}
