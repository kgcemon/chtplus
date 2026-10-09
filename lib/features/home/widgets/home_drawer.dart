import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feature_providers.dart';
import '../../../router.dart';
import '../../auth/google_signin_service.dart';
import 'home_header.dart';

/// The slide-in menu behind the header's ☰ button, matching the website's
/// mobile nav: logo and close button, then profile, coins and chat as outlined
/// rows on the dark green, with log out pinned to the bottom.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final coins = ref.watch(coinBalanceProvider).valueOrNull ?? 0;
    final unreadChats = ref.watch(chatUnreadCountProvider).valueOrNull ?? 0;
    final width = MediaQuery.sizeOf(context).width * 0.8;

    // Closes the drawer before leaving, so it is not still open on return.
    void go(String path) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(path);
    }

    return Drawer(
      width: width > 300 ? 300 : width,
      backgroundColor: AppColors.forestDark,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 14),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    const Flexible(child: SiteLogo(height: 34)),
                    const Spacer(),
                    Material(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (user == null)
                _DrawerItem(
                  onTap: () => go(Routes.login),
                  background: Colors.white,
                  borderColor: Colors.white,
                  center: true,
                  child: const Text(
                    'Log in / Sign up',
                    style: TextStyle(color: AppColors.forestDark, fontWeight: FontWeight.w700),
                  ),
                ),
              if (user == null)
                const _ShareAppItem()
              else ...[
                _DrawerItem(
                  onTap: () => go(Routes.profile),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Avatar(url: user.photoUrl, name: user.name, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                VerifiedBadge(active: user.blueBadge, size: 13),
                              ],
                            ),
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xB8FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _DrawerItem(
                  onTap: () => go(Routes.coins),
                  background: const Color(0x33F0A202),
                  borderColor: const Color(0xA6F0A202),
                  child: Text(
                    '🪙  $coins coins — buy more',
                    style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w700),
                  ),
                ),
                _DrawerItem(
                  onTap: () => go(Routes.chat),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        unreadChats > 0
                            ? 'Chat (${unreadChats > 9 ? '9+' : unreadChats})'
                            : 'Chat',
                      ),
                    ],
                  ),
                ),
                const _ShareAppItem(),
                const Spacer(),
                _DrawerItem(
                  onTap: () => _signOut(context, ref),
                  background: Colors.white,
                  borderColor: Colors.white,
                  center: true,
                  child: const Text(
                    'Log out',
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to post, message or book.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;

    navigator.pop();
    await GoogleSignInService.instance.signOut();
    await ref.read(authControllerProvider.notifier).signOut();
    router.go(Routes.home);
  }
}

/// "Share app": sends the Play Store link through the phone's share sheet.
class _ShareAppItem extends StatelessWidget {
  const _ShareAppItem();

  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      onTap: () => Launchers.share(
        'Download the ${AppConfig.appName} app:\n${AppConfig.playStoreUrl}',
        subject: AppConfig.appName,
      ),
      child: const Row(
        children: [
          Icon(Icons.share_rounded, size: 18, color: Colors.white),
          SizedBox(width: 12),
          Text('Share app'),
        ],
      ),
    );
  }
}

/// One outlined, lightly filled row of the drawer (`.mobile-nav-item`).
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.onTap,
    required this.child,
    this.background = const Color(0x1AFFFFFF),
    this.borderColor = const Color(0x47FFFFFF),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.center = false,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color background;
  final Color borderColor;
  final EdgeInsets padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              child: center ? Center(child: child) : child,
            ),
          ),
        ),
      ),
    );
  }
}
