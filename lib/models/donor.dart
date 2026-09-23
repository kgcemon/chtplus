import '../core/utils/formatters.dart';
import '../core/utils/json.dart';

const bloodGroups = <String>['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class Donor {
  const Donor({
    required this.id,
    required this.name,
    this.bloodGroup,
    this.phone,
    this.district,
    this.area,
    this.photoUrl,
    this.lastDonationDate,
    this.rating = 0,
    this.ratingCount = 0,
    this.userId,
    this.likeCount = 0,
    this.likedByMe = false,
    bool? eligible,
  }) : _eligible = eligible;

  final String id;
  final String name;
  final String? bloodGroup;
  final String? phone;
  final String? district;
  final String? area;
  final String? photoUrl;
  final DateTime? lastDonationDate;
  final double rating;
  final int ratingCount;
  final String? userId;
  final int likeCount;
  final bool likedByMe;
  final bool? _eligible;

  factory Donor.fromJson(Map<String, dynamic> json) => Donor(
        id: json.str('id'),
        name: json.str('name'),
        bloodGroup: json.strOrNull('bloodGroup'),
        phone: json.strOrNull('phone'),
        district: json.strOrNull('district'),
        area: json.strOrNull('area'),
        photoUrl: json.strOrNull('photoUrl'),
        lastDonationDate: json.date('lastDonationDate'),
        rating: json.dbl('rating'),
        ratingCount: json.intOr('ratingCount'),
        userId: json.strOrNull('userId'),
        likeCount: json.intOr('likeCount'),
        likedByMe: json.flag('likedByMe'),
        eligible: json.containsKey('eligible') ? json.flag('eligible') : null,
      );

  /// The server sends `eligible` on most routes; when it does not (profile
  /// embeds), it is derived the same way — 120 days since the last donation.
  bool get eligible => _eligible ?? Fmt.isEligibleToDonate(lastDonationDate);

  String get locationLabel =>
      [area, district].where((e) => e != null && e.isNotEmpty).join(', ');

  /// Days left before this donor can give blood again, or null when available.
  int? get daysUntilEligible {
    if (eligible) return null;
    final last = lastDonationDate;
    if (last == null) return null;
    final remaining = 120 - DateTime.now().difference(last).inDays;
    return remaining > 0 ? remaining : null;
  }

  Donor copyWith({int? likeCount, bool? likedByMe}) => Donor(
        id: id,
        name: name,
        bloodGroup: bloodGroup,
        phone: phone,
        district: district,
        area: area,
        photoUrl: photoUrl,
        lastDonationDate: lastDonationDate,
        rating: rating,
        ratingCount: ratingCount,
        userId: userId,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        eligible: _eligible,
      );
}
