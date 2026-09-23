import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../models/biodata.dart';
import '../../providers/feature_providers.dart';
import 'biodata_wizard_screen.dart';

class MyBiodataScreen extends ConsumerWidget {
  const MyBiodataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biodata = ref.watch(myBiodataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My biodata')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/biodata/submit');
          ref.invalidate(myBiodataProvider);
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Submit new'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myBiodataProvider);
          await ref.read(myBiodataProvider.future);
        },
        child: biodata.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(myBiodataProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.favorite_outline_rounded,
                    title: 'No biodata yet',
                    message:
                        'Submit your biodata and, once an admin verifies it, it appears in the matrimony list.',
                    actionLabel: 'Submit biodata',
                    onAction: () async {
                      await context.push('/biodata/submit');
                      ref.invalidate(myBiodataProvider);
                    },
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _MyBiodataTile(biodata: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _MyBiodataTile extends ConsumerWidget {
  const _MyBiodataTile({required this.biodata});

  final Biodata biodata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = biodata.photos.isEmpty ? null : biodata.photos.first;

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
                placeholderIcon: Icons.person_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      biodata.biodataNo ?? 'Biodata',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        StatusPill(
                          label: dataLabel(biodata.gender),
                          color: biodata.isBride
                              ? const Color(0xFFC2185B)
                              : AppColors.forest,
                        ),
                        const SizedBox(width: 6),
                        StatusPill(
                          label: biodata.unlocked ? 'Published' : 'Awaiting verification',
                          color: biodata.unlocked ? AppColors.forest : AppColors.amber,
                          icon: biodata.unlocked
                              ? Icons.check_circle_outline
                              : Icons.hourglass_empty_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (biodata.age != null) '${biodata.age} yrs',
                        if ((biodata.height ?? '').isNotEmpty) biodata.height!,
                        if ((biodata.area ?? '').isNotEmpty) biodata.area!,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!biodata.unlocked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF8A5A00)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'An admin is reviewing this biodata. It is not public yet.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Color(0xFF6B4600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: biodata.unlocked
                      ? () => context.push('/biodata/view/${biodata.id}')
                      : null,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => BiodataWizardScreen(existing: biodata),
                      ),
                    );
                    if (saved == true) ref.invalidate(myBiodataProvider);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
