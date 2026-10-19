import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/core_providers.dart';

/// (type, id) → how many people opened it. Kept while any card shows it.
final viewCountProvider = FutureProvider.autoDispose.family<int, (String, String)>(
  (ref, key) => ref.watch(viewsRepositoryProvider).count(key.$1, key.$2),
);

/// 👁 12 — the small view count on a card, like the site's `ViewCount`.
class ViewCountBadge extends ConsumerWidget {
  const ViewCountBadge({
    super.key,
    required this.type,
    required this.id,
    this.fontSize = 11,
    this.pill = false,
  });

  /// service · donor · listing · biodata
  final String type;
  final String id;
  final double fontSize;

  /// Drawn as a bordered pill, to sit beside the donor card's ❤️ / 💬 pills.
  final bool pill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(viewCountProvider((type, id))).valueOrNull;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_outlined, size: fontSize + 3, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          count == null ? '·' : '$count',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
    final semantics = Semantics(label: '${count ?? 0} views', child: content);
    if (!pill) return semantics;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: semantics,
    );
  }
}

/// Wrap a detail screen with this to count the visit once when it opens, and
/// refresh that item's number on the cards behind it.
class ViewTracker extends ConsumerStatefulWidget {
  const ViewTracker({super.key, required this.type, required this.id, required this.child});

  final String type;
  final String id;
  final Widget child;

  @override
  ConsumerState<ViewTracker> createState() => _ViewTrackerState();
}

class _ViewTrackerState extends ConsumerState<ViewTracker> {
  @override
  void initState() {
    super.initState();
    _record();
  }

  Future<void> _record() async {
    final key = (widget.type, widget.id);
    await ref.read(viewsRepositoryProvider).record(widget.type, widget.id);
    if (mounted) ref.invalidate(viewCountProvider(key));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
