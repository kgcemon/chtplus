import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/donor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../../data/moderation_repository.dart';
import '../widgets/detail_parts.dart';
import '../widgets/reviews_section.dart';
import '../widgets/moderation.dart';

final _donorLikersProvider = FutureProvider.autoDispose.family<List<String>, String>(
  (ref, id) => ref.watch(donorRepositoryProvider).likerNames(id),
);

/// A donor's details, drawn like the site's donor popup: name with Follow and
/// "group · area" in the header, a big photo beside Call / Profile / Message,
/// the love reactions, then reviews.
class DonorDetailScreen extends ConsumerWidget {
  const DonorDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donor = ref.watch(donorDetailProvider(id));

    return donor.when(
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
            onRetry: () => ref.invalidate(donorDetailProvider(id)),
          ),
        ],
      ),
      data: (d) => _Content(donor: d),
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
  bool _showLikers = false;

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
      final result = await ref.read(donorRepositoryProvider).toggleLike(widget.donor.id);
      ref.invalidate(_donorLikersProvider(widget.donor.id));
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

  Future<void> _message() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    try {
      final conversationId =
          await ref.read(chatRepositoryProvider).startConversation(widget.donor.userId!);
      if (mounted) {
        context.push('/chat/$conversationId?name=${Uri.encodeComponent(widget.donor.name)}');
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donor;
    final area = (d.area ?? '').isNotEmpty ? d.area! : d.locationLabel;
    final likers = _showLikers ? ref.watch(_donorLikersProvider(d.id)) : null;

    return SheetPage(
      title: Row(
        children: [
          Flexible(child: Text(d.name)),
          FollowInline(userId: d.userId),
        ],
      ),
      subtitle: [d.bloodGroup ?? '', area].where((e) => e.isNotEmpty).join(' · '),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.forestLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: (d.photoUrl ?? '').isEmpty
                    ? Text(
                        d.name.isEmpty ? '?' : d.name.characters.first,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      )
                    : AppNetworkImage(url: d.photoUrl, width: 110, height: 110),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.eligible)
                    FilledButton(
                      onPressed: () => Launchers.call(context, d.phone),
                      style: smallButtonStyle(block: true),
                      child: const Text('📞 Call'),
                    )
                  else
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Donated recently',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (d.userId != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.push('/u/${d.userId}'),
                      style: smallButtonStyle(outlined: true, block: true),
                      child: const Text('👤 Profile'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _message,
                      style: smallButtonStyle(outlined: true, block: true),
                      child: const Text('💬 Message'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LovePill(
                label: '${_liked ? '❤️' : '🤍'} $_likeCount',
                onTap: _toggleLike,
                filled: _liked,
              ),
              const SizedBox(width: 8),
              _LovePill(
                label: 'liked this ${_showLikers ? '▲' : '▼'}',
                onTap: () => setState(() => _showLikers = !_showLikers),
              ),
            ],
          ),
        ),
        if (likers != null) ...[
          const SizedBox(height: 10),
          likers.when(
            loading: () => const _Note('Loading...'),
            error: (_, __) => const _Note('Could not load'),
            data: (names) => names.isEmpty
                ? const _Note('No one has liked this yet')
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in names)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '❤️ $name',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 16),
        ReviewsSection(targetType: 'donor', targetId: d.id),
        const SizedBox(height: 8),
        ReportLink(target: ReportTarget.donor, targetId: d.id, what: 'donor'),
      ],
    );
  }
}

/// Rounded red pill (`.likers-toggle`); [filled] once the viewer has loved.
class _LovePill extends StatelessWidget {
  const _LovePill({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.red : const Color(0xFFFFF5F4),
      shape: StadiumBorder(
        side: BorderSide(color: filled ? AppColors.red : const Color(0xFFF7D9D6)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppColors.red,
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary));
  }
}
