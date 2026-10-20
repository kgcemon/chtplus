import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../router.dart';
import '../home/widgets/home_drawer.dart';

/// Bottom navigation mirroring the website's mobile nav:
/// Home · Services · Blood · Market · Biodata — plus an app-only Profile
/// button (it opens sign-in for a visitor).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// The outer scaffold, so the home header can open [HomeDrawer] over the
  /// whole screen (bottom nav included), as the site's menu covers the page.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _items = <_NavItem>[
    _NavItem('🏠', 'Home'),
    _NavItem('🧰', 'Services'),
    _NavItem('🩸', 'Blood'),
    _NavItem('🛒', 'Market'),
    _NavItem('💍', 'Biodata'),
  ];

  static const _exitWindow = Duration(seconds: 2);
  DateTime? _lastBackOnHome;

  StatefulNavigationShell get shell => widget.shell;

  void _onTap(int index) {
    // Tapping the active tab again pops it back to its first screen, which is
    // what people expect from a tab bar.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  /// The Android back button. The router gets the first go — it pops any
  /// screen opened on top (details, settings…) and lets a screen's own
  /// PopScope act (the services list closes a category). Only when there is
  /// nothing left to pop, instead of quitting the app: close the menu if it is
  /// open, go to Home from another tab, and on Home quit only on a second
  /// press within two seconds.
  Future<bool> _onBack() async {
    final scaffold = AppShell.scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) {
      scaffold!.closeDrawer();
      return true;
    }
    final router = GoRouter.of(context);
    if (await router.routerDelegate.popRoute()) return true;
    if (!mounted) return true;

    if (shell.currentIndex != 0) {
      shell.goBranch(0);
      return true;
    }
    final now = DateTime.now();
    if (_lastBackOnHome != null && now.difference(_lastBackOnHome!) < _exitWindow) {
      await SystemNavigator.pop();
      return true;
    }
    _lastBackOnHome = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitWindow,
        ),
      );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: _onBack,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      key: AppShell.scaffoldKey,
      drawer: const HomeDrawer(),
      // Opened only by the home header's menu button, not by an edge swipe
      // on other tabs.
      drawerEnableOpenDragGesture: false,
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      active: shell.currentIndex == i,
                      onTap: () => _onTap(i),
                    ),
                  ),
                Expanded(
                  child: _NavButton(
                    item: const _NavItem('👤', 'Profile'),
                    active: false,
                    onTap: () => context.push(Routes.profile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.emoji, this.label);

  final String emoji;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The site's `.bottom-nav-item`: emoji over label, the active tab on a
    // soft green pill.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: active ? AppColors.forestLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 19, height: 1)),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.forestDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
