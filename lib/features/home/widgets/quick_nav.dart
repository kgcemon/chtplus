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
      // `.quick-nav-section { padding: 10px 0 6px }` plus the 16px container.
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: HomeTileGrid(
        spacing: 10,
        children: [
          for (final item in _items)
            HomeTile(
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
            ),
        ],
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

/// Three tiles to a row, every row only as tall as its own tallest tile —
/// how `.quick-nav` and `.cat-grid` behave once they wrap to three columns.
/// A fixed row height would leave a gap under the short labels.
class HomeTileGrid extends StatelessWidget {
  const HomeTileGrid({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += _columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < _columns; column++) ...[
                if (column > 0) SizedBox(width: spacing),
                Expanded(
                  child: start + column < children.length
                      ? children[start + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
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
    this.maxLines,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool circle;

  /// Left unset the label wraps freely, the way the site's tiles grow to fit.
  /// Screens that place these in a fixed-height grid cap it instead.
  final int? maxLines;

  /// Drawn filled green, like the site's `.cat-tile-active`.
  final bool selected;

  // A browser rounds these line boxes to whole pixels: 35 for the 26px emoji,
  // 16 and 15 for the labels. Matching that keeps a row's intrinsic height
  // equal to the height it is laid out at, so no tile overflows by a fraction.
  static const _iconBox = 35.0;
  static const _labelLine = 16.0;
  static const _quickLabelLine = 15.0;

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
          // `.quick-nav-item { padding: 16px 6px }`, `.cat-tile { 16px 8px }`.
          padding: EdgeInsets.symmetric(horizontal: circle ? 6 : 8, vertical: 16),
          child: Column(
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
                  child: Text(emoji, style: const TextStyle(fontSize: 26, height: 1)),
                )
              else
                SizedBox(
                  height: _iconBox,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 26, height: 1)),
                  ),
                ),
              const SizedBox(height: 8),
              // Flexible so a script whose glyphs measure a shade taller than
              // the line box (Bengali, with its marks) squeezes into the row's
              // height instead of overflowing it.
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: circle ? 11.5 : 12.5,
                    height: (circle ? _quickLabelLine : _labelLine) /
                        (circle ? 11.5 : 12.5),
                    fontWeight: circle ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : AppColors.text,
                  ),
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
