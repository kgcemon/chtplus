import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/html_text.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../models/service.dart';
import '../../providers/feature_providers.dart';
import '../../data/moderation_repository.dart';
import '../widgets/detail_parts.dart';
import '../widgets/reviews_section.dart';
import '../widgets/moderation.dart';

/// A provider's details, drawn like the site's service popup: sponsor
/// ribbon, "category · area" header, photo beside name / owner / Call /
/// profile / rating, the description, then reviews.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceDetailProvider(id));

    return service.when(
      loading: () => const SheetPage(
        children: [
          Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => SheetPage(
        children: [
          ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(serviceDetailProvider(id)),
          ),
        ],
      ),
      data: (s) => _Content(
        service: s,
        onRefresh: () async {
          ref.invalidate(serviceDetailProvider(id));
          await ref.read(serviceDetailProvider(id).future);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.service, required this.onRefresh});

  final ServiceItem service;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final photos = s.allPhotos;
    final category = '${s.categoryIcon ?? ''} ${s.categoryName ?? ''}'.trim();
    final area = (s.area ?? '').isNotEmpty ? s.area! : s.locationLabel;

    return SheetPage(
      ribbon: s.paid ? '✨ Sponsored service' : null,
      subtitle: [category, area].where((e) => e.isNotEmpty).join(' · '),
      onRefresh: onRefresh,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty) ...[
              _Photos(photos: photos),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              s.providerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          FollowInline(userId: s.userId),
                        ],
                      ),
                      if (s.paid)
                        const Tag(
                          'Sponsored',
                          color: Color(0xFF9A6700),
                          background: Color(0xFFFFF3D6),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  OwnerChip(
                    userId: s.userId,
                    name: s.ownerName,
                    photoUrl: s.ownerPhotoUrl,
                    blueBadge: s.ownerBlueBadge,
                    label: '',
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((s.phone ?? '').isNotEmpty)
                        FilledButton(
                          onPressed: () => Launchers.call(context, s.phone),
                          style: smallButtonStyle(),
                          child: const Text('📞 Call'),
                        ),
                      if (s.userId != null)
                        OutlinedButton(
                          onPressed: () => context.push('/u/${s.userId}'),
                          style: smallButtonStyle(outlined: true),
                          child: const Text('View profile'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RatingStars(rating: s.rating, count: s.ratingCount, size: 13),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        HtmlText(html: s.description),
        const SizedBox(height: 16),
        ReviewsSection(targetType: 'service', targetId: s.id),
        const SizedBox(height: 8),
        ReportLink(target: ReportTarget.service, targetId: s.id, what: 'service'),
      ],
    );
  }
}

/// Main photo with the rest as small thumbnails underneath
/// (`ServicePhotoGallery`); any photo opens full screen.
class _Photos extends StatelessWidget {
  const _Photos({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    void open(int i) => FullScreenGallery.open(context, photos: photos, initialIndex: i);

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => open(0),
            child: AppNetworkImage(
              url: photos.first,
              width: 140,
              height: 110,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i < photos.length; i++)
                  GestureDetector(
                    onTap: () => open(i),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: AppNetworkImage(
                        url: photos[i],
                        width: 40,
                        height: 40,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
