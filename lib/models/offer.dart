import '../core/utils/json.dart';

/// Partner offers (`/api/offers`, see the site's lib/offers.js): an approved
/// business posts a discount, a user taps "Get offer" for a one-off code and
/// shows it at the shop, where the partner marks it used.
class Offer {
  const Offer({
    required this.id,
    required this.title,
    this.description = '',
    this.terms = '',
    this.photoUrl,
    this.regularPrice,
    this.offerPrice,
    this.percentOff,
    this.discountLabel = '',
    required this.codeValidDays,
    required this.perUserLimit,
    this.cooldownDays = 0,
    this.totalLimit,
    this.remaining,
    this.endsOn,
    required this.status,
    this.adminHidden = false,
    this.claimedCount = 0,
    this.redeemedCount = 0,
    required this.partner,
  });

  final String id;
  final String title;
  final String description;
  final String terms;
  final String? photoUrl;
  final int? regularPrice;
  final int? offerPrice;
  final int? percentOff;

  /// "50% OFF", or the partner's own words ("Buy 1 get 1").
  final String discountLabel;
  final int codeValidDays;

  /// 0 = no limit per person.
  final int perUserLimit;
  final int cooldownDays;
  final int? totalLimit;

  /// Codes still available; null when there's no total cap.
  final int? remaining;

  /// YYYY-MM-DD, or null for no end date.
  final String? endsOn;

  /// active · paused
  final String status;
  final bool adminHidden;
  final int claimedCount;
  final int redeemedCount;
  final OfferPartner partner;

  bool get soldOut => remaining == 0;

  List<String> get termLines => terms.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// The partner's rules in a few words, as on the site.
  List<String> get rules => [
        'Code valid $codeValidDays ${codeValidDays == 1 ? 'day' : 'days'}',
        perUserLimit == 0 ? 'No limit per person' : '$perUserLimit ${perUserLimit == 1 ? 'time' : 'times'} per person',
        if (cooldownDays > 0) 'Again after $cooldownDays days',
        if (remaining != null) remaining! > 0 ? '$remaining left' : 'All claimed',
        if (endsOn != null) 'Ends ${formatOfferDay(endsOn!)}',
      ];

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: json.str('id'),
        title: json.str('title'),
        description: json.str('description'),
        terms: json.str('terms'),
        photoUrl: json.strOrNull('photoUrl'),
        regularPrice: json.intOrNull('regularPrice'),
        offerPrice: json.intOrNull('offerPrice'),
        percentOff: json.intOrNull('percentOff'),
        discountLabel: json.str('discountLabel'),
        codeValidDays: json.intOr('codeValidDays', 7),
        perUserLimit: json.intOr('perUserLimit', 1),
        cooldownDays: json.intOr('cooldownDays'),
        totalLimit: json.intOrNull('totalLimit'),
        remaining: json.intOrNull('remaining'),
        endsOn: json.strOrNull('endsOn'),
        status: json.str('status', fallback: 'active'),
        adminHidden: json.flag('adminHidden'),
        claimedCount: json.intOr('claimedCount'),
        redeemedCount: json.intOr('redeemedCount'),
        partner: OfferPartner.fromJson(json.mapOrNull('partner') ?? const {}),
      );
}

class OfferPartner {
  const OfferPartner({
    required this.userId,
    required this.name,
    this.category = '',
    this.area = '',
    this.address,
    this.phone = '',
    this.logoUrl,
    this.blueBadge = false,
  });

  final String userId;
  final String name;
  final String category;
  final String area;
  final String? address;
  final String phone;
  final String? logoUrl;
  final bool blueBadge;

  factory OfferPartner.fromJson(Map<String, dynamic> json) => OfferPartner(
        userId: json.str('userId'),
        name: json.str('name', fallback: 'Partner'),
        category: json.str('category'),
        area: json.str('area'),
        address: json.strOrNull('address'),
        phone: json.str('phone'),
        logoUrl: json.strOrNull('logoUrl'),
        blueBadge: json.flag('blueBadge'),
      );
}

/// A user's code for an offer.
class OfferClaim {
  const OfferClaim({
    required this.id,
    required this.offerId,
    required this.code,
    required this.status,
    required this.expiresAt,
    this.redeemedAt,
    this.offer,
  });

  final int id;
  final String offerId;

  /// "CHT-7K4P2Q"
  final String code;

  /// active · redeemed · expired
  final String status;

  /// "YYYY-MM-DD HH:MM:SS" (Bangladesh time)
  final String expiresAt;
  final String? redeemedAt;

  /// Set on "My codes".
  final Offer? offer;

  factory OfferClaim.fromJson(Map<String, dynamic> json) {
    final offer = json.mapOrNull('offer');
    return OfferClaim(
      id: json.intOr('id'),
      offerId: json.str('offerId'),
      code: json.str('code'),
      status: json.str('status', fallback: 'active'),
      expiresAt: json.str('expiresAt'),
      redeemedAt: json.strOrNull('redeemedAt'),
      offer: offer == null ? null : Offer.fromJson(offer),
    );
  }
}

/// `/api/offers/:id`: the offer and what the viewer can do with it.
class OfferDetail {
  const OfferDetail({
    required this.offer,
    this.isOwner = false,
    this.live = true,
    this.activeClaim,
    this.canClaim = false,
    this.reason,
    this.nextOn,
    this.usedCount = 0,
  });

  final Offer offer;
  final bool isOwner;
  final bool live;
  final OfferClaim? activeClaim;
  final bool canClaim;

  /// Why "Get offer" isn't available: login · own_offer · has_code · not_live
  /// · limit_reached · cooldown · sold_out.
  final String? reason;

  /// With reason "cooldown": the day the user can get it again.
  final String? nextOn;
  final int usedCount;

  factory OfferDetail.fromJson(Map<String, dynamic> json) {
    final claim = json.mapOrNull('activeClaim');
    return OfferDetail(
      offer: Offer.fromJson(json.mapOrNull('offer') ?? const {}),
      isOwner: json.flag('isOwner'),
      live: json.flag('live', fallback: true),
      activeClaim: claim == null ? null : OfferClaim.fromJson(claim),
      canClaim: json.flag('canClaim'),
      reason: json.strOrNull('reason'),
      nextOn: json.strOrNull('nextOn'),
      usedCount: json.intOr('usedCount'),
    );
  }
}

/// `/api/me/offer-partner`: my partner application and, once approved, my
/// offers and recently used codes.
class PartnerState {
  const PartnerState({
    this.status,
    this.businessName,
    this.category,
    this.area,
    this.adminNote,
    this.offers = const [],
    this.redemptions = const [],
    this.categories = const [],
  });

  /// null (never applied) · pending · approved · rejected · blocked
  final String? status;
  final String? businessName;
  final String? category;
  final String? area;
  final String? adminNote;
  final List<Offer> offers;
  final List<Redemption> redemptions;
  final List<String> categories;

  factory PartnerState.fromJson(Map<String, dynamic> json) {
    final p = json.mapOrNull('partner');
    return PartnerState(
      status: p?.strOrNull('status'),
      businessName: p?.strOrNull('businessName'),
      category: p?.strOrNull('category'),
      area: p?.strOrNull('area'),
      adminNote: p?.strOrNull('adminNote'),
      offers: parseList(json['offers'], Offer.fromJson),
      redemptions: parseList(json['redemptions'], Redemption.fromJson),
      categories: json.stringList('categories'),
    );
  }
}

class Redemption {
  const Redemption({required this.code, required this.offerTitle, required this.userName, required this.redeemedAt});

  final String code;
  final String offerTitle;
  final String userName;
  final String redeemedAt;

  factory Redemption.fromJson(Map<String, dynamic> json) => Redemption(
        code: json.str('code'),
        offerTitle: json.str('offerTitle'),
        userName: json.str('userName'),
        redeemedAt: json.str('redeemedAt'),
      );
}

/// What the partner sees after typing a customer's code.
class CodeCheck {
  const CodeCheck({
    required this.claim,
    required this.offerTitle,
    this.offerPrice,
    this.discountLabel = '',
    this.userName,
    this.redeemed = false,
  });

  final OfferClaim claim;
  final String offerTitle;
  final int? offerPrice;
  final String discountLabel;
  final String? userName;

  /// True right after this check marked the code used.
  final bool redeemed;

  static CodeCheck? fromJson(Map<String, dynamic> json) {
    final claim = json.mapOrNull('claim');
    if (claim == null) return null;
    final offer = json.mapOrNull('offer') ?? const {};
    return CodeCheck(
      claim: OfferClaim.fromJson(claim),
      offerTitle: offer.str('title'),
      offerPrice: offer.intOrNull('offerPrice'),
      discountLabel: offer.str('discountLabel'),
      userName: json.mapOrNull('user')?.strOrNull('name'),
      redeemed: json.flag('redeemed'),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-10-24" or "2026-10-24 14:38:00" → "24 Oct 2026".
String formatOfferDay(String ymd) {
  final d = DateTime.tryParse(ymd.length >= 10 ? ymd.substring(0, 10) : ymd);
  if (d == null) return ymd;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "৳1,500"
String offerTaka(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '৳$b';
}
