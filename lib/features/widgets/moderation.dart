import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/moderation_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

/// Report and block actions, shared by every screen that shows content other
/// people posted. Google Play requires both for apps with user content.
class Moderation {
  const Moderation._();

  static bool _requireSignIn(BuildContext context, WidgetRef ref) {
    if (ref.read(isSignedInProvider)) return true;
    context.push(Routes.login);
    return false;
  }

  /// Asks why [targetId] is objectionable and files a report for the admins.
  static Future<void> report(
    BuildContext context,
    WidgetRef ref, {
    required ReportTarget target,
    required String targetId,
    String what = 'this',
  }) async {
    if (!_requireSignIn(context, ref)) return;
    final sent = await AppDialogs.sheet<bool>(
      context,
      child: _ReportSheet(target: target, targetId: targetId, what: what),
    );
    if (sent == true && context.mounted) {
      AppSnackbar.success(context, 'Thanks — our team will review your report within 24 hours.');
    }
  }

  /// Blocks [userId] after a confirmation. Returns true when blocked.
  static Future<bool> block(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String name,
  }) async {
    if (!_requireSignIn(context, ref)) return false;
    final ok = await AppDialogs.confirm(
      context,
      title: 'Block $name?',
      message:
          'They will not be able to message you, and you will not see chats with them. You can unblock them any time from Settings → Blocked users.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    try {
      await ref.read(moderationRepositoryProvider).block(userId);
      _refresh(ref, userId);
      if (context.mounted) AppSnackbar.success(context, '$name has been blocked.');
      return true;
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
      return false;
    }
  }

  static Future<void> unblock(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String name,
  }) async {
    try {
      await ref.read(moderationRepositoryProvider).unblock(userId);
      _refresh(ref, userId);
      if (context.mounted) AppSnackbar.success(context, '$name has been unblocked.');
    } on ApiException catch (error) {
      if (context.mounted) AppSnackbar.error(context, error.message);
    }
  }

  static void _refresh(WidgetRef ref, String userId) {
    ref.invalidate(isBlockedProvider(userId));
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(chatInboxProvider);
    ref.invalidate(isFollowingProvider(userId));
    ref.invalidate(followListsProvider);
  }
}

/// A quiet "Report" link placed at the end of a detail screen.
class ReportLink extends ConsumerWidget {
  const ReportLink({
    super.key,
    required this.target,
    required this.targetId,
    required this.what,
  });

  final ReportTarget target;
  final String targetId;

  /// e.g. "service", "listing" — shown as "Report this service".
  final String what;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton.icon(
        onPressed: () => Moderation.report(
          context,
          ref,
          target: target,
          targetId: targetId,
          what: 'this $what',
        ),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: Text('Report this $what'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.target, required this.targetId, required this.what});

  final ReportTarget target;
  final String targetId;
  final String what;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(moderationRepositoryProvider).report(
            target: widget.target,
            targetId: widget.targetId,
            reason: reason,
            details: _details.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackbar.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Report ${widget.what}',
            subtitle: 'Why are you reporting it?',
          ),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              children: [
                for (final entry in reportReasons.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                    dense: true,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(hintText: 'More details (optional)'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton(
              onPressed: _reason == null || _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size(double.infinity, 46),
              ),
              child: Text(_busy ? 'Sending…' : 'Send report'),
            ),
          ),
        ],
      ),
    );
  }
}
