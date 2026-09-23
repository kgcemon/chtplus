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
import '../../models/service.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../widgets/sponsor_sheet.dart';
import 'service_form_screen.dart';

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(myServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/services/add');
          ref.invalidate(myServicesProvider);
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add service'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myServicesProvider);
          await ref.read(myServicesProvider.future);
        },
        child: services.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(myServicesProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.handyman_outlined,
                    title: 'No services yet',
                    message:
                        'Add your business or service so people in the hill districts can find you.',
                    actionLabel: 'Add a service',
                    onAction: () async {
                      await context.push('/services/add');
                      ref.invalidate(myServicesProvider);
                    },
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _MyServiceTile(service: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _MyServiceTile extends ConsumerWidget {
  const _MyServiceTile({required this.service});

  final ServiceItem service;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete this service?',
      message:
          '"${service.providerName}" and its reviews will be removed permanently. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(serviceRepositoryProvider).delete(service.id);
      ref.invalidate(myServicesProvider);
      ref.invalidate(servicesProvider);
      ref.invalidate(homeFeedProvider);
      if (context.mounted) AppSnackbar.success(context, 'Service deleted.');
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = service.allPhotos.isEmpty ? null : service.allPhotos.first;
    final boostedUntil = service.sponsoredUntil;

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
                placeholderIcon: Icons.handyman_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        StatusPill.forStatus(service.status),
                        if (service.isSponsorActive) ...[
                          const SizedBox(width: 6),
                          const StatusPill(
                            label: 'Boosted',
                            color: AppColors.amber,
                            icon: Icons.bolt_rounded,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: service.rating,
                      count: service.ratingCount,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (service.isSponsorActive && boostedUntil != null) ...[
            const SizedBox(height: 8),
            Text(
              'Boost runs until ${Fmt.date(boostedUntil)}',
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
                onTap: () => context.push('/services/${service.id}'),
              ),
              _Action(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ServiceFormScreen(existing: service),
                    ),
                  );
                  if (saved == true) ref.invalidate(myServicesProvider);
                },
              ),
              _Action(
                icon: Icons.bolt_rounded,
                label: 'Boost',
                color: AppColors.amber,
                onTap: () async {
                  final boosted = await SponsorSheet.open(
                    context,
                    target: SponsorTarget.service,
                    id: service.id,
                  );
                  if (boosted) ref.invalidate(myServicesProvider);
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
