import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';

/// Placeholder that matches the real home layout, so nothing shifts when the
/// data lands: the 3:1 hero, the quick-nav tiles, then a section head over a
/// category grid and two rows of cards.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  /// Fixed row heights taken from the tiles they stand in for.
  static const _quickNavTile = 105.0;
  static const _categoryTile = 93.0;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(
              aspectRatio: 3 / 1,
              child: SkeletonBox(height: double.infinity, radius: AppRadius.card),
            ),
            // The hero's 10px bottom padding plus the quick nav's 10px top.
            const SizedBox(height: 20),
            const _TileGrid(count: 6, extent: _quickNavTile, spacing: 10),
            // The quick nav's 6px bottom padding plus the section's 18px top.
            const SizedBox(height: 24),
            const _SectionHead(),
            const _TileGrid(count: 6, extent: _categoryTile, spacing: 12),
            const SizedBox(height: 36),
            const _SectionHead(),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 223,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, __) => const SkeletonBox(
                height: double.infinity,
                radius: AppRadius.card,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A title and subtitle bar standing in for `_SectionHead`, including its
/// 16px bottom margin.
class _SectionHead extends StatelessWidget {
  const _SectionHead();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 160, height: 18),
          SizedBox(height: 6),
          SkeletonBox(width: 210, height: 12),
        ],
      ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.count,
    required this.extent,
    required this.spacing,
  });

  final int count;
  final double extent;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: extent,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemBuilder: (_, __) => const SkeletonBox(
        height: double.infinity,
        radius: AppRadius.card,
      ),
    );
  }
}
