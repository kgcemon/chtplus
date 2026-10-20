import '../core/utils/json.dart';

/// `/api/blue-badge` — the blue tick packages users buy with coins, and the
/// signed-in user's current tick (see the site's lib/blueBadge.js).
class BlueBadgeInfo {
  const BlueBadgeInfo({this.packages = const [], this.status});

  final List<BlueBadgePackage> packages;

  /// Null for a visitor.
  final BlueBadgeStatus? status;

  factory BlueBadgeInfo.fromJson(Map<String, dynamic> json) => BlueBadgeInfo(
        packages: json.mapList('packages').map(BlueBadgePackage.fromJson).toList(growable: false),
        status: json.mapOrNull('status') == null ? null : BlueBadgeStatus.fromJson(json.mapOrNull('status')!),
      );
}

class BlueBadgePackage {
  const BlueBadgePackage({required this.id, required this.label, required this.coinCost});

  final String id;

  /// "1 month", "6 months", "1 year", "Permanent"…
  final String label;
  final int coinCost;

  factory BlueBadgePackage.fromJson(Map<String, dynamic> json) => BlueBadgePackage(
        id: json.str('id'),
        label: json.str('label'),
        coinCost: json.intOr('coinCost'),
      );
}

class BlueBadgeStatus {
  const BlueBadgeStatus({
    required this.active,
    required this.permanent,
    this.expiresAt,
    required this.coinBalance,
  });

  final bool active;
  final bool permanent;
  final DateTime? expiresAt;
  final int coinBalance;

  factory BlueBadgeStatus.fromJson(Map<String, dynamic> json) => BlueBadgeStatus(
        active: json.flag('active'),
        permanent: json.flag('permanent'),
        expiresAt: json.date('expiresAt'),
        coinBalance: json.intOr('coinBalance'),
      );
}
