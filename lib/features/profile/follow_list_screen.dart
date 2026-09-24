import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../models/user.dart';
import '../../providers/feature_providers.dart';
import '../widgets/site_scaffold.dart';

class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followListsProvider);

    return DefaultTabController(
      initialIndex: initialTab,
      length: 2,
      child: SiteScaffold(
          title: 'Connections',
          headerBottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        body: follows.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(followListsProvider),
          ),
          data: (lists) => TabBarView(
            children: [
              _UserList(
                users: lists.followers,
                emptyMessage: 'Nobody is following you yet.',
              ),
              _UserList(
                users: lists.following,
                emptyMessage:
                    'You are not following anyone yet. Follow people to hear when they post something new.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users, required this.emptyMessage});

  final List<UserChip> users;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Avatar(url: user.photoUrl, name: user.name, size: 44),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              VerifiedBadge(active: user.blueBadge, size: 14),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/u/${user.id}'),
        );
      },
    );
  }
}
