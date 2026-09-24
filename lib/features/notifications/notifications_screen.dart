import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/deep_links.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/engagement.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../widgets/site_scaffold.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return SiteScaffold(
      title: 'Notifications',
      action: unread == 0
          ? null
          : TextButton(
              onPressed: () async {
                try {
                  await ref.read(meRepositoryProvider).markAllNotificationsRead();
                  ref.invalidate(notificationsProvider);
                } on ApiException catch (error) {
                  if (context.mounted) AppSnackbar.error(context, error.message);
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.forest),
              child: const Text('Mark all read'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notifications.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing new',
                    message:
                        'Reviews, replies, approvals and updates from people you follow show up here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
              itemBuilder: (context, index) => _NotificationTile(
                notification: items[index],
                onTap: () => _open(context, ref, items[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.read) {
      try {
        await ref.read(meRepositoryProvider).markNotificationRead(notification.id);
        ref.invalidate(notificationsProvider);
      } on ApiException {
        // Marking it read is best-effort; navigation still happens.
      }
    }
    // Same mapping a push tap uses, so both routes behave identically.
    final route = appRouteForLink(notification.link);
    if (route != null && context.mounted) context.push(route);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon {
    final title = notification.title.toLowerCase();
    if (title.contains('review')) return Icons.rate_review_outlined;
    if (title.contains('reply')) return Icons.mode_comment_outlined;
    if (title.contains('message')) return Icons.chat_bubble_outline_rounded;
    if (title.contains('donor') || title.contains('blood')) {
      return Icons.bloodtype_outlined;
    }
    if (title.contains('coin')) return Icons.monetization_on_outlined;
    if (title.contains('approve') || title.contains('published')) {
      return Icons.check_circle_outline;
    }
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: notification.read ? null : AppColors.forestLight.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: notification.read ? AppColors.bg : AppColors.forestLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _icon,
          size: 19,
          color: notification.read ? AppColors.textSecondary : AppColors.forestDark,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: notification.read ? FontWeight.w600 : FontWeight.w800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((notification.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              notification.body!,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            Fmt.relative(notification.createdAt),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
      trailing: notification.read
          ? null
          : Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.forest,
                shape: BoxShape.circle,
              ),
            ),
    );
  }
}
