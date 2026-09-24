import '../core/api/api_client.dart';
import '../core/api/response_cache.dart';
import '../core/utils/json.dart';
import '../models/billing.dart';

/// Coins, matrimony subscriptions and the boost packages for services and
/// marketplace adverts.
///
/// Payments are handled outside the app: the user sends money over bKash or
/// Nagad and submits the transaction id here for an admin to approve. Nothing
/// is charged in-app, so no Play billing is involved.
class BillingRepository {
  const BillingRepository(this._api);

  final ApiClient _api;

  Future<int> coinBalance() async {
    final body = await _api.get('/api/me/coins');
    return body is Map<String, dynamic> ? body.intOr('coinBalance') : 0;
  }

  Future<List<CoinPackage>> coinPackages() async {
    final body = await _api.get('/api/coin-packages', cacheTtl: CacheTtl.reference);
    return parseList(body, CoinPackage.fromJson);
  }

  /// The bKash / Nagad numbers to Send Money to, keyed by method. An empty
  /// number means that method is not offered right now.
  Future<Map<String, String>> coinPaymentNumbers() async {
    final body = await _api.get('/api/coin-payment-numbers');
    if (body is! Map<String, dynamic>) return const {};
    return {for (final m in paymentMethods) m: body.str(m)};
  }

  Future<List<CoinPurchaseRequest>> coinRequests() async {
    final body = await _api.get('/api/coin-purchase-requests');
    return parseList(body, CoinPurchaseRequest.fromJson);
  }

  /// Submits a coin top-up for admin review. Fails with
  /// `pending_request_exists` when one is already waiting.
  Future<void> requestCoins({
    required String packageId,
    required String method,
    required String transactionId,
    required String phone,
  }) =>
      _api.post('/api/coin-purchase-requests', body: {
        'packageId': packageId,
        'method': method,
        'transactionId': transactionId,
        'phone': phone,
      });

  Future<SubscriptionRequest?> subscription() async {
    final body = await _api.get('/api/subscriptions');
    if (body is! Map<String, dynamic>) return null;
    final sub = body.mapOrNull('subscription');
    return sub == null ? null : SubscriptionRequest.fromJson(sub);
  }

  Future<void> requestSubscription({
    required String method,
    required String transactionId,
    required String phone,
    required num amount,
  }) =>
      _api.post('/api/subscriptions', body: {
        'method': method,
        'transactionId': transactionId,
        'phone': phone,
        'amount': amount,
      });

  Future<List<SponsorPackage>> servicePackages() async {
    final body = await _api.get(
      '/api/service-subscription-packages',
      cacheTtl: CacheTtl.reference,
    );
    return parseList(body, SponsorPackage.fromJson);
  }

  Future<List<SponsorPackage>> marketplacePackages() async {
    final body = await _api.get(
      '/api/marketplace-subscription-packages',
      cacheTtl: CacheTtl.reference,
    );
    return parseList(body, SponsorPackage.fromJson);
  }
}
