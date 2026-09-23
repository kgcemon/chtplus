import '../core/utils/json.dart';

/// The user object the auth routes return alongside the bearer token.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.area,
    this.photoUrl,
    this.onboardingCompleted = false,
    this.homeInterests = const [],
    this.blueBadge = false,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? area;
  final String? photoUrl;
  final bool onboardingCompleted;
  final List<String> homeInterests;
  final bool blueBadge;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json.str('id'),
        name: json.str('name'),
        email: json.str('email'),
        phone: json.strOrNull('phone'),
        area: json.strOrNull('area'),
        photoUrl: json.strOrNull('photoUrl'),
        onboardingCompleted: json.flag('onboardingCompleted'),
        homeInterests: json.stringList('homeInterests'),
        blueBadge: json.flag('blueBadge'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'area': area,
        'photoUrl': photoUrl,
        'onboardingCompleted': onboardingCompleted,
        'homeInterests': homeInterests,
        'blueBadge': blueBadge,
      };

  AuthUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? area,
    String? photoUrl,
    bool? onboardingCompleted,
    List<String>? homeInterests,
    bool? blueBadge,
  }) =>
      AuthUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        area: area ?? this.area,
        photoUrl: photoUrl ?? this.photoUrl,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        homeInterests: homeInterests ?? this.homeInterests,
        blueBadge: blueBadge ?? this.blueBadge,
      );
}

class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.company,
    this.position,
    this.location,
    this.isCurrent = false,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String company;
  final String? position;
  final String? location;
  final bool isCurrent;
  final DateTime? startDate;
  final DateTime? endDate;

  factory WorkEntry.fromJson(Map<String, dynamic> json) => WorkEntry(
        id: json.intOr('id'),
        company: json.str('company'),
        position: json.strOrNull('position'),
        location: json.strOrNull('location'),
        isCurrent: json.flag('isCurrent'),
        startDate: json.date('startDate'),
        endDate: json.date('endDate'),
      );
}

class EducationEntry {
  const EducationEntry({
    required this.id,
    required this.institution,
    this.level,
    this.fieldOfStudy,
    this.passingYear,
  });

  final int id;
  final String institution;
  final String? level;
  final String? fieldOfStudy;
  final String? passingYear;

  factory EducationEntry.fromJson(Map<String, dynamic> json) => EducationEntry(
        id: json.intOr('id'),
        institution: json.str('institution'),
        level: json.strOrNull('level'),
        fieldOfStudy: json.strOrNull('fieldOfStudy'),
        passingYear: json.strOrNull('passingYear'),
      );

  String get levelLabel {
    switch (level) {
      case 'school':
        return 'School';
      case 'college':
        return 'College';
      default:
        return 'University';
    }
  }
}

/// `GET /api/me` — the signed-in user's full profile plus counters.
class MeProfile {
  const MeProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.area,
    this.photoUrl,
    this.coverPhotoUrl,
    this.bio,
    this.currentCity,
    this.hometown,
    this.relationshipStatus,
    this.currentCityPrivacy = 'public',
    this.hometownPrivacy = 'public',
    this.relationshipStatusPrivacy = 'public',
    this.blueBadge = false,
    this.createdAt,
    this.work = const [],
    this.education = const [],
    this.donor,
    this.stats = const MeStats(),
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? area;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final String? bio;
  final String? currentCity;
  final String? hometown;
  final String? relationshipStatus;
  final String currentCityPrivacy;
  final String hometownPrivacy;
  final String relationshipStatusPrivacy;
  final bool blueBadge;
  final DateTime? createdAt;
  final List<WorkEntry> work;
  final List<EducationEntry> education;
  final MyDonorProfile? donor;
  final MeStats stats;

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    final user = json.mapOrNull('user') ?? const <String, dynamic>{};
    final donorJson = json.mapOrNull('donor');
    return MeProfile(
      id: user.str('id'),
      name: user.str('name'),
      email: user.str('email'),
      phone: user.strOrNull('phone'),
      area: user.strOrNull('area'),
      photoUrl: user.strOrNull('photoUrl'),
      coverPhotoUrl: user.strOrNull('coverPhotoUrl'),
      bio: user.strOrNull('bio'),
      currentCity: user.strOrNull('currentCity'),
      hometown: user.strOrNull('hometown'),
      relationshipStatus: user.strOrNull('relationshipStatus'),
      currentCityPrivacy: user.str('currentCityPrivacy', fallback: 'public'),
      hometownPrivacy: user.str('hometownPrivacy', fallback: 'public'),
      relationshipStatusPrivacy: user.str('relationshipStatusPrivacy', fallback: 'public'),
      blueBadge: user.flag('blueBadge'),
      createdAt: user.date('createdAt'),
      work: json.mapList('work').map(WorkEntry.fromJson).toList(),
      education: json.mapList('education').map(EducationEntry.fromJson).toList(),
      donor: donorJson == null ? null : MyDonorProfile.fromJson(donorJson),
      stats: MeStats.fromJson(json.mapOrNull('stats') ?? const {}),
    );
  }
}

class MeStats {
  const MeStats({
    this.servicesCount = 0,
    this.donorProfileExists = false,
    this.biodataCount = 0,
    this.marketplaceCount = 0,
    this.reviewsCount = 0,
    this.savedCount = 0,
  });

  final int servicesCount;
  final bool donorProfileExists;
  final int biodataCount;
  final int marketplaceCount;
  final int reviewsCount;
  final int savedCount;

  factory MeStats.fromJson(Map<String, dynamic> json) => MeStats(
        servicesCount: json.intOr('servicesCount'),
        donorProfileExists: json.flag('donorProfileExists'),
        biodataCount: json.intOr('biodataCount'),
        marketplaceCount: json.intOr('marketplaceCount'),
        reviewsCount: json.intOr('reviewsCount'),
        savedCount: json.intOr('savedCount'),
      );
}

/// The donor row attached to the signed-in account, if they registered as one.
class MyDonorProfile {
  const MyDonorProfile({
    this.bloodGroup,
    this.phone,
    this.district,
    this.area,
    this.lastDonationDate,
    this.photoUrl,
  });

  final String? bloodGroup;
  final String? phone;
  final String? district;
  final String? area;
  final DateTime? lastDonationDate;
  final String? photoUrl;

  factory MyDonorProfile.fromJson(Map<String, dynamic> json) => MyDonorProfile(
        bloodGroup: json.strOrNull('bloodGroup'),
        phone: json.strOrNull('phone'),
        district: json.strOrNull('district'),
        area: json.strOrNull('area'),
        lastDonationDate: json.date('lastDonationDate'),
        photoUrl: json.strOrNull('photoUrl'),
      );
}

/// A user in a follower/following list or chat header.
class UserChip {
  const UserChip({
    required this.id,
    required this.name,
    this.photoUrl,
    this.blueBadge = false,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final bool blueBadge;

  factory UserChip.fromJson(Map<String, dynamic> json) => UserChip(
        id: json.str('id'),
        name: json.str('name'),
        photoUrl: json.strOrNull('photoUrl'),
        blueBadge: json.flag('blueBadge'),
      );
}

/// Privacy-filtered "about" block from `/api/users/[id]/about`.
class UserAbout {
  const UserAbout({
    this.currentCity,
    this.hometown,
    this.relationshipStatus,
    this.currentCityPrivacy = 'public',
    this.hometownPrivacy = 'public',
    this.relationshipStatusPrivacy = 'public',
  });

  final String? currentCity;
  final String? hometown;
  final String? relationshipStatus;
  final String currentCityPrivacy;
  final String hometownPrivacy;
  final String relationshipStatusPrivacy;

  factory UserAbout.fromJson(Map<String, dynamic> json) => UserAbout(
        currentCity: json.strOrNull('currentCity'),
        hometown: json.strOrNull('hometown'),
        relationshipStatus: json.strOrNull('relationshipStatus'),
        currentCityPrivacy: json.str('currentCityPrivacy', fallback: 'public'),
        hometownPrivacy: json.str('hometownPrivacy', fallback: 'public'),
        relationshipStatusPrivacy: json.str('relationshipStatusPrivacy', fallback: 'public'),
      );

  bool get isEmpty =>
      (currentCity == null || currentCity!.isEmpty) &&
      (hometown == null || hometown!.isEmpty) &&
      (relationshipStatus == null || relationshipStatus!.isEmpty);
}
