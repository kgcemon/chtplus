import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';

/// Placeholder that matches the real home layout, so nothing shifts when the
/// data lands.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(
              aspectRatio: 3 / 1,
              child: SkeletonBox(height: double.infinity, radius: AppRadius.card),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (_, __) => const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: 46, height: 46, radius: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 52, height: 9),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 150, height: 17),
            const SizedBox(height: 14),
            SizedBox(
              height: 232,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) => const SizedBox(
                  width: 172,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 108, radius: AppRadius.card),
                      SizedBox(height: 10),
                      SkeletonBox(height: 12),
                      SizedBox(height: 7),
                      SkeletonBox(width: 100, height: 10),
                      SizedBox(height: 7),
                      SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 130, height: 17),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SkeletonBox(width: 52, height: 52, radius: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 140, height: 12),
                          SizedBox(height: 8),
                          SkeletonBox(width: 90, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
