import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/common.dart';
import '../../models/listing.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../../data/moderation_repository.dart';
import '../home/widgets/home_header.dart';
import '../widgets/cards.dart';
import '../widgets/detail_parts.dart';
import '../widgets/moderation.dart';

/// A product page laid out like the site's listing page on a phone: category
/// trail, photo gallery, title, poster, meta, price and description, then the
/// seller card, product details, safety tips and more from the category.
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingDetailProvider(id));

    return listing.when(
      loading: () => const Scaffold(
        body: CustomScrollView(
          slivers: [
            HomeHeader(),
            SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      error: (error, _) => Scaffold(
        body: CustomScrollView(
          slivers: [
            const HomeHeader(),
            SliverFillRemaining(
              child: ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(listingDetailProvider(id)),
              ),
            ),
          ],
        ),
      ),
      data: (item) => _Content(
        listing: item,
        onRefresh: () async {
          ref.invalidate(listingDetailProvider(id));
          await ref.read(listingDetailProvider(id).future);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.listing, required this.onRefresh});

  final Listing listing;
  final Future<void> Function() onRefresh;

  String _label(String? icon, String? name) => '${icon ?? ''} ${name ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final area = (l.area ?? '').isNotEmpty ? l.area! : l.locationLabel;
    final posted = Fmt.date(l.createdAt);
    void openCategory(String? id) => context.go('${Routes.marketplace}?category=$id');

    final body = <Widget>[
      Breadcrumb(
        parts: [
          ('Marketplace', () => context.go(Routes.marketplace)),
          if (l.parentCategoryId != null)
            (
              _label(l.parentCategoryIcon, l.parentCategoryName),
              () => openCategory(l.parentCategoryId),
            ),
          (_label(l.categoryIcon, l.categoryName), () => openCategory(l.categoryId)),
        ],
      ),
      const SizedBox(height: 16),
      if (l.paid)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '✨ Sponsored product',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A6700)),
          ),
        ),
      DetailGallery(photos: l.photos, placeholderEmoji: l.categoryIcon ?? '📦'),
      const SizedBox(height: 20),
      Text(
        l.title,
        style: const TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OwnerChip(
          userId: l.userId,
          name: l.ownerName,
          photoUrl: l.ownerPhotoUrl,
          blueBadge: l.ownerBlueBadge,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (l.condition != null) Tag(dataLabel(l.condition)),
          if (area.isNotEmpty) _Meta('📍 $area'),
          if (posted.isNotEmpty) _Meta('🕓 $posted'),
        ],
      ),
      const SizedBox(height: 14),
      Text.rich(
        TextSpan(
          text: Fmt.taka(l.price),
          children: [
            if (l.negotiable)
              const TextSpan(
                text: '  (negotiable)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: AppColors.forestDark,
        ),
      ),
      const SizedBox(height: 22),
      if (l.specs.isNotEmpty) ...[
        InfoCard(
          title: 'Specifications',
          rows: [
            for (final s in l.specs) (extraAttributeLabel(s.key), dataLabel(s.value)),
          ],
        ),
        const SizedBox(height: 22),
      ],
      const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(l.description ?? '', style: const TextStyle(fontSize: 14, height: 1.7)),
      const SizedBox(height: 22),
      _SellerCard(listing: l),
      const SizedBox(height: 16),
      InfoCard(
        title: 'Product details',
        rows: [
          ('Categories', _label(l.categoryIcon, l.categoryName)),
          if (l.condition != null) ('Condition', dataLabel(l.condition)),
          if (area.isNotEmpty) ('Location', '📍 $area'),
          if (posted.isNotEmpty) ('Posted on', posted),
          ('Ad number', l.adNumber ?? l.id),
        ],
      ),
      const SizedBox(height: 16),
      const SafetyBox(
        title: '⚠️ Safe shopping tips',
        tips: [
          'Avoid paying in advance',
          'Meet the seller in a safe, public place',
          'Inspect the product carefully and make sure it suits your needs',
          'Pay only when you are satisfied',
        ],
      ),
      const SizedBox(height: 8),
      ReportLink(target: ReportTarget.listing, targetId: l.id, what: 'listing'),
      if (l.related.isNotEmpty) ...[
        const SizedBox(height: 32),
        const Text(
          'More products in the same category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < l.related.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ListingCard(listing: l.related[i])),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < l.related.length
                    ? ListingCard(listing: l.related[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    ];

    return DetailPage(header: const HomeHeader(), onRefresh: onRefresh, children: body);
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary));
  }
}

/// Centered seller card: initial, name with Follow, a big phone button and
/// "View profile" (`.listing-seller-card`).
class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final name = listing.sellerName ?? 'Seller';
    final phone = listing.sellerPhone ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Avatar(name: name, size: 64)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              FollowInline(userId: listing.userId),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Seller',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (phone.isNotEmpty)
            FilledButton(
              onPressed: () => Launchers.call(context, phone),
              style: _bigButton(FilledButton.styleFrom(backgroundColor: AppColors.forest)),
              child: Text('📞 $phone'),
            ),
          if (listing.userId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/u/${listing.userId}'),
              style: _bigButton(
                OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.forest),
                ),
              ),
              child: const Text('View profile'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Contact the seller directly by phone',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  ButtonStyle _bigButton(ButtonStyle base) => base.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}
