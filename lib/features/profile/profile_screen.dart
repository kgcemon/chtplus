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

/// The signed-in user's own profile: identity, counters and every "my ..."
/// destination in one place.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(meProfileProvider);
    final coins = ref.watch(coinBalanceProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
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
              return const EmptyState(
                icon: Icons.account_circle_outlined,
                message: 'Sign in to see your profile.',
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _Header(me: me),
                _StatsRow(me: me),
                const SizedBox(height: 8),
                _MenuGroup(
                  title: 'My content',
                  items: [
                    _MenuItem(
                      icon: Icons.handyman_outlined,
                      label: 'My services',
                      trailing: '${me.stats.servicesCount}',
                      route: Routes.myServices,
                    ),
                    _MenuItem(
                      icon: Icons.storefront_outlined,
                      label: 'My adverts',
                      trailing: '${me.stats.marketplaceCount}',
                      route: Routes.myListings,
                    ),
                    _MenuItem(
                      icon: Icons.favorite_outline_rounded,
                      label: 'My biodata',
                      trailing: '${me.stats.biodataCount}',
                      route: Routes.myBiodata,
                    ),
                    _MenuItem(
                      icon: Icons.event_note_outlined,
                      label: 'My appointments',
                      route: Routes.myAppointments,
                    ),
                    _MenuItem(
                      icon: Icons.bookmark_outline_rounded,
                      label: 'Saved',
                      trailing: '${me.stats.savedCount}',
                      route: Routes.saved,
                    ),
                  ],
                ),
                _MenuGroup(
                  title: 'Blood donation',
                  items: [
                    _MenuItem(
                      icon: Icons.bloodtype_outlined,
                      label: me.donor == null
                          ? 'Become a blood donor'
                          : 'Update donor profile',
                      trailing: me.donor?.bloodGroup,
                      route: '/donors/register',
                    ),
                  ],
                ),
                _MenuGroup(
                  title: 'Account',
                  items: [
                    _MenuItem(
                      icon: Icons.monetization_on_outlined,
                      label: 'Coins & subscription',
                      trailing: '$coins',
                      route: Routes.coins,
                    ),
                    _MenuItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      route: Routes.chat,
                    ),
                    _MenuItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      route: Routes.notifications,
                    ),
                    _MenuItem(
                      icon: Icons.edit_outlined,
                      label: 'Edit profile',
                      route: '/profile/edit',
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings & privacy',
                      route: Routes.settings,
                    ),
                  ],
                ),
                if (me.work.isNotEmpty || me.education.isNotEmpty)
                  _BackgroundSection(work: me.work, education: me.education),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.me});

  final MeProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AppNetworkImage(
                url: me.coverPhotoUrl,
                width: double.infinity,
                height: 140,
                placeholderIcon: Icons.landscape_outlined,
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 4),
                  ),
                  child: Avatar(url: me.photoUrl, name: me.name, size: 88),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 10,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.push('/profile/edit');
                    ref.invalidate(meProfileProvider);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    backgroundColor: AppColors.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      me.name,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                  ),
                  VerifiedBadge(active: me.blueBadge, size: 18),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                me.email,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if ((me.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  me.bio!,
                  style: const TextStyle(fontSize: 13.5, height: 1.55),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  if ((me.area ?? '').isNotEmpty)
                    _MetaChip(icon: Icons.place_outlined, label: me.area!),
                  if ((me.currentCity ?? '').isNotEmpty)
                    _MetaChip(icon: Icons.home_outlined, label: 'Lives in ${me.currentCity}'),
                  if ((me.hometown ?? '').isNotEmpty)
                    _MetaChip(icon: Icons.cottage_outlined, label: 'From ${me.hometown}'),
                  if ((me.relationshipStatus ?? '').isNotEmpty)
                    _MetaChip(
                      icon: Icons.favorite_outline_rounded,
                      label: Fmt.relationshipLabel(me.relationshipStatus),
                    ),
                  if (me.createdAt != null)
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: 'Joined ${Fmt.date(me.createdAt)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.me});

  final MeProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followListsProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _Stat(
              value: '${follows?.followers.length ?? 0}',
              label: 'Followers',
              onTap: () => context.push('/profile/follows?tab=followers'),
            ),
            const _StatDivider(),
            _Stat(
              value: '${follows?.following.length ?? 0}',
              label: 'Following',
              onTap: () => context.push('/profile/follows?tab=following'),
            ),
            const _StatDivider(),
            _Stat(
              value: '${me.stats.reviewsCount}',
              label: 'Reviews',
              onTap: () => context.push('/u/${me.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.border);
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final String? trailing;
}

class _MenuGroup extends ConsumerWidget {
  const _MenuGroup({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 52),
                ListTile(
                  onTap: () async {
                    await context.push(items[i].route);
                    ref.invalidate(meProfileProvider);
                  },
                  leading: Icon(items[i].icon, size: 21, color: AppColors.forestDark),
                  title: Text(
                    items[i].label,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((items[i].trailing ?? '').isNotEmpty)
                        Text(
                          items[i].trailing!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BackgroundSection extends StatelessWidget {
  const _BackgroundSection({required this.work, required this.education});

  final List<WorkEntry> work;
  final List<EducationEntry> education;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Work & education'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in work)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline_rounded,
                            size: 17, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [
                              if ((entry.position ?? '').isNotEmpty) entry.position!,
                              entry.company,
                            ].join(' at '),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (entry.isCurrent)
                          const StatusPill(label: 'Current', color: AppColors.forest),
                      ],
                    ),
                  ),
                for (final entry in education)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
    );
  }
}
