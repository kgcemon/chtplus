import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../home/widgets/home_header.dart';
import '../widgets/site_layout.dart';

/// The signed-in user's own profile, laid out like the site's profile page:
/// cover and photo, then one card with the name and follow counts, work and
/// education, and a row per feature (donor, services, products, biodata,
/// chat …) each with its button.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(meProfileProvider);

    return Scaffold(
      appBar: const SiteAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(meProfileProvider);
          ref.invalidate(coinBalanceProvider);
          await ref.read(meProfileProvider.future);
        },
        child: profile.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(meProfileProvider),
              ),
            ],
          ),
          data: (me) {
            if (me == null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Please log in first to see your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SiteButton(
                      label: 'Log in / Sign up',
                      onPressed: () => context.push(Routes.login),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Cover(me: me),
                _ProfileCard(me: me),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cover photo with the round profile photo overlapping its lower edge
/// (`ProfileCover`).
class _Cover extends StatelessWidget {
  const _Cover({required this.me});

  final MeProfile me;

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
              child: (me.coverPhotoUrl ?? '').isEmpty
                  ? null
                  : AppNetworkImage(url: me.coverPhotoUrl, width: double.infinity, height: 150),
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
              child: Avatar(url: me.photoUrl, name: me.name, size: 96),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.me});

  final MeProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followListsProvider).valueOrNull;
    final coins = ref.watch(coinBalanceProvider).valueOrNull ?? 0;
    final stats = me.stats;

    Future<void> go(String route) async {
      await context.push(route);
      ref.invalidate(meProfileProvider);
    }

    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: AppColors.border),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name, follow counts, phone and the Edit button.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            me.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        VerifiedBadge(active: me.blueBadge, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => go('/profile/follows?tab=followers'),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${follows?.followers.length ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                            const TextSpan(text: ' Followers · '),
                            TextSpan(
                              text: '${follows?.following.length ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                            const TextSpan(text: ' Following'),
                          ],
                        ),
                        style: _sub,
                      ),
                    ),
                    if ((me.phone ?? '').isNotEmpty) Text(me.phone!, style: _sub),
                    if ((me.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(me.bio!, style: const TextStyle(fontSize: 13.5, height: 1.55)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SiteButton(label: 'Edit', outlined: true, onPressed: () => go('/profile/edit')),
            ],
          ),
          // About: where they live, where from, relationship, when they joined.
          if ((me.currentCity ?? '').isNotEmpty ||
              (me.hometown ?? '').isNotEmpty ||
              (me.relationshipStatus ?? '').isNotEmpty ||
              me.work.isNotEmpty ||
              me.education.isNotEmpty) ...[
            divider,
            for (final w in me.work)
              _AboutLine(
                '💼',
                [if ((w.position ?? '').isNotEmpty) w.position!, w.company].join(' at '),
              ),
            for (final e in me.education) _AboutLine('🎓', e.institution),
            if ((me.currentCity ?? '').isNotEmpty) _AboutLine('🏠', 'Lives in ${me.currentCity}'),
            if ((me.hometown ?? '').isNotEmpty) _AboutLine('📍', 'From ${me.hometown}'),
            if ((me.relationshipStatus ?? '').isNotEmpty)
              _AboutLine('❤️', Fmt.relationshipLabel(me.relationshipStatus)),
          ],
          divider,
          _Row(
            icon: '🩸',
            text: me.donor == null ? 'You are not registered as a blood donor' : 'Blood donor',
            detail: me.donor?.bloodGroup,
            button: me.donor == null ? 'Become a donor' : 'Update',
            onTap: () => go('/donors/register'),
          ),
          divider,
          _Row(
            icon: '🛠️',
            text: stats.servicesCount == 0
                ? 'You have not added any services yet'
                : 'Services (${stats.servicesCount})',
            button: 'Services',
            onTap: () => go(Routes.myServices),
          ),
          divider,
          _Row(
            icon: '🛍️',
            text: stats.marketplaceCount == 0
                ? 'You have not added any products yet'
                : 'Products (${stats.marketplaceCount})',
            button: 'Products',
            onTap: () => go(Routes.myListings),
          ),
          divider,
          _Row(
            icon: '💍',
            text: stats.biodataCount == 0
                ? 'You have not submitted a biodata yet'
                : 'Biodata (${stats.biodataCount})',
            button: 'Biodata',
            onTap: () => go(Routes.myBiodata),
          ),
          divider,
          _Row(icon: '💬', text: 'Chat', button: 'Inbox', onTap: () => go(Routes.chat)),
          divider,
          _Row(
            icon: '🔖',
            text: 'Saved (${stats.savedCount})',
            button: 'Saved',
            onTap: () => go(Routes.saved),
          ),
          divider,
          _Row(icon: '🪙', text: '$coins coins', button: 'Buy coins', onTap: () => go(Routes.coins)),
          divider,
          _Row(
            icon: '⚙️',
            text: 'Settings & privacy',
            button: 'Settings',
            onTap: () => go(Routes.settings),
          ),
        ],
      ),
    );
  }

  static const _sub = TextStyle(fontSize: 13, color: AppColors.textSecondary);
}

class _AboutLine extends StatelessWidget {
  const _AboutLine(this.icon, this.text);

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(icon, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// Emoji, a line of text (with an optional grey detail under it) and a small
/// outlined button (`.profile-row`).
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.text,
    required this.button,
    required this.onTap,
    this.detail,
  });

  final String icon;
  final String text;
  final String? detail;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(icon, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 14)),
              if ((detail ?? '').isNotEmpty)
                Text(detail!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SiteButton(label: button, outlined: true, onPressed: onTap),
      ],
    );
  }
}
