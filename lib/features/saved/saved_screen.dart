import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/engagement.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/site_scaffold.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  static String? _routeFor(SavedItem item) {
    switch (item.targetType) {
      case 'service':
        return '/services/${item.targetId}';
      case 'donor':
        return '/donors/${item.targetId}';
      case 'marketplace_listing':
        return '/marketplace/listing/${item.targetId}';
      case 'biodata':
        return '/biodata/view/${item.targetId}';
      default:
        return null;
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'service':
        return Icons.handyman_outlined;
      case 'donor':
        return Icons.bloodtype_outlined;
      case 'marketplace_listing':
        return Icons.storefront_outlined;
      case 'biodata':
        return Icons.favorite_outline_rounded;
      default:
        return Icons.bookmark_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedItemsProvider);

    return SiteScaffold(
      title: 'Saved',
      subtitle: 'Services, products, donors and biodata you saved',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedItemsProvider);
          await ref.read(savedItemsProvider.future);
        },
        child: saved.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(savedItemsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.bookmark_outline_rounded,
                    title: 'Nothing saved yet',
                    message:
                        'Tap the bookmark on any service, advert, donor or biodata to keep it here for later.',
                    actionLabel: 'Browse services',
                    onAction: () => context.go(Routes.services),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final route = _routeFor(item);
                return AppCard(
                  onTap: route == null ? null : () => context.push(route),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.forestLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconFor(item.targetType),
                          size: 20,
                          color: AppColors.forestDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title ?? 'No longer available',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: item.title == null
                                    ? AppColors.textSecondary
                                    : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatusPill(
                                  label: item.typeLabel,
                                  color: AppColors.textSecondary,
                                ),
                                if ((item.subtitle ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      item.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () async {
                          try {
                            await ref.read(meRepositoryProvider).toggleSaved(
                                  targetType: item.targetType,
                                  targetId: item.targetId,
                                );
                            ref.invalidate(savedItemsProvider);
                            if (context.mounted) {
                              AppSnackbar.success(context, 'Removed from saved.');
                            }
                          } on ApiException catch (error) {
                            if (context.mounted) {
                              AppSnackbar.error(context, error.message);
                            }
                          }
                        },
                        icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
