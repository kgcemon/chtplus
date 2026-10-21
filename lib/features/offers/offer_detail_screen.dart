import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/call_pulse.dart';
import '../../core/widgets/common.dart';
import '../../models/offer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import '../widgets/site_scaffold.dart';
import '../widgets/view_count.dart';
import 'offer_widgets.dart';

final offerDetailProvider = FutureProvider.autoDispose.family<OfferDetail, String>(
  (ref, id) => ref.watch(offerRepositoryProvider).detail(id),
);

const _reasons = {
  'own_offer': 'This is your own offer.',
  'not_live': 'This offer isn’t available right now.',
  'limit_reached': 'You have already used this offer as many times as allowed.',
  'sold_out': 'All codes for this offer have been claimed.',
};

/// One offer, like the site's /offers/:id: the deal, the partner's rules,
/// "Get offer" (or the user's code), and the business with Call / Message.
class OfferDetailScreen extends ConsumerWidget {
  const OfferDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(offerDetailProvider(id));
    return SiteScaffold(
      title: 'Offer',
      body: ViewTracker(
        type: 'offer',
        id: id,
        child: detail.when(
          loading: () => const AppLoader(),
          error: (e, _) => ErrorView(
            message: e is ApiException && e.code == 'not_found' ? 'This offer isn’t available.' : '$e',
            onRetry: () => ref.invalidate(offerDetailProvider(id)),
          ),
          data: (d) => _Content(detail: d),
        ),
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.detail});

  final OfferDetail detail;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  bool _busy = false;

  Future<void> _claim() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(offerRepositoryProvider).claim(widget.detail.offer.id);
      ref.invalidate(offerDetailProvider(widget.detail.offer.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      final nextOn = e.data is Map ? (e.data as Map)['nextOn']?.toString() : null;
      AppSnackbar.error(
        context,
        e.code == 'cooldown' && nextOn != null
            ? 'You can get this offer again from ${formatOfferDay(nextOn)}.'
            : _reasons[e.code] ?? e.message,
      );
      ref.invalidate(offerDetailProvider(widget.detail.offer.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message(OfferPartner p) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    try {
      final conversationId = await ref.read(chatRepositoryProvider).startConversation(p.userId);
      if (mounted) context.push('/chat/$conversationId?name=${Uri.encodeComponent(p.name)}');
    } on ApiException catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.code == 'chat_disabled' ? 'This business has turned chat off — please call instead.' : e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final o = d.offer;
    final p = o.partner;
    const block = EdgeInsets.all(14);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(offerDetailProvider(o.id).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if ((o.photoUrl ?? '').isNotEmpty)
                    AppNetworkImage(url: o.photoUrl)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFFFF4DC), Color(0xFFFFE2B8)]),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🎁', style: TextStyle(fontSize: 60)),
                    ),
                  if (o.discountLabel.isNotEmpty) Positioned(top: 10, left: 10, child: OfferBadge(o.discountLabel, large: true)),
                ],
              ),
            ),
          ),
          if (!d.live) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9EC),
                border: Border.all(color: const Color(0xFFF3E0B0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                d.isOwner && o.adminHidden
                    ? 'Hidden by CHT Plus — people can’t see this offer.'
                    : d.isOwner && o.status == 'paused'
                        ? 'Paused — people can’t see this offer until you resume it.'
                        : 'This offer has ended.',
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(o.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: OfferPriceText(offer: o, large: true)),
                if (o.offerPrice != null && o.discountLabel.isNotEmpty) OfferBadge(o.discountLabel),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final r in o.rules) OfferRuleChip(r)]),
          const SizedBox(height: 14),

          // Get the code.
          if (!d.isOwner)
            AppCard(
              padding: block,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.activeClaim != null)
                    CodeBoxCard(claim: d.activeClaim!)
                  else if (d.canClaim || d.reason == 'login') ...[
                    FilledButton(
                      onPressed: _busy ? null : _claim,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: Text(_busy ? 'Getting your code...' : '🎟️ Get offer'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d.reason == 'login' ? 'Log in to get your code — it’s free.' : 'You’ll get a code to show at the shop.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ] else
                    Text(
                      d.reason == 'cooldown' && d.nextOn != null
                          ? 'You can get this offer again from ${formatOfferDay(d.nextOn!)}.'
                          : _reasons[d.reason] ?? '',
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                    ),
                  if (d.usedCount > 0) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.push('/offers/my'),
                      child: Text(
                        'You have used this offer ${d.usedCount} ${d.usedCount == 1 ? 'time' : 'times'} · My codes',
                        style: const TextStyle(fontSize: 13, color: AppColors.forest, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            AppCard(
              padding: block,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your offer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('🎟️ ${o.claimedCount} codes given · ✅ ${o.redeemedCount} used'),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: () => context.push('/offers/partner'), child: const Text('Open partner panel')),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // The business.
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PartnerLogo(partner: p, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                              VerifiedBadge(active: p.blueBadge, size: 13),
                            ],
                          ),
                          Text(
                            '${p.category} · 📍 ${p.area}${(p.address ?? '').isEmpty ? '' : ', ${p.address}'}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!d.isOwner) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (p.phone.isNotEmpty) ...[
                        Expanded(
                          child: CallPulse(
                            child: FilledButton(
                              onPressed: () => Launchers.call(context, p.phone),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                              child: const Text('📞 Call'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _message(p),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: const BorderSide(color: AppColors.forest),
                          ),
                          child: const Text('💬 Message'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (o.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: block,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(o.description, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
          if (o.termLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: block,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Terms', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final t in o.termLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $t', style: const TextStyle(height: 1.4)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
