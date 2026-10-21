import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/offer.dart';
import '../../providers/core_providers.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import 'offer_widgets.dart';

final myOfferClaimsProvider = FutureProvider.autoDispose<List<OfferClaim>>(
  (ref) => ref.watch(offerRepositoryProvider).myClaims(),
);

/// "My codes", like the site's /offers/my.
class MyCodesScreen extends ConsumerWidget {
  const MyCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(myOfferClaimsProvider);
    return SiteScaffold(
      title: 'My codes',
      subtitle: 'Codes you got from offers — show the active ones at the shop',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myOfferClaimsProvider.future),
        child: claims.when(
          loading: () => const AppLoader(),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(myOfferClaimsProvider)),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (list.isEmpty) ...[
                const EmptyNote('You haven’t got any offer codes yet.'),
                const SizedBox(height: 8),
                Center(child: SiteButton(label: 'See Hot Discount Offers', onPressed: () => context.push('/offers'))),
              ] else
                for (final c in list) ...[
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => context.push('/offers/${c.offerId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.offer?.title ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${c.offer?.partner.name ?? ''} · ${c.offer?.discountLabel ?? ''}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        CodeBoxCard(claim: c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
