import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import 'storage/prefs.dart';
import 'theme.dart';

/// Lets the updater show its "update ready" bar from outside any screen.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Keeps the Android app up to date through Google Play's in-app updates.
///
/// On launch and whenever the app comes back to the foreground it asks Play
/// whether a newer version is published:
/// * normally it starts a *flexible* update — Play asks once, the new version
///   downloads in the background while the app stays usable, then a bar
///   offers "Restart". Ignored, it installs by itself the next time the app
///   is opened;
/// * if the update has been out for [_forceAfterDays] days and still isn't
///   installed (or is published with priority 4–5 in Play Console), it runs
///   the *immediate* full-screen update instead.
///
/// Only works for builds installed from Play (including internal testing);
/// for debug / sideloaded builds Play reports an error, which is ignored.
class AppUpdater with WidgetsBindingObserver {
  AppUpdater._();

  static final instance = AppUpdater._();

  static const _forceAfterDays = 3;
  static const _recheckEvery = Duration(hours: 1);
  static const _askAgainAfter = Duration(days: 1);

  bool _started = false;
  bool _busy = false;
  bool _readyBarShown = false;
  DateTime? _lastCheck;

  void start() {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // Downloaded earlier but never restarted: install now, on open.
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }
      // An immediate update was interrupted (app killed mid-update): resume it.
      if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      final now = DateTime.now();
      if (_lastCheck != null && now.difference(_lastCheck!) < _recheckEvery) return;
      _lastCheck = now;

      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      // Already downloading in the background.
      if (info.installStatus == InstallStatus.downloading ||
          info.installStatus == InstallStatus.pending) {
        return;
      }

      final stale = (info.clientVersionStalenessDays ?? 0) >= _forceAfterDays;
      if (info.immediateUpdateAllowed && (stale || info.updatePriority >= 4)) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed && !_recentlyDeclined()) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          _showReadyBar();
        } else if (result == AppUpdateResult.userDeniedUpdate) {
          await Prefs.instance.setInt(
            PrefKeys.updateDeclinedAt,
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
    } catch (_) {
      // Not installed from Play, no Play Store, offline — nothing to do.
    } finally {
      _busy = false;
    }
  }

  bool _recentlyDeclined() {
    final at = Prefs.instance.getInt(PrefKeys.updateDeclinedAt);
    if (at == null) return false;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) < _askAgainAfter;
  }

  void _showReadyBar() {
    final messenger = appMessengerKey.currentState;
    if (messenger == null || _readyBarShown) return;
    _readyBarShown = true;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.forestDark,
        duration: const Duration(days: 1),
        content: const Text('A new version of CHT Plus is ready.'),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: const Color(0xFFFFD166),
          onPressed: () => InAppUpdate.completeFlexibleUpdate().catchError((_) {}),
        ),
      ),
    );
  }
}
