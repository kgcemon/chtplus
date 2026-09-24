import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/doctor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../home/widgets/home_header.dart';
import '../widgets/detail_parts.dart';
import '../widgets/site_layout.dart';

const _chamberTypes = {
  'hospital': 'Hospital',
  'diagnostic_center': 'Diagnostic Center',
  'pharmacy': 'Pharmacy',
  'clinic': 'Clinic',
};

/// A doctor's page laid out like the site's: "← All doctors", a card with the
/// photo beside name, qualifications, specialty, love count and the
/// conditions they treat, then one card per chamber.
class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(doctorDetailProvider(id));

    return doctor.when(
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
                onRetry: () => ref.invalidate(doctorDetailProvider(id)),
              ),
            ),
          ],
        ),
      ),
      data: (d) => _Content(
        doctor: d,
        onRefresh: () async {
          ref.invalidate(doctorDetailProvider(id));
          await ref.read(doctorDetailProvider(id).future);
        },
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.doctor, required this.onRefresh});

  final DoctorDetail doctor;
  final Future<void> Function() onRefresh;

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
      final result = await ref.read(doctorRepositoryProvider).toggleLike(widget.doctor.id);
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
    final d = widget.doctor;

    return DetailPage(
      header: const HomeHeader(),
      onRefresh: widget.onRefresh,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SiteButton(
            label: '← All doctors',
            outlined: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final photoWidth = constraints.maxWidth * 0.4;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: photoWidth,
                      height: photoWidth,
                      child: (d.photoUrl ?? '').isEmpty
                          ? ColoredBox(
                              color: AppColors.forestLight,
                              child: Center(
                                child: Text(
                                  d.name.isEmpty ? '?' : d.name.characters.first,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forestDark,
                                  ),
                                ),
                              ),
                            )
                          : AppNetworkImage(url: d.photoUrl, width: photoWidth, height: photoWidth),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        if ((d.qualifications ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(d.qualifications!, style: _sub),
                        ],
                        if ((d.specialty ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(d.specialty!, style: _sub),
                        ],
                        const SizedBox(height: 8),
                        Material(
                          color: _liked ? AppColors.red : const Color(0xFFFFF5F4),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: _liked ? AppColors.red : const Color(0xFFF7D9D6),
                            ),
                          ),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: _toggleLike,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              child: Text(
                                '${_liked ? '❤️' : '🤍'} $_likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _liked ? Colors.white : AppColors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (d.services.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Conditions they treat',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          for (final s in d.services)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('•  ${s.name}', style: const TextStyle(fontSize: 13.5)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text('Chambers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (d.chambers.isEmpty)
          const Text(
            'This doctor has no active chamber right now.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          )
        else
          for (final chamber in d.chambers) ...[
            _ChamberCard(doctorId: d.id, chamber: chamber),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  static const _sub = TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4);
}

/// White rounded card (`.admin-card`).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ChamberCard extends ConsumerWidget {
  const _ChamberCard({required this.doctorId, required this.chamber});

  final String doctorId;
  final Chamber chamber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = chamber;
    final next = c.nextAvailable;
    final fees = [
      if (c.consultationFee != null) 'Consultation fee: ${Fmt.taka(c.consultationFee)}',
      if (c.serialFee != null) 'Serial fee: ${Fmt.taka(c.serialFee)}',
    ].join(' · ');
    final place = [c.district, c.area].where((e) => (e ?? '').isNotEmpty).join(', ');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((c.type ?? '').isNotEmpty)
            Tag(
              _chamberTypes[c.type] ?? c.type!,
              color: AppColors.textSecondary,
            ),
          const SizedBox(height: 4),
          Text(
            c.organizationName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '📍 $place',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          if (fees.isNotEmpty) ...[
            Text(fees, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
          ],
          if ((c.notes ?? '').isNotEmpty) ...[
            Text(c.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
          ],
          if (next != null)
            Text(
              '🗓️ Next serial: ${Fmt.date(next.dateTime)}'
              '${next.timeRange.isEmpty ? '' : ' · ${next.timeRange}'}'
              ' · ${next.remainingCapacity} available',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.forestDark,
              ),
            )
          else
            const Tag(
              'Serial booking is closed',
              color: Color(0xFF9A6700),
              background: Color(0xFFFFF3D6),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => context.push(
              ref.read(isSignedInProvider) ? '/doctors/$doctorId/book/${c.id}' : Routes.login,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply for a serial'),
          ),
        ],
      ),
    );
  }
}
