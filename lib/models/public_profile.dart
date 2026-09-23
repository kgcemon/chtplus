import '../core/utils/json.dart';
import 'donor.dart';
import 'listing.dart';
import 'service.dart';
import 'user.dart';

/// `GET /api/users/[id]` — everything the public profile screen shows except
/// the three privacy-controlled fields, which come from `/about`.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.coverPhotoUrl,
    this.area,
    this.bio,
    this.createdAt,
    this.chatEnabled = true,
    this.blueBadge = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.work = const [],
    this.education = const [],
    this.services = const [],
    this.listings = const [],
    this.donor,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final String? area;
  final String? bio;
  final DateTime? createdAt;
  final bool chatEnabled;
  final bool blueBadge;
  final int followerCount;
  final int followingCount;
  final List<WorkEntry> work;
  final List<EducationEntry> education;
  final List<ServiceItem> services;
  final List<Listing> listings;
  final Donor? donor;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final donorJson = json.mapOrNull('donor');
    return PublicProfile(
      id: json.str('id'),
      name: json.str('name'),
      photoUrl: json.strOrNull('photoUrl'),
      coverPhotoUrl: json.strOrNull('coverPhotoUrl'),
      area: json.strOrNull('area'),
      bio: json.strOrNull('bio'),
      createdAt: json.date('createdAt'),
      chatEnabled: json.flag('chatEnabled', fallback: true),
      blueBadge: json.flag('blueBadge'),
      followerCount: json.intOr('followerCount'),
      followingCount: json.intOr('followingCount'),
      work: json.mapList('work').map(WorkEntry.fromJson).toList(),
      education: json.mapList('education').map(EducationEntry.fromJson).toList(),
      services: json.mapList('services').map(ServiceItem.fromJson).toList(),
      listings: json.mapList('listings').map(Listing.fromJson).toList(),
      donor: donorJson == null ? null : Donor.fromJson(donorJson),
    );
  }
}

/// The two lists behind `/api/me/follows`.
class FollowLists {
  const FollowLists({this.following = const [], this.followers = const []});

  final List<UserChip> following;
  final List<UserChip> followers;

  factory FollowLists.fromJson(Map<String, dynamic> json) => FollowLists(
        following: json.mapList('following').map(UserChip.fromJson).toList(),
        followers: json.mapList('followers').map(UserChip.fromJson).toList(),
      );
}
