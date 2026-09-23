import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

/// Bookmark toggle. Posting the same item twice removes it, which is how the
/// `/api/saved` route behaves.
class SaveButton extends ConsumerStatefulWidget {
  const SaveButton({
    super.key,
    required this.targetType,
    required this.targetId,
    this.light = true,
    this.size = 18,
  });

  final String targetType;
  final String targetId;

  /// True on top of a photo, where the icon needs its own dark backing.
  final bool light;
  final double size;

  @override
  ConsumerState<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<SaveButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await ref.read(meRepositoryProvider).toggleSaved(
            targetType: widget.targetType,
            targetId: widget.targetId,
          );
      ref.invalidate(savedItemsProvider);
      if (mounted) {
        AppSnackbar.success(context, saved ? 'Saved' : 'Removed from saved');
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref
        .watch(savedKeysProvider)
        .contains('${widget.targetType}:${widget.targetId}');

    return Material(
      color: widget.light ? Colors.black.withValues(alpha: 0.35) : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            size: widget.size,
            color: saved
                ? AppColors.amber
                : (widget.light ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
