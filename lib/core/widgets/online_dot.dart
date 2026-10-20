import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';

/// Whether a user is online now; re-checked every 45 s while shown.
final onlineProvider = FutureProvider.autoDispose.family<bool, String>((ref, userId) {
  final timer = Timer(const Duration(seconds: 45), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(presenceRepositoryProvider).isOnline(userId);
});

/// The green "online now" dot for a profile picture of [avatarSize]
/// (site: app/PresenceDot.js). Draws nothing while offline or unknown.
class OnlineDot extends ConsumerWidget {
  const OnlineDot({super.key, required this.userId, required this.avatarSize});

  final String userId;
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider(userId)).valueOrNull ?? false;
    if (!online) return const SizedBox.shrink();
    final dot = (avatarSize * 0.26).clamp(9.0, 34.0);
    return Semantics(
      label: 'Online now',
      child: Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          color: const Color(0xFF31A24C),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: (dot / 5).clamp(2.0, 5.0)),
        ),
      ),
    );
  }
}
