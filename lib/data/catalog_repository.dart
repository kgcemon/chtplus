import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/catalog.dart';

/// Reference data shared by many screens. Everything here is cached, because
/// these lists change rarely and are needed on almost every screen.
class CatalogRepository {
  const CatalogRepository(this._api);

  final ApiClient _api;

  Future<AppRemoteConfig> appConfig() async {
    final body = await _api.get('/api/app-config', cacheTtl: CacheTtl.config);
    return AppRemoteConfig.fromJson(
      body is Map<String, dynamic> ? body : const {},
    );
  }

  Future<List<BannerItem>> banners({bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/banners',
      cacheTtl: CacheTtl.promo,
      forceRefresh: forceRefresh,
    );
    return parseList(body, BannerItem.fromJson);
  }

  /// The banners above the service categories page.
  Future<List<BannerItem>> serviceBanners() async {
    final body = await _api.get(
      '/api/banners',
      query: {'placement': 'services'},
      cacheTtl: CacheTtl.promo,
    );
    return parseList(body, BannerItem.fromJson);
  }

  Future<WelcomePopup?> welcomePopup() async {
    final body = await _api.get('/api/welcome-popup', cacheTtl: CacheTtl.promo);
    return WelcomePopup.fromResponse(body);
  }

  Future<List<Category>> serviceCategories({bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/service-categories',
      cacheTtl: CacheTtl.reference,
      forceRefresh: forceRefresh,
    );
    return parseList(body, Category.fromJson);
  }

  Future<List<Category>> marketplaceCategories({bool forceRefresh = false}) async {
    final body = await _api.get(
      '/api/marketplace-categories',
      cacheTtl: CacheTtl.reference,
      forceRefresh: forceRefresh,
    );
    return parseList(body, Category.fromJson);
  }

  /// Only the four districts the site serves (Khagrachari, Rangamati,
  /// Bandarban, Chattogram).
  Future<List<District>> districts() async {
    final body = await _api.get('/api/locations/districts', cacheTtl: CacheTtl.reference);
    return parseList(body, District.fromJson);
  }

  Future<List<Upazila>> upazilas(int districtId) async {
    final body = await _api.get(
      '/api/locations/upazilas',
      query: {'districtId': districtId},
      cacheTtl: CacheTtl.reference,
    );
    return parseList(body, Upazila.fromJson);
  }

  Future<List<DiseaseDepartment>> diseaseDepartments() async {
    final body = await _api.get('/api/disease-departments', cacheTtl: CacheTtl.reference);
    return parseList(body, DiseaseDepartment.fromJson);
  }

  Future<List<Organization>> organizations() async {
    final body = await _api.get('/api/organizations', cacheTtl: CacheTtl.reference);
    return parseList(body, Organization.fromJson);
  }
}
