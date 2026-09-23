import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/listing.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../widgets/sponsor_sheet.dart';
import 'sell_screen.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My adverts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/marketplace/sell');
          ref.invalidate(myListingsProvider);
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sell_outlined),
        label: const Text('Sell'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myListingsProvider);
          await ref.read(myListingsProvider.future);
        },
        child: listings.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(myListingsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No adverts yet',
                    message:
                        'List something you no longer need and reach buyers across the hill districts.',
                    actionLabel: 'Sell an item',
                    onAction: () async {
                      await context.push('/marketplace/sell');
                      ref.invalidate(myListingsProvider);
                    },
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _MyListingTile(listing: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _MyListingTile extends ConsumerWidget {
  const _MyListingTile({required this.listing});

  final Listing listing;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete this advert?',
      message: '"${listing.title}" will be removed permanently. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(marketplaceRepositoryProvider).delete(listing.id);
      ref.invalidate(myListingsProvider);
      ref.invalidate(listingsProvider);
      ref.invalidate(homeFeedProvider);
      if (context.mounted) AppSnackbar.success(context, 'Advert deleted.');
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = listing.photos.isEmpty ? null : listing.photos.first;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppNetworkImage(
                url: photo,
                width: 68,
                height: 68,
                borderRadius: BorderRadius.circular(10),
                placeholderIcon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      Fmt.taka(listing.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusPill.forStatus(listing.status),
                        if (listing.isSponsorActive) ...[
                          const SizedBox(width: 6),
                          const StatusPill(
                            label: 'Promoted',
                            color: AppColors.amber,
                            icon: Icons.bolt_rounded,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (listing.adNumber != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ad number ${listing.adNumber}'
              '${listing.isSponsorActive && listing.sponsoredUntil != null ? ' · boost until ${Fmt.date(listing.sponsoredUntil)}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              _Action(
                icon: Icons.visibility_outlined,
                label: 'View',
                onTap: () => context.push('/marketplace/listing/${listing.id}'),
              ),
              _Action(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SellScreen(existing: listing),
                    ),
                  );
                  if (saved == true) ref.invalidate(myListingsProvider);
                },
              ),
              _Action(
                icon: Icons.bolt_rounded,
                label: 'Promote',
                color: AppColors.amber,
                onTap: () async {
                  final boosted = await SponsorSheet.open(
                    context,
                    target: SponsorTarget.listing,
                    id: listing.id,
                  );
                  if (boosted) ref.invalidate(myListingsProvider);
                },
              ),
              _Action(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppColors.red,
                onTap: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
