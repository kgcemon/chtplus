import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feature_providers.dart';
import '../../../router.dart';

/// Sticky app bar with the wordmark, notification and chat bells and the
/// viewer's avatar — the same set the website's `HomeHeader` shows.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unreadChats = ref.watch(chatUnreadCountProvider).valueOrNull ?? 0;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      toolbarHeight: 58,
      backgroundColor: AppColors.forestDark,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'C+',
              style: TextStyle(
                color: AppColors.forestDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'CHT Plus',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        _BellButton(
          icon: Icons.notifications_none_rounded,
          count: unreadNotifications,
          onTap: () => context.push(Routes.notifications),
        ),
        _BellButton(
          icon: Icons.chat_bubble_outline_rounded,
          count: unreadChats,
          onTap: () => context.push(Routes.chat),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.push(user == null ? Routes.login : Routes.profile),
            child: user == null
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.account_circle_outlined,
                        color: Colors.white, size: 26),
                  )
                : Avatar(
                    url: user.photoUrl,
                    name: user.name,
                    size: 32,
                    borderColor: Colors.white24,
                  ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: InkWell(
            onTap: () => context.go(Routes.services),
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, size: 19, color: AppColors.textSecondary),
                  SizedBox(width: 9),
                  Text(
                    'Search services, products, donors…',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.icon, required this.count, required this.onTap});

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 23),
          visualDensity: VisualDensity.compact,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.forestDark, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
