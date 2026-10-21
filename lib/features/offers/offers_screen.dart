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

final offersProvider =
    FutureProvider.autoDispose.family<({List<Offer> offers, List<String> categories}), (String, String)>(
  (ref, key) => ref.watch(offerRepositoryProvider).list(q: key.$1, category: key.$2),
);

/// Partner offers, like the site's /offers page.
class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _category = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = (_q, _category);
    final data = ref.watch(offersProvider(key));
    final categories = data.valueOrNull?.categories ?? const <String>[];
    return SiteScaffold(
      title: '🎁 Offers',
      subtitle: 'Special prices from local businesses — only through CHT Plus',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(offersProvider(key).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                SiteButton(label: 'My codes', outlined: true, onPressed: () => context.push('/offers/my')),
                const SizedBox(width: 8),
                SiteButton(label: 'For businesses', onPressed: () => context.push('/offers/partner')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search: bike wash, restaurant, salon…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _search.clear();
                          _q = '';
                        }),
                      ),
              ),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in ['', ...categories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            c.isEmpty ? 'All' : c,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c == _category ? Colors.white : AppColors.text,
                            ),
                          ),
                          selected: c == _category,
                          showCheckmark: false,
                          selectedColor: AppColors.forest,
                          backgroundColor: AppColors.surface,
                          shape: const StadiumBorder(),
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            data.when(
              loading: () => const AppLoader(),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(offersProvider(key))),
              data: (d) => d.offers.isEmpty
                  ? Column(
                      children: [
                        EmptyNote(_q.isEmpty && _category.isEmpty ? 'No offers right now — check back soon.' : 'No offers match your search.'),
                        const SizedBox(height: 8),
                        SiteButton(label: 'Own a business? Give an offer', outlined: true, onPressed: () => context.push('/offers/partner')),
                      ],
                    )
                  : Column(
                      children: [
                        for (final o in d.offers) ...[OfferCardTile(offer: o), const SizedBox(height: 12)],
                      ],
                    ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap an offer, get your code, and show it at the shop. Partners are checked by CHT Plus before they can post offers.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
