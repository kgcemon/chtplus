import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/html_text.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/service.dart';
import '../../providers/feature_providers.dart';
import '../widgets/reviews_section.dart';
import '../widgets/save_button.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceDetailProvider(id));

    return Scaffold(
      body: service.when(
        loading: () => const _DetailSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(serviceDetailProvider(id)),
          ),
        ),
        data: (item) => _Content(service: item),
      ),
      bottomNavigationBar: service.valueOrNull == null
          ? null
          : _ContactBar(service: service.value!),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: AppColors.forestDark,
          actions: [
            IconButton(
              onPressed: () => Launchers.shareWebLink(
                '/services',
                title: service.providerName,
              ),
              icon: const Icon(Icons.share_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SaveButton(
                targetType: 'service',
                targetId: service.id,
                size: 22,
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: PhotoCarousel(
              photos: service.allPhotos,
              height: 250,
              placeholderIcon: Icons.handyman_outlined,
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
                  children: [
                    Expanded(
                      child: Text(
                        service.providerName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (service.paid)
                      const StatusPill(
                        label: 'Sponsored',
                        color: AppColors.amber,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
                if (service.categoryName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${service.categoryIcon ?? ''} ${service.categoryName}'.trim(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.forestDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                RatingStars(rating: service.rating, count: service.ratingCount),
                if (service.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => Launchers.map(context, service.locationLabel),
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
                              service.locationLabel,
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
                const SizedBox(height: 18),
                const Text(
                  'About this service',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                HtmlText(html: service.description),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (service.userId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppCard(
                onTap: () => context.push('/u/${service.userId}'),
                child: Row(
                  children: [
                    Avatar(
                      url: service.ownerPhotoUrl,
                      name: service.ownerName ?? '',
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Listed by',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  service.ownerName ?? 'View profile',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              VerifiedBadge(active: service.ownerBlueBadge),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ReviewsSection(targetType: 'service', targetId: service.id),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    if ((service.phone ?? '').isEmpty) return const SizedBox.shrink();

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
                  onPressed: () => Launchers.call(context, service.phone),
                  icon: const Icon(Icons.call_rounded, size: 19),
                  label: const Text('Call now'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Launchers.whatsapp(
                  context,
                  service.phone,
                  text: 'Hello, I found your service "${service.providerName}" on CHT Plus.',
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

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SkeletonBox(height: 250, radius: 0),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 200, height: 20),
              SizedBox(height: 12),
              SkeletonBox(width: 120, height: 12),
              SizedBox(height: 18),
              SkeletonBox(height: 12),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
