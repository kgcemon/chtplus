import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../providers/feature_providers.dart';
import '../widgets/moderation.dart';
import '../widgets/site_scaffold.dart';

/// Settings → Blocked users: everyone the signed-in user has blocked, with an
/// unblock button for each.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);

    return SiteScaffold(
      title: 'Blocked users',
      subtitle: 'People you blocked cannot message you',
      body: blocked.when(
        loading: () => const AppLoader(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (users) => users.isEmpty
            ? const EmptyState(
                icon: Icons.block_rounded,
                message: 'You have not blocked anyone.',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: Avatar(url: user.photoUrl, name: user.name, size: 44),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => context.push('/u/${user.id}'),
                    trailing: OutlinedButton(
                      onPressed: () => Moderation.unblock(
                        context,
                        ref,
                        userId: user.id,
                        name: user.name,
                      ),
                      child: const Text('Unblock'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
