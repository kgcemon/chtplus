import '../core/utils/json.dart';

/// `/api/me/referral` — the user's Refer & Win code, who joined with it, and
/// (if this account itself joined with someone's code) what is still needed
/// for its welcome bonus. Mirrors the site's /refer page.
class ReferralSummary {
  const ReferralSummary({
    required this.enabled,
    required this.code,
    required this.shareUrl,
    required this.referrerReward,
    required this.referredReward,
    required this.monthlyLimit,
    required this.stats,
    required this.referrals,
    this.joinedWith,
  });

  final bool enabled;
  final String code;
  final String shareUrl;
  final int referrerReward;
  final int referredReward;

  /// 0 means no limit.
  final int monthlyLimit;
  final ReferralStats stats;
  final List<ReferredFriend> referrals;
  final JoinedWith? joinedWith;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) => ReferralSummary(
        enabled: json.flag('enabled', fallback: true),
        code: json.str('code'),
        shareUrl: json.str('shareUrl'),
        referrerReward: json.intOr('referrerReward'),
        referredReward: json.intOr('referredReward'),
        monthlyLimit: json.intOr('monthlyLimit'),
        stats: ReferralStats.fromJson(json.mapOrNull('stats') ?? const {}),
        referrals: json.mapList('referrals').map(ReferredFriend.fromJson).toList(growable: false),
        joinedWith: json.mapOrNull('joinedWith') == null
            ? null
            : JoinedWith.fromJson(json.mapOrNull('joinedWith')!),
      );
}

class ReferralStats {
  const ReferralStats({
    required this.joined,
    required this.completed,
    required this.pending,
    required this.coinsEarned,
  });

  final int joined;
  final int completed;
  final int pending;
  final int coinsEarned;

  factory ReferralStats.fromJson(Map<String, dynamic> json) => ReferralStats(
        joined: json.intOr('joined'),
        completed: json.intOr('completed'),
        pending: json.intOr('pending'),
        coinsEarned: json.intOr('coinsEarned'),
      );
}

class ReferredFriend {
  const ReferredFriend({
    required this.id,
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.status,
    required this.reward,
    this.createdAt,
  });

  final int id;
  final String userId;
  final String name;
  final String? photoUrl;

  /// pending (profile not complete yet) · rewarded · rejected
  final String status;
  final int reward;
  final DateTime? createdAt;

  factory ReferredFriend.fromJson(Map<String, dynamic> json) => ReferredFriend(
        id: json.intOr('id'),
        userId: json.str('userId'),
        name: json.str('name'),
        photoUrl: json.strOrNull('photoUrl'),
        status: json.str('status', fallback: 'pending'),
        reward: json.intOr('reward'),
        createdAt: json.date('createdAt'),
      );
}

class JoinedWith {
  const JoinedWith({
    required this.referrerName,
    required this.status,
    required this.reward,
    required this.checklist,
  });

  final String referrerName;
  final String status;
  final int reward;

  /// photo / phone / location → done?
  final Map<String, bool> checklist;

  factory JoinedWith.fromJson(Map<String, dynamic> json) {
    final raw = json.mapOrNull('checklist') ?? const {};
    return JoinedWith(
      referrerName: json.str('referrerName'),
      status: json.str('status', fallback: 'pending'),
      reward: json.intOr('reward'),
      checklist: {for (final e in raw.entries) e.key: e.value == true},
    );
  }
}
