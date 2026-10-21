import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../models/offer.dart';
import '../../providers/catalog_providers.dart';

/// The user's active code as a coupon card — like a membership card, with the
/// CHT Plus logo — the same design the site saves as an image. Under it,
/// "Copy code" and "Save image", which renders the card to a PNG and opens
/// the share sheet (save to Photos / Files, or send it on).
class OfferCodeCard extends StatefulWidget {
  const OfferCodeCard({super.key, required this.claim, required this.offer});

  final OfferClaim claim;
  final Offer offer;

  @override
  State<OfferCodeCard> createState() => _OfferCodeCardState();
}

class _OfferCodeCardState extends State<OfferCodeCard> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveImage() async {
    setState(() => _saving = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final code = widget.claim.code;
      await Share.shareXFiles(
        [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: '$code.png')],
        subject: '${widget.offer.title} — $code',
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not save the image, please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(key: _cardKey, child: _CouponCard(claim: widget.claim, offer: widget.offer)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.claim.code));
                  AppSnackbar.success(context, 'Code copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy code'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveImage,
                style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save image'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _gold = Color(0xFFFFD166);
const _paleGreen = Color(0xFFE6F4EC);

class _CouponCard extends ConsumerWidget {
  const _CouponCard({required this.claim, required this.offer});

  final OfferClaim claim;
  final Offer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoUrl = ref.watch(appRemoteConfigProvider).valueOrNull?.logoUrl;
    final p = offer.partner;
    final time = claim.expiresAt.length >= 16 ? claim.expiresAt.substring(11, 16) : '';
    final validUntil = '${formatOfferDay(claim.expiresAt)}${time.isEmpty ? '' : ', $time'}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4A2E), Color(0xFF176A42), Color(0xFF1F7A4D)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x55145C39), blurRadius: 18, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Soft decorative circle.
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            ),
          ),
          // Gold stripe on top.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 5,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.amber, _gold])),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- main part ---
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: (logoUrl ?? '').isNotEmpty
                              ? AppNetworkImage(url: logoUrl, height: 30, width: 110, fit: BoxFit.contain)
                              : const Center(
                                  child: Text(
                                    'CHT Plus',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestDark),
                                  ),
                                ),
                        ),
                        const Spacer(),
                        if (offer.discountLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              offer.discountLabel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '🔥 HOT DISCOUNT OFFER',
                      style: TextStyle(color: _gold, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    if (offer.offerPrice != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            offer.offerPrice! > 0 ? offerTaka(offer.offerPrice!) : 'Free',
                            style: const TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          if (offer.regularPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              offerTaka(offer.regularPrice!),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(p.name, style: const TextStyle(color: _paleGreen, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (p.place.isNotEmpty)
                      Text(
                        '📍 ${p.place}',
                        style: TextStyle(color: _paleGreen.withValues(alpha: 0.85), fontSize: 12.5),
                      ),
                  ],
                ),
              ),

              // --- perforation ---
              const _Perforation(),

              // --- code stub ---
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  children: [
                    const Text(
                      'YOUR CODE',
                      style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          claim.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: AppColors.forestDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valid until $validUntil',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One-time code · show it at the shop',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ticket-style tear line: half-circle notches at both edges with a dashed
/// line between them.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final notchColor = Theme.of(context).cardColor;
    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, c) {
                  final count = (c.maxWidth / 12).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      count,
                      (_) => Container(width: 6, height: 2, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(left: -11, top: 0, child: _notch(notchColor)),
          Positioned(right: -11, top: 0, child: _notch(notchColor)),
        ],
      ),
    );
  }

  Widget _notch(Color color) =>
      Container(width: 22, height: 22, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
