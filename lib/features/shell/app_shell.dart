import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../home/widgets/home_drawer.dart';

/// Bottom navigation mirroring the website's mobile nav:
/// Home · Services · Blood · Market · Biodata.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// The outer scaffold, so the home header can open [HomeDrawer] over the
  /// whole screen (bottom nav included), as the site's menu covers the page.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  static const _items = <_NavItem>[
    _NavItem('🏠', 'Home'),
    _NavItem('🧰', 'Services'),
    _NavItem('🩸', 'Blood'),
    _NavItem('🛒', 'Market'),
    _NavItem('💍', 'Biodata'),
  ];

  void _onTap(int index) {
    // Tapping the active tab again pops it back to its first screen, which is
    // what people expect from a tab bar.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
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
