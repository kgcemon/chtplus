import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../router.dart';

/// The six shortcut tiles the website puts directly under the hero banner.
class QuickNav extends StatelessWidget {
  const QuickNav({super.key});

  static const _items = <_QuickItem>[
    _QuickItem('🧰', 'Services', Routes.services, tab: true),
    _QuickItem('🩸', 'Blood donors', Routes.donors, tab: true),
    _QuickItem('🛒', 'Marketplace', Routes.marketplace, tab: true),
    _QuickItem('💍', 'Matrimony', Routes.biodata, tab: true),
    _QuickItem('🩺', 'Doctors', Routes.doctors),
    _QuickItem('🧳', 'Tour & travels', '${Routes.services}?category=cat_tour'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.15,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => item.tab ? context.go(item.path) : context.push(item.path),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.forestLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickItem {
  const _QuickItem(this.emoji, this.label, this.path, {this.tab = false});

  final String emoji;
  final String label;
  final String path;

  /// True when the destination is one of the five bottom-nav branches, which
  /// must be switched to rather than pushed on top.
  final bool tab;
}
