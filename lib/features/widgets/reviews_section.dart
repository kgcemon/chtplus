import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/engagement.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

/// Ratings, loves and replies for a service or a blood-donor profile.
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (targetType: targetType, targetId: targetId);
    final reviews = ref.watch(reviewsProvider(key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Reviews',
          subtitle: reviews.valueOrNull == null
              ? null
              : '${reviews.value!.length} ${reviews.value!.length == 1 ? 'review' : 'reviews'}',
          actionLabel: 'Write one',
          onAction: () => _writeReview(context, ref),
        ),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 10),
              ],
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$error',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  message: 'No reviews yet. Be the first to share your experience.',
                  compact: true,
                ),
              );
            }
            return Column(
              children: [
                for (final review in items)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _ReviewTile(review: review, targetKey: key),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _writeReview(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    final result = await AppDialogs.sheet<bool>(
      context,
      child: _ReviewComposer(targetType: targetType, targetId: targetId),
    );
    if (result == true) {
      ref.invalidate(reviewsProvider((targetType: targetType, targetId: targetId)));
      ref.invalidate(myReviewsProvider);
    }
  }
}

class _ReviewTile extends ConsumerStatefulWidget {
  const _ReviewTile({required this.review, required this.targetKey});

  final Review review;
  final ({String targetType, String targetId}) targetKey;

  @override
  ConsumerState<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<_ReviewTile> {
  late bool _loved = widget.review.lovedByMe;
  late int _loveCount = widget.review.loveCount;
  bool _showReplies = false;
  bool _busy = false;

  Future<void> _toggleLove() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      // Optimistic: the tap should feel instant and is corrected below.
      _loved = !_loved;
      _loveCount += _loved ? 1 : -1;
    });
    try {
      final result =
          await ref.read(reviewRepositoryProvider).toggleLove(widget.review.id);
      if (mounted) {
        setState(() {
          _loved = result.loved;
          _loveCount = result.loveCount;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loved = widget.review.lovedByMe;
          _loveCount = widget.review.loveCount;
        });
        AppSnackbar.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reply() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    final text = await AppDialogs.prompt(
      context,
      title: 'Reply to this review',
      hint: 'Write your reply',
      maxLines: 3,
      maxLength: 1000,
      confirmLabel: 'Post reply',
    );
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(reviewRepositoryProvider).reply(widget.review.id, text);
      ref.invalidate(reviewRepliesProvider(widget.review.id));
      ref.invalidate(reviewsProvider(widget.targetKey));
      if (mounted) setState(() => _showReplies = true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The reviewer's name and photo open their profile, the same way
              // every other person's name does across the app.
              Expanded(
                child: InkWell(
                  onTap: review.reviewerUserId == null
                      ? null
                      : () => context.push('/u/${review.reviewerUserId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Avatar(name: review.reviewerName, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      review.reviewerName ?? 'Someone',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: review.reviewerUserId == null
                                            ? AppColors.text
                                            : AppColors.forestDark,
                                      ),
                                    ),
                                  ),
                                  VerifiedBadge(
                                    active: review.reviewerBlueBadge,
                                    size: 13,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                review.date ?? '',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              RatingStars(
                rating: review.rating.toDouble(),
                size: 13,
                showValue: false,
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionButton(
                icon: _loved ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                label: _loveCount == 0 ? 'Love' : '$_loveCount',
                color: _loved ? AppColors.red : AppColors.textSecondary,
                onTap: _toggleLove,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: review.replyCount == 0 ? 'Reply' : '${review.replyCount}',
                color: AppColors.textSecondary,
                onTap: () => setState(() => _showReplies = !_showReplies),
              ),
              const Spacer(),
              TextButton(
                onPressed: _reply,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Write a reply'),
              ),
            ],
          ),
          if (_showReplies) _RepliesList(reviewId: review.id),
        ],
      ),
    );
  }
}

class _RepliesList extends ConsumerWidget {
  const _RepliesList({required this.reviewId});

  final int reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(reviewRepliesProvider(reviewId));

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 6),
      child: replies.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SkeletonBox(width: 160, height: 10),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No replies yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            );
          }
          return Column(
            children: [
              for (final reply in items)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/u/${reply.userId}'),
                        child: Avatar(
                          url: reply.userPhotoUrl,
                          name: reply.userName,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () => context.push('/u/${reply.userId}'),
                                    child: Text(
                                      reply.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forestDark,
                                      ),
                                    ),
                                  ),
                                ),
                                VerifiedBadge(active: reply.userBlueBadge, size: 12),
                                const SizedBox(width: 6),
                                Text(
                                  reply.date ?? '',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              reply.replyText ?? '',
                              style: const TextStyle(fontSize: 12.5, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewComposer extends ConsumerStatefulWidget {
  const _ReviewComposer({required this.targetType, required this.targetId});

  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<_ReviewComposer> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      AppSnackbar.error(context, 'Please write a few words about your experience.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).create(
            targetType: widget.targetType,
            targetId: widget.targetId,
            rating: _rating,
            comment: comment,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Write a review',
            subtitle: 'Your name is shown with your review.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your rating',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => _rating = i),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          i <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 34,
                          color: AppColors.amber,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What was your experience like?',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post review'),
            ),
          ),
        ],
      ),
    );
  }
}
