import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/donor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/reviews_section.dart';
import '../widgets/save_button.dart';

class DonorDetailScreen extends ConsumerWidget {
  const DonorDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donor = ref.watch(donorDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SaveButton(
              targetType: 'donor',
              targetId: id,
              light: false,
              size: 22,
            ),
          ),
        ],
      ),
      body: donor.when(
        loading: () => const AppLoader(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(donorDetailProvider(id)),
        ),
        data: (item) => _Content(donor: item),
      ),
      bottomNavigationBar: donor.valueOrNull == null
          ? null
          : _ContactBar(donor: donor.value!),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.donor});

  final Donor donor;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  late bool _liked = widget.donor.likedByMe;
  late int _likeCount = widget.donor.likeCount;
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
          await ref.read(donorRepositoryProvider).toggleLike(widget.donor.id);
      if (mounted) {
        setState(() {
          _liked = result.liked;
          _likeCount = result.likeCount;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _liked = widget.donor.likedByMe;
          _likeCount = widget.donor.likeCount;
        });
        AppSnackbar.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final donor = widget.donor;
    final waitDays = donor.daysUntilEligible;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          color: AppColors.surface,
          child: Column(
            children: [
              Stack(
                children: [
                  Avatar(url: donor.photoUrl, name: donor.name, size: 96),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        donor.bloodGroup ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                donor.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              if (donor.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  donor.locationLabel,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              StatusPill(
                label: donor.eligible
                    ? 'Available to donate'
                    : waitDays == null
                        ? 'Not available yet'
                        : 'Available in $waitDays days',
                color: donor.eligible ? AppColors.forest : AppColors.amber,
                icon: donor.eligible
                    ? Icons.check_circle_outline
                    : Icons.schedule_rounded,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RatingStars(rating: donor.rating, count: donor.ratingCount),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                            size: 17,
                            color: _liked ? AppColors.red : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$_likeCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              LabeledRow(
                label: 'Blood group',
                value: donor.bloodGroup ?? '—',
                icon: Icons.bloodtype_outlined,
              ),
              LabeledRow(
                label: 'Last donation',
                value: donor.lastDonationDate == null
                    ? 'Not recorded'
                    : Fmt.date(donor.lastDonationDate),
                icon: Icons.event_outlined,
              ),
              LabeledRow(
                label: 'Area',
                value: donor.locationLabel.isEmpty ? '—' : donor.locationLabel,
                icon: Icons.place_outlined,
              ),
            ],
          ),
        ),
        if (donor.userId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCard(
              onTap: () => context.push('/u/${donor.userId}'),
              child: const Row(
                children: [
                  Icon(Icons.account_circle_outlined, color: AppColors.forest),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View this donor\'s CHT Plus profile',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ReviewsSection(targetType: 'donor', targetId: donor.id),
      ],
    );
  }
}

class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.donor});

  final Donor donor;

  @override
  Widget build(BuildContext context) {
    if ((donor.phone ?? '').isEmpty) return const SizedBox.shrink();

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
                  onPressed: () => Launchers.call(context, donor.phone),
                  icon: const Icon(Icons.call_rounded, size: 19),
                  label: const Text('Call donor'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Launchers.sms(context, donor.phone),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(52, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Icon(Icons.sms_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
