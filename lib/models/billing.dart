import '../core/utils/json.dart';

const paymentMethods = <String>['bkash', 'nagad'];

String paymentMethodLabel(String? method) {
  switch (method) {
    case 'bkash':
      return 'bKash';
    case 'nagad':
      return 'Nagad';
    default:
      return method ?? '';
  }
}

class CoinPackage {
  const CoinPackage({
    required this.id,
    required this.takaAmount,
    required this.coinAmount,
  });

  final String id;
  final num takaAmount;
  final int coinAmount;

  factory CoinPackage.fromJson(Map<String, dynamic> json) => CoinPackage(
        id: json.str('id'),
        takaAmount: json.dbl('takaAmount'),
        coinAmount: json.intOr('coinAmount'),
      );
}

class CoinPurchaseRequest {
  const CoinPurchaseRequest({
    required this.id,
    required this.status,
    this.method,
    this.transactionId,
    this.phone,
    this.coinAmount = 0,
    this.takaAmount = 0,
    this.requestedAt,
    this.decidedAt,
  });

  final int id;
  final String status;
  final String? method;
  final String? transactionId;
  final String? phone;
  final int coinAmount;
  final num takaAmount;
  final DateTime? requestedAt;
  final DateTime? decidedAt;

  factory CoinPurchaseRequest.fromJson(Map<String, dynamic> json) =>
      CoinPurchaseRequest(
        id: json.intOr('id'),
        status: json.str('status', fallback: 'pending'),
        method: json.strOrNull('method'),
        transactionId: json.strOrNull('transactionId'),
        phone: json.strOrNull('phone'),
        coinAmount: json.intOr('coinAmount'),
        takaAmount: json.dbl('takaAmount'),
        requestedAt: json.date('requestedAt'),
        decidedAt: json.date('decidedAt'),
      );
}

/// A matrimony-wide subscription request (unlimited biodata access).
class SubscriptionRequest {
  const SubscriptionRequest({
    required this.id,
    required this.status,
    this.method,
    this.transactionId,
    this.phone,
    this.amount = 0,
    this.requestedAt,
    this.decidedAt,
    this.expiresAt,
  });

  final int id;
  final String status;
  final String? method;
  final String? transactionId;
  final String? phone;
  final num amount;
  final DateTime? requestedAt;
  final DateTime? decidedAt;
  final DateTime? expiresAt;

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) =>
      SubscriptionRequest(
        id: json.intOr('id'),
        status: json.str('status', fallback: 'pending'),
        method: json.strOrNull('method'),
        transactionId: json.strOrNull('transactionId'),
        phone: json.strOrNull('phone'),
        amount: json.dbl('amount'),
        requestedAt: json.date('requestedAt'),
        decidedAt: json.date('decidedAt'),
        expiresAt: json.date('expiresAt'),
      );

  bool get isActive =>
      status == 'active' && expiresAt != null && expiresAt!.isAfter(DateTime.now());
}

/// A boost package for a service or a marketplace listing.
class SponsorPackage {
  const SponsorPackage({
    required this.id,
    required this.name,
    required this.coinCost,
    required this.durationDays,
  });

  final String id;
  final String name;
  final int coinCost;
  final int durationDays;

  factory SponsorPackage.fromJson(Map<String, dynamic> json) => SponsorPackage(
        id: json.str('id'),
        name: json.str('name'),
        coinCost: json.intOr('coinCost'),
        durationDays: json.intOr('durationDays'),
      );
}
