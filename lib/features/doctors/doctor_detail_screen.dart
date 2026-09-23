import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/doctor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(doctorDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor'),
        actions: [
          IconButton(
            onPressed: () => Launchers.shareWebLink(
              '/doctors/$id',
              title: doctor.valueOrNull?.name ?? 'Doctor on CHT Plus',
            ),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: doctor.when(
        loading: () => const AppLoader(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(doctorDetailProvider(id)),
        ),
        data: (item) => _Content(doctor: item),
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.doctor});

  final DoctorDetail doctor;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  late bool _liked = widget.doctor.likedByMe;
  late int _likeCount = widget.doctor.likeCount;
  bool _busy = false;

  Future<void> _toggleLike() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final result =
          await ref.read(doctorRepositoryProvider).toggleLike(widget.doctor.id);
      if (mounted) {
        setState(() {
          _liked = result.liked;
          _likeCount = result.likeCount;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _liked = widget.doctor.likedByMe;
          _likeCount = widget.doctor.likeCount;
        });
        AppSnackbar.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Container(
          width: double.infinity,
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
          child: Column(
            children: [
              Avatar(url: doctor.photoUrl, name: doctor.name, size: 96),
              const SizedBox(height: 14),
              Text(
                doctor.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              if ((doctor.specialty ?? '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  doctor.specialty!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.forestDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if ((doctor.qualifications ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  doctor.qualifications!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _toggleLike,
                    icon: Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      size: 17,
                      color: _liked ? AppColors.red : AppColors.textSecondary,
                    ),
                    label: Text('$_likeCount'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  if ((doctor.phone ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => Launchers.call(context, doctor.phone),
                      icon: const Icon(Icons.call_rounded, size: 17),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (doctor.services.isNotEmpty) ...[
          const SectionHeader(title: 'Services offered'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in doctor.services)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.forestLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        SectionHeader(
          title: 'Chambers',
          subtitle: doctor.chambers.isEmpty
              ? null
              : 'Pick a chamber to book a serial',
        ),
        if (doctor.chambers.isEmpty)
          const EmptyState(
            icon: Icons.local_hospital_outlined,
            message: 'This doctor has no active chamber right now.',
            compact: true,
          )
        else
          for (final chamber in doctor.chambers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ChamberCard(doctorId: doctor.id, chamber: chamber),
            ),
      ],
    );
  }
}

class _ChamberCard extends ConsumerWidget {
  const _ChamberCard({required this.doctorId, required this.chamber});

  final String doctorId;
  final Chamber chamber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = chamber.nextAvailable;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chamber.organizationName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (chamber.locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        chamber.locationLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if ((chamber.organizationPhone ?? '').isNotEmpty)
                IconButton(
                  onPressed: () => Launchers.call(context, chamber.organizationPhone),
                  icon: const Icon(Icons.call_outlined, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.forestLight,
                    foregroundColor: AppColors.forestDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (chamber.consultationFee != null)
                StatusPill(
                  label: 'Consultation ${Fmt.taka(chamber.consultationFee)}',
                  color: AppColors.forestDark,
                ),
              if (chamber.serialFee != null)
                StatusPill(
                  label: 'Serial fee ${Fmt.taka(chamber.serialFee)}',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          if ((chamber.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              chamber.notes!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: next == null ? AppColors.bg : AppColors.forestLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  next == null ? Icons.event_busy_outlined : Icons.event_available_rounded,
                  size: 17,
                  color: next == null ? AppColors.textSecondary : AppColors.forestDark,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    next == null
                        ? 'No open dates in the next 30 days'
                        : 'Next available: ${Fmt.date(next.dateTime)}'
                            '${next.timeRange.isEmpty ? '' : ' · ${next.timeRange}'}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: next == null
                          ? AppColors.textSecondary
                          : AppColors.forestDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: next == null
                ? null
                : () => context.push(
                      ref.read(isSignedInProvider)
                          ? '/doctors/$doctorId/book/${chamber.id}'
                          : Routes.login,
                    ),
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: Text(next == null ? 'No dates available' : 'Book a serial'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ],
      ),
    );
  }
}
