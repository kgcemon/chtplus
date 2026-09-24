import '../core/utils/json.dart';

/// A marketplace advert.
class Listing {
  const Listing({
    required this.id,
    required this.title,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.description,
    this.price = 0,
    this.condition,
    this.district,
    this.area,
    this.sellerName,
    this.sellerPhone,
    this.paid = false,
    this.negotiable = false,
    this.extraAttributes,
    this.photos = const [],
    this.adNumber,
    this.status,
    this.sponsoredUntil,
    this.userId,
    this.createdAt,
    this.ownerName,
    this.ownerPhotoUrl,
    this.ownerBlueBadge = false,
    this.parentCategoryId,
    this.parentCategoryName,
    this.parentCategoryIcon,
    this.related = const [],
  });

  final String id;
  final String title;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? description;
  final num price;
  final String? condition;
  final String? district;
  final String? area;
  final String? sellerName;
  final String? sellerPhone;
  final bool paid;
  final bool negotiable;
  final Map<String, dynamic>? extraAttributes;
  final List<String> photos;
  final String? adNumber;
  final String? status;
  final DateTime? sponsoredUntil;
  final String? userId;
  final DateTime? createdAt;

  /// The CHT Plus account that posted it (detail only).
  final String? ownerName;
  final String? ownerPhotoUrl;
  final bool ownerBlueBadge;

  /// The top-level category above [categoryId], for the breadcrumb trail.
  final String? parentCategoryId;
  final String? parentCategoryName;
  final String? parentCategoryIcon;

  /// Up to four other products in the same category (detail only).
  final List<Listing> related;

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json.str('id'),
        title: json.str('title'),
        categoryId: json.strOrNull('categoryId'),
        categoryName: json.strOrNull('categoryName'),
        categoryIcon: json.strOrNull('categoryIcon'),
        description: json.strOrNull('description'),
        price: json.dbl('price'),
        condition: json.strOrNull('condition'),
        district: json.strOrNull('district'),
        area: json.strOrNull('area'),
        sellerName: json.strOrNull('sellerName'),
        sellerPhone: json.strOrNull('sellerPhone'),
        paid: json.flag('paid'),
        negotiable: json.flag('negotiable'),
        extraAttributes: json.mapOrNull('extraAttributes'),
        photos: json.stringList('photos'),
        adNumber: json.strOrNull('adNumber'),
        status: json.strOrNull('status'),
        sponsoredUntil: json.date('sponsoredUntil'),
        userId: json.strOrNull('userId'),
        createdAt: json.date('createdAt'),
        ownerName: json.strOrNull('ownerName'),
        ownerPhotoUrl: json.strOrNull('ownerPhotoUrl'),
        ownerBlueBadge: json.flag('ownerBlueBadge'),
        parentCategoryId: json.mapOrNull('parentCategory')?.strOrNull('id'),
        parentCategoryName: json.mapOrNull('parentCategory')?.strOrNull('name'),
        parentCategoryIcon: json.mapOrNull('parentCategory')?.strOrNull('icon'),
        related: json.mapList('related').map(Listing.fromJson).toList(),
      );

  String get locationLabel =>
      [area, district].where((e) => e != null && e.isNotEmpty).join(', ');

  bool get isSponsorActive =>
      paid || (sponsoredUntil != null && sponsoredUntil!.isAfter(DateTime.now()));

  /// Non-empty extra specs, ready to render as label/value rows.
  List<MapEntry<String, String>> get specs {
    final source = extraAttributes;
    if (source == null) return const [];
    final result = <MapEntry<String, String>>[];
    source.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      result.add(MapEntry(key, text));
    });
    return result;
  }
}

/// Marketplace sort options that `/api/marketplace-listings` understands.
enum ListingSort {
  newest('', 'Newest first'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low');

  const ListingSort(this.value, this.label);
  final String value;
  final String label;
}
