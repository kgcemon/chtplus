import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../router.dart';

/// The six shortcut tiles the website puts directly under the hero banner:
/// white bordered cards, three per row on a phone, with the emoji in a soft
/// green circle.
class QuickNav extends StatelessWidget {
  const QuickNav({super.key});

  static const _items = <_QuickItem>[
    _QuickItem('🧰', 'Services', Routes.services, tab: true),
    _QuickItem('🩸', 'Blood Donors', Routes.donors, tab: true),
    _QuickItem('🛒', 'Marketplace', Routes.marketplace, tab: true),
    _QuickItem('💍', 'Matrimony', Routes.biodata, tab: true),
    _QuickItem('🩺', 'Doctor Appointments', Routes.doctors),
    // Not open yet: the site shows a "coming soon" popup instead of a page.
    _QuickItem('🧳', 'Tour & Travels', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 112,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];
          return HomeTile(
            emoji: item.emoji,
            label: item.label,
            circle: true,
            onTap: () {
              final path = item.path;
              if (path == null) {
                _showComingSoon(context);
              } else if (item.tab) {
                context.go(path);
              } else {
                context.push(path);
              }
            },
          );
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('🧳', style: TextStyle(fontSize: 40)),
        title: const Text(
          'Coming soon',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Tour & Travels is on its way — it will be available very soon.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// A white bordered tile with an emoji over a label — the site's
/// `.quick-nav-item` (with [circle]) and `.cat-tile` (without).
class HomeTile extends StatelessWidget {
  const HomeTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.circle = false,
    this.selected = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool circle;

  /// Drawn filled green, like the site's `.cat-tile-active`.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: selected ? AppColors.forest : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (circle)
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.forestLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: circle ? 11.5 : 12.5,
                  height: 1.3,
                  fontWeight: circle ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickItem {
  const _QuickItem(this.emoji, this.label, this.path, {this.tab = false});

  final String emoji;
  final String label;
  final String? path;

  /// True when the destination is one of the five bottom-nav branches, which
  /// must be switched to rather than pushed on top.
  final bool tab;
}
