import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/catalog_providers.dart';
import '../../../providers/feature_providers.dart';
import '../../../router.dart';
import '../../shell/app_shell.dart';

/// Sticky header used by every main page, laid out like the website's
/// `HomeHeader` on a phone: the menu button on the left, the logo centred,
/// and — once signed in — the chat and notification bells on the right.
/// Everything else lives in the drawer.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = _HeaderParts.of(context, ref);
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      toolbarHeight: _HeaderParts.height,
      backgroundColor: AppColors.forestDark,
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      leading: parts.leading,
      centerTitle: true,
      title: parts.title,
      actions: parts.actions,
    );
  }
}

/// The same header as a plain app bar, for pages whose body scrolls itself.
class SiteAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SiteAppBar({super.key, this.bottom});

  /// Optional strip under the header (tabs, a progress bar).
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(_HeaderParts.height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = _HeaderParts.of(context, ref);
    return AppBar(
      elevation: 0,
      toolbarHeight: _HeaderParts.height,
      backgroundColor: AppColors.forestDark,
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      leading: parts.leading,
      centerTitle: true,
      title: parts.title,
      actions: parts.actions,
      bottom: bottom,
    );
  }
}

/// Leading button, logo and bells shared by [HomeHeader] and [SiteAppBar].
class _HeaderParts {
  const _HeaderParts(this.leading, this.title, this.actions);

  static const height = 64.0;

  final Widget leading;
  final Widget title;
  final List<Widget> actions;

  factory _HeaderParts.of(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final unreadChats = ref.watch(chatUnreadCountProvider).valueOrNull ?? 0;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    // Pages pushed over the tabs (Doctors, …) get a back button where the
    // tabs have the menu.
    final canPop = Navigator.of(context).canPop();

    return _HeaderParts(
      Center(
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: canPop
                ? () => Navigator.of(context).maybePop()
                : () => AppShell.scaffoldKey.currentState?.openDrawer(),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                canPop ? Icons.arrow_back_rounded : Icons.menu_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
      InkWell(
        onTap: () => context.go(Routes.home),
        child: const SiteLogo(),
      ),
      [
        if (signedIn) ...[
          _BellButton(
            icon: Icons.chat_bubble_outline_rounded,
            count: unreadChats,
            onTap: () => context.push(Routes.chat),
          ),
          _BellButton(
            icon: Icons.notifications_none_rounded,
            count: unreadNotifications,
            onTap: () => context.push(Routes.notifications),
          ),
        ],
        const SizedBox(width: 10),
      ],
    );
  }
}

/// The admin-uploaded logo, or the site's text logo ("🌄 CHT Plus") when none
/// is set or it cannot be loaded.
class SiteLogo extends ConsumerWidget {
  const SiteLogo({super.key, this.height = 38});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = AppConfig.absoluteUrl(
      ref.watch(appRemoteConfigProvider).valueOrNull?.logoUrl,
    );
    if (url == null) return const _TextLogo();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height, maxWidth: 200),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => SizedBox(height: height),
        errorWidget: (_, __, ___) => const _TextLogo(),
      ),
    );
  }
}

class _TextLogo extends StatelessWidget {
  const _TextLogo();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: '🌄 CHT ',
        children: [
          TextSpan(text: 'Plus', style: TextStyle(color: AppColors.amber)),
        ],
      ),
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
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
            top: 8,
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
