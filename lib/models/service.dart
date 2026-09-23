import '../core/utils/formatters.dart';
import '../core/utils/json.dart';

/// A service provider listing. The same shape backs `/api/services`,
/// `/api/me/services` and the services embedded in a public profile.
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.providerName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.description,
    this.descriptionText,
    this.district,
    this.area,
    this.phone,
    this.rating = 0,
    this.ratingCount = 0,
    this.paid = false,
    this.photoUrl,
    this.photos = const [],
    this.userId,
    this.ownerName,
    this.ownerPhotoUrl,
    this.ownerBlueBadge = false,
    this.status,
    this.sponsoredUntil,
  });

  final String id;
  final String providerName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? description;
  final String? descriptionText;
  final String? district;
  final String? area;
  final String? phone;
  final double rating;
  final int ratingCount;
  final bool paid;
  final String? photoUrl;
  final List<String> photos;
  final String? userId;
  final String? ownerName;
  final String? ownerPhotoUrl;
  final bool ownerBlueBadge;
  final String? status;
  final DateTime? sponsoredUntil;

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json.str('id'),
        providerName: json.str('providerName'),
        categoryId: json.strOrNull('categoryId'),
        categoryName: json.strOrNull('categoryName'),
        categoryIcon: json.strOrNull('categoryIcon'),
        description: json.strOrNull('description'),
        descriptionText: json.strOrNull('descriptionText'),
        district: json.strOrNull('district'),
        area: json.strOrNull('area'),
        phone: json.strOrNull('phone'),
        rating: json.dbl('rating'),
        ratingCount: json.intOr('ratingCount'),
        paid: json.flag('paid'),
        photoUrl: json.strOrNull('photoUrl'),
        photos: json.stringList('photos'),
        userId: json.strOrNull('userId'),
        ownerName: json.strOrNull('ownerName'),
        ownerPhotoUrl: json.strOrNull('ownerPhotoUrl'),
        ownerBlueBadge: json.flag('ownerBlueBadge'),
        status: json.strOrNull('status'),
        sponsoredUntil: json.date('sponsoredUntil'),
      );

  /// Falls back to the single `photoUrl` column for rows saved before the
  /// multi-photo table existed.
  List<String> get allPhotos {
    if (photos.isNotEmpty) return photos;
    final single = photoUrl;
    return single == null ? const [] : [single];
  }

  String get preview =>
      descriptionText?.isNotEmpty == true ? descriptionText! : Fmt.plainText(description);

  String get locationLabel =>
      [area, district].where((e) => e != null && e.isNotEmpty).join(', ');

  bool get isSponsorActive =>
      paid || (sponsoredUntil != null && sponsoredUntil!.isAfter(DateTime.now()));
}
