import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/save_button.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingDetailProvider(id));

    return Scaffold(
      body: listing.when(
        loading: () => const _Skeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(listingDetailProvider(id)),
          ),
        ),
        data: (item) => _Content(listing: item),
      ),
      bottomNavigationBar:
          listing.valueOrNull == null ? null : _ContactBar(listing: listing.value!),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoted = ref.watch(promotedListingsProvider).valueOrNull ?? const [];
    final others = promoted.where((l) => l.id != listing.id).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.forestDark,
          actions: [
            IconButton(
              onPressed: () => Launchers.shareWebLink(
                '/marketplace/listing/${listing.id}',
                title: '${listing.title} — ${Fmt.taka(listing.price)}',
              ),
              icon: const Icon(Icons.share_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SaveButton(
                targetType: 'marketplace_listing',
                targetId: listing.id,
                size: 22,
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: PhotoCarousel(
              photos: listing.photos,
              height: 280,
              placeholderIcon: Icons.inventory_2_outlined,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (listing.paid)
                      const StatusPill(
                        label: 'Promoted',
                        color: AppColors.amber,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.taka(listing.price),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forestDark,
                      ),
                    ),
                    if (listing.negotiable) ...[
                      const SizedBox(width: 9),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: StatusPill(
                          label: 'Negotiable',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (listing.condition != null)
                      StatusPill(label: dataLabel(listing.condition)),
                    if (listing.categoryName != null)
                      StatusPill(
                        label: listing.categoryName!,
                        color: AppColors.textSecondary,
                      ),
                    if (listing.adNumber != null)
                      StatusPill(
                        label: 'Ad ${listing.adNumber}',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                if (listing.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => Launchers.map(context, listing.locationLabel),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 17, color: AppColors.forest),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              listing.locationLabel,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded,
                              size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
                if (listing.specs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Specifications',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  for (final spec in listing.specs)
                    LabeledRow(
                      label: extraAttributeLabel(spec.key),
                      value: dataLabel(spec.value),
                    ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  listing.description ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: Color(0xFF8A5A00)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Meet in a public place, check the item before paying, and never send money in advance.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: Color(0xFF6B4600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (listing.userId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SellerCard(listing: listing),
            ),
          ),
        if (others.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Also promoted',
              subtitle: 'Other items worth a look',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 262,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: others.length,
                itemExtent: 178,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 168,
                    child: ListingCard(listing: others[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _SellerCard extends ConsumerWidget {
  const _SellerCard({required this.listing});

  final Listing listing;

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    try {
      final conversationId =
          await ref.read(chatRepositoryProvider).startConversation(listing.userId!);
      if (context.mounted) {
        context.push(
          '/chat/$conversationId?name=${Uri.encodeComponent(listing.sellerName ?? 'Seller')}',
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Row(
        children: [
          Avatar(name: listing.sellerName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seller',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  listing.sellerName ?? 'Seller',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _message(context, ref),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => context.push('/u/${listing.userId}'),
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    if ((listing.sellerPhone ?? '').isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Launchers.call(context, listing.sellerPhone),
                  icon: const Icon(Icons.call_rounded, size: 19),
                  label: const Text('Call seller'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Launchers.whatsapp(
                  context,
                  listing.sellerPhone,
                  text: 'Hello, is "${listing.title}" still available on CHT Plus?',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(52, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Icon(Icons.chat_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SkeletonBox(height: 280, radius: 0),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 20),
              SizedBox(height: 12),
              SkeletonBox(width: 140, height: 26),
              SizedBox(height: 18),
              SkeletonBox(height: 12),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 200, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
