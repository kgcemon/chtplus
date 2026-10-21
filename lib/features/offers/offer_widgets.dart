import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/offer.dart';
import '../widgets/view_count.dart';

/// The red "50% OFF" pill on an offer's photo (`.offer-badge`).
class OfferBadge extends StatelessWidget {
  const OfferBadge(this.label, {super.key, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x59D0342C), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: large ? 15 : 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// ~~৳100~~ ৳50, or the deal in words when there's no price.
class OfferPriceText extends StatelessWidget {
  const OfferPriceText({super.key, required this.offer, this.large = false});

  final Offer offer;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final priceStyle = TextStyle(fontSize: large ? 24 : 17, fontWeight: FontWeight.w800, color: AppColors.red);
    final price = offer.offerPrice;
    if (price == null) return Text(offer.discountLabel, style: priceStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (offer.regularPrice != null) ...[
          Text(
            offerTaka(offer.regularPrice!),
            style: TextStyle(
              fontSize: large ? 16 : 13,
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 7),
        ],
        Text(price > 0 ? offerTaka(price) : 'Free', style: priceStyle),
      ],
    );
  }
}

/// Round logo, or the first letter of the business name.
class PartnerLogo extends StatelessWidget {
  const PartnerLogo({super.key, required this.partner, this.size = 22});

  final OfferPartner partner;
  final double size;

  @override
  Widget build(BuildContext context) {
    if ((partner.logoUrl ?? '').isNotEmpty) {
      return ClipOval(child: AppNetworkImage(url: partner.logoUrl, width: size, height: size));
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.forestLight, shape: BoxShape.circle),
      child: Text(
        partner.name.isEmpty ? '?' : partner.name.characters.first,
        style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w800, color: AppColors.forestDark),
      ),
    );
  }
}

/// One offer in a list (`OfferCard`).
class OfferCardTile extends StatelessWidget {
  const OfferCardTile({super.key, required this.offer, this.footer});

  final Offer offer;

  /// Status and buttons on the partner's own offers.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/offers/${offer.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((offer.photoUrl ?? '').isNotEmpty)
                  AppNetworkImage(url: offer.photoUrl)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFFF4DC), Color(0xFFFFE2B8)]),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎁', style: TextStyle(fontSize: 40)),
                  ),
                if (offer.discountLabel.isNotEmpty) Positioned(top: 10, left: 10, child: OfferBadge(offer.discountLabel)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PartnerLogo(partner: offer.partner),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        offer.partner.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                    VerifiedBadge(active: offer.partner.blueBadge, size: 12),
                  ],
                ),
                const SizedBox(height: 6),
                Text(offer.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('📍 ${offer.partner.place}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const Divider(height: 18, color: AppColors.border),
                Row(
                  children: [
                    Expanded(child: OfferPriceText(offer: offer)),
                    if (offer.remaining != null)
                      Text(
                        offer.soldOut ? 'All claimed' : '${offer.remaining} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: offer.soldOut ? AppColors.red : AppColors.forest,
                        ),
                      ),
                    const SizedBox(width: 8),
                    ViewCountBadge(type: 'offer', id: offer.id),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            ),
          ),
        ],
      ),
    );
    return offer.soldOut ? Opacity(opacity: 0.6, child: card) : card;
  }
}

/// The dashed box with the code to show at the shop (`.offer-code-box`).
class CodeBoxCard extends StatelessWidget {
  const CodeBoxCard({super.key, required this.claim});

  final OfferClaim claim;

  @override
  Widget build(BuildContext context) {
    final active = claim.status == 'active';
    final time = claim.expiresAt.length >= 16 ? claim.expiresAt.substring(11, 16) : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF3FAF6) : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.forest : AppColors.border, width: 2),
      ),
      child: Column(
        children: [
          Text(
            active ? 'Show this code at the shop' : (claim.status == 'redeemed' ? 'Used' : 'Expired'),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SelectableText(
            claim.code,
            style: TextStyle(
              fontSize: active ? 28 : 22,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: active ? AppColors.forestDark : AppColors.textSecondary,
              decoration: active ? null : TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          if (active) ...[
            Text(
              'Valid until ${formatOfferDay(claim.expiresAt)}${time.isEmpty ? '' : ', $time'}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: claim.code));
                AppSnackbar.success(context, 'Code copied.');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy code'),
            ),
          ] else if (claim.redeemedAt != null)
            Text('Used on ${formatOfferDay(claim.redeemedAt!)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// A rule chip ("Code valid 7 days").
class OfferRuleChip extends StatelessWidget {
  const OfferRuleChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.forestDark)),
    );
  }
}
