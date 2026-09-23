import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../core/utils/deep_links.dart';
import '../router.dart';
import 'auth_provider.dart';
import 'catalog_providers.dart';
import 'feature_providers.dart';

/// Push notifications through OneSignal, the same service the website uses.
///
/// The app id comes from `/api/app-config`, so an admin can turn push on or
/// off without a new release; when it is empty nothing is initialized. The
/// signed-in user id is set as the OneSignal external id, which is how the
/// server addresses a push ("send this to user X").
///
/// Tapping a notification opens the screen it refers to: the backend puts a
/// site path in the payload (`/chat/12`, `/donors?open=bd_1`, ...) and
/// [appRouteForLink] maps that onto an app route.
class PushService {
  PushService(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.user?.id == next.user?.id) return;
      _syncUser(next.user?.id);
    }, fireImmediately: true);

    _ref.listen(appRemoteConfigProvider, (_, next) {
      final appId = next.valueOrNull?.oneSignalAppId;
      if (appId != null && appId.isNotEmpty) _initialize(appId);
    }, fireImmediately: true);
  }

  final Ref _ref;
  bool _initialized = false;

  Future<void> _initialize(String appId) async {
    if (_initialized) return;
    _initialized = true;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      OneSignal.initialize(appId);

      OneSignal.Notifications.addClickListener(_onClick);

      // Arriving while the app is open should still refresh the badges.
      OneSignal.Notifications.addForegroundWillDisplayListener((_) {
        _refreshBadges();
      });

      await _syncUser(_ref.read(currentUserProvider)?.id);
    } catch (error) {
      // Push is a convenience: a device without Play Services, or a bad
      // configuration, must never stop the app from starting.
      debugPrint('OneSignal init skipped: $error');
    }
  }

  void _onClick(OSNotificationClickEvent event) {
    _refreshBadges();

    // `launchUrl` is what the server set; `result.url` is what the SDK
    // resolved, which is the same value for our payloads but survives an
    // action button being tapped.
    final link = event.notification.launchUrl ?? event.result.url;
    final route = appRouteForLink(link) ?? notificationFallbackRoute;
    unawaited(_navigate(route));
  }

  void _refreshBadges() {
    _ref.invalidate(chatUnreadCountProvider);
    _ref.invalidate(notificationsProvider);
  }

  /// Pushes [route] once there is a navigator to push onto.
  ///
  /// Tapping a notification can launch the app from cold, in which case this
  /// runs before the first frame — so it waits for the navigator rather than
  /// dropping the tap. It gives up after a few seconds so a failed start can
  /// never leave a retry loop running.
  Future<void> _navigate(String route) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (rootNavigatorKey.currentState != null) {
        try {
          _ref.read(routerProvider).push(route);
        } catch (error) {
          debugPrint('Notification navigation failed for $route: $error');
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('Notification navigation gave up waiting for the navigator.');
  }

  Future<void> _syncUser(String? userId) async {
    if (!_initialized) return;
    try {
      if (userId == null) {
        await OneSignal.logout();
        return;
      }
      await OneSignal.login(userId);
      // Asked for only after sign-in, when the value of notifications is
      // obvious, rather than on the very first launch.
      await OneSignal.Notifications.requestPermission(true);
    } catch (error) {
      debugPrint('OneSignal user sync skipped: $error');
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
