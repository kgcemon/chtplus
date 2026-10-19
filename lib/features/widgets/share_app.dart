import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/utils/launchers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../referral/refer_screen.dart';

/// Shares the Play Store link through the phone's share sheet. A signed-in
/// user's Refer & Win code goes along (when the feature is on), so a friend
/// who installs from it earns them both coins.
Future<void> shareApp(WidgetRef ref) async {
  var text = 'Download the ${AppConfig.appName} app — services, blood donors, '
      'marketplace and more in the Hill Tracts:\n${AppConfig.playStoreUrl}';

  final signedIn = ref.read(isSignedInProvider);
  final referralEnabled =
      ref.read(appRemoteConfigProvider).valueOrNull?.referralEnabled ?? false;
  if (signedIn && referralEnabled) {
    try {
      final summary = await ref
          .read(referralSummaryProvider.future)
          .timeout(const Duration(seconds: 4));
      if (summary.enabled && summary.code.isNotEmpty) {
        final bonus = summary.referredReward > 0
            ? ' to get ${summary.referredReward} free coins'
            : '';
        text += '\n\nSign up with my code ${summary.code}$bonus.';
      }
    } catch (_) {
      // Offline or slow — share the plain link rather than nothing.
    }
  }
  await Launchers.share(text, subject: AppConfig.appName);
}
