import '../core/utils/json.dart';

/// Public client config from `/api/app-config` — values an admin can change in
/// Admin → Settings, so they are never hardcoded in the app.
class AppRemoteConfig {
  const AppRemoteConfig({this.googleClientId, this.oneSignalAppId, this.logoUrl});

  final String? googleClientId;
  final String? oneSignalAppId;

  /// The logo uploaded in Admin → Settings, the same one the site's header shows.
  final String? logoUrl;

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) => AppRemoteConfig(
        googleClientId: json.strOrNull('googleClientId'),
        oneSignalAppId: json.strOrNull('oneSignalAppId'),
        logoUrl: json.strOrNull('logoUrl'),
      );

  bool get googleEnabled => (googleClientId ?? '').isNotEmpty;
  bool get pushEnabled => (oneSignalAppId ?? '').isNotEmpty;
}

class BannerItem {
  const BannerItem({required this.id, this.title, this.url, this.imageUrl});

  final String id;
  final String? title;
  final String? url;
  final String? imageUrl;

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json.str('id'),
        title: json.strOrNull('title'),
        url: json.strOrNull('url'),
        imageUrl: json.strOrNull('imageUrl'),
      );
}

class WelcomePopup {
  const WelcomePopup({required this.imageUrl, this.url});

  final String imageUrl;
  final String? url;

  static WelcomePopup? fromResponse(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final popup = body.mapOrNull('popup');
    if (popup == null) return null;
    final image = popup.strOrNull('imageUrl');
    if (image == null) return null;
    return WelcomePopup(imageUrl: image, url: popup.strOrNull('url'));
  }
}

/// A service or marketplace category. `icon` is an emoji the admin picked.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.parentId,
  });

  final String id;
  final String name;
  final String? icon;
  final String? parentId;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json.str('id'),
        name: json.str('name'),
        icon: json.strOrNull('icon'),
        parentId: json.strOrNull('parentId'),
      );

  bool get isTopLevel => parentId == null;
}

class District {
  const District({
    required this.id,
    required this.name,
    this.bnName,
    this.divisionName,
    this.divisionBnName,
  });

  final int id;
  final String name;
  final String? bnName;
  final String? divisionName;
  final String? divisionBnName;

  factory District.fromJson(Map<String, dynamic> json) => District(
        id: json.intOr('id'),
        name: json.str('name'),
        bnName: json.strOrNull('bnName'),
        divisionName: json.strOrNull('divisionName'),
        divisionBnName: json.strOrNull('divisionBnName'),
      );

  /// The site stores the Bengali district name on services/listings/donors, so
  /// that is what gets sent back as a filter value.
  String get filterValue => bnName ?? name;
  String get label => bnName == null ? name : '$bnName ($name)';
}

class Upazila {
  const Upazila({required this.id, required this.name, this.bnName});

  final int id;
  final String name;
  final String? bnName;

  factory Upazila.fromJson(Map<String, dynamic> json) => Upazila(
        id: json.intOr('id'),
        name: json.str('name'),
        bnName: json.strOrNull('bnName'),
      );

  String get filterValue => bnName ?? name;
  String get label => bnName == null ? name : '$bnName ($name)';
}
