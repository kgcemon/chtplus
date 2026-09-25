import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/public_profile.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../home/widgets/home_header.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(userId));
    final me = ref.watch(currentUserProvider);

    return profile.when(
      loading: () => const Scaffold(appBar: SiteAppBar(), body: AppLoader()),
      error: (error, _) => Scaffold(
        appBar: const SiteAppBar(),
        body: ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
        ),
      ),
      data: (data) => Scaffold(
        body: _Content(profile: data, isMe: me?.id == data.id),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.profile, required this.isMe});

  final PublicProfile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final about = ref.watch(userAboutProvider(profile.id)).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(publicProfileProvider(profile.id));
        ref.invalidate(userAboutProvider(profile.id));
        await ref.read(publicProfileProvider(profile.id).future);
      },
      child: CustomScrollView(
        slivers: [
          const HomeHeader(),
          // The cover and the card under it are one sliver so the profile
          // photo can overlap the cover: slivers paint in reverse order, which
          // is what used to draw the cover on top of the photo.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Cover(profile: profile),
                  _HeaderCard(profile: profile, about: about, isMe: isMe),
                ],
              ),
            ),
          ),
          if (profile.work.isNotEmpty || profile.education.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Work & education'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (final entry in profile.work)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  const Icon(Icons.work_outline_rounded,
                                      size: 17, color: AppColors.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      [
                                        if ((entry.position ?? '').isNotEmpty)
                                          entry.position!,
                                        entry.company,
                                      ].join(' at '),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final entry in profile.education)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  const Icon(Icons.school_outlined,
                                      size: 17, color: AppColors.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.institution,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if ((entry.passingYear ?? '').isNotEmpty)
                                    Text(
                                      entry.passingYear!,
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
                    ),
                  ),
                ],
              ),
            ),
          if (profile.donor != null)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Blood donor'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DonorCard(donor: profile.donor!),
                  ),
                ],
              ),
            ),
          if (profile.services.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Services',
                    subtitle: '${profile.services.length} listed',
                  ),
                  SizedBox(
                    height: 262,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: profile.services.length,
                      itemExtent: 182,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 172,
                          child: ServiceCard(service: profile.services[index]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (profile.listings.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Marketplace adverts',
                    subtitle: '${profile.listings.length} listed',
                  ),
                  SizedBox(
                    height: 262,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: profile.listings.length,
                      itemExtent: 178,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 168,
                          child: ListingCard(listing: profile.listings[index]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Cover photo with the round profile photo overlapping its lower edge — the
/// same cover the signed-in user sees on their own profile.
class _Cover extends StatelessWidget {
  const _Cover({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.forestDark, AppColors.forest],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: (profile.coverPhotoUrl ?? '').isEmpty
                  ? null
                  : AppNetworkImage(
                      url: profile.coverPhotoUrl,
                      width: double.infinity,
                      height: 150,
                    ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 4),
              ),
              child: Avatar(url: profile.photoUrl, name: profile.name, size: 96),
            ),
          ),
        ],
      ),
    );
  }
}

/// Name, bio, the about lines, follow counts and the follow/message buttons in
/// one card, laid out like the signed-in user's own profile.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.about,
    required this.isMe,
  });

  final PublicProfile profile;
  final UserAbout? about;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final meta = <Widget>[
      if ((profile.area ?? '').isNotEmpty)
        _Meta(icon: Icons.place_outlined, label: profile.area!),
      if ((about?.currentCity ?? '').isNotEmpty)
        _Meta(
          icon: Icons.home_outlined,
          label: 'Lives in ${about!.currentCity}',
        ),
      if ((about?.hometown ?? '').isNotEmpty)
        _Meta(icon: Icons.cottage_outlined, label: 'From ${about!.hometown}'),
      if ((about?.relationshipStatus ?? '').isNotEmpty)
        _Meta(
          icon: Icons.favorite_outline_rounded,
          label: Fmt.relationshipLabel(about!.relationshipStatus),
        ),
      if (profile.createdAt != null)
        _Meta(
          icon: Icons.schedule_rounded,
          label: 'Joined ${Fmt.date(profile.createdAt)}',
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              VerifiedBadge(active: profile.blueBadge, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${profile.followerCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const TextSpan(text: ' Followers · '),
                TextSpan(
                  text: '${profile.followingCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const TextSpan(text: ' Following'),
              ],
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if ((profile.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile.bio!,
              style: const TextStyle(fontSize: 13.5, height: 1.55),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Wrap(spacing: 14, runSpacing: 8, children: meta),
          ],
          if (!isMe) ...[
            const SizedBox(height: 16),
            _ActionRow(profile: profile),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerStatefulWidget {
  const _ActionRow({required this.profile});

  final PublicProfile profile;

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _busy = false;

  Future<void> _toggleFollow(bool following) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(meRepositoryProvider).toggleFollow(widget.profile.id);
      ref.invalidate(isFollowingProvider(widget.profile.id));
      ref.invalidate(publicProfileProvider(widget.profile.id));
      ref.invalidate(followListsProvider);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
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
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .startConversation(widget.profile.id);
      if (mounted) {
        context.push(
          '/chat/$conversationId?name=${Uri.encodeComponent(widget.profile.name)}',
        );
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following =
        ref.watch(isFollowingProvider(widget.profile.id)).valueOrNull ?? false;

    return Row(
      children: [
        Expanded(
          child: following
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : () => _toggleFollow(following),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Following'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                )
              : FilledButton.icon(
                  onPressed: _busy ? null : () => _toggleFollow(following),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: const Text('Follow'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.profile.chatEnabled ? _message : null,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
            label: Text(
              widget.profile.chatEnabled ? 'Message' : 'Chat off',
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
