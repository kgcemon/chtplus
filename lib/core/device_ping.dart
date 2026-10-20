import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api/api_client.dart';
import 'storage/prefs.dart';

/// Tells the server "this phone opened the app", so Admin → Dashboard can show
/// how many phones have the app and how many used it today — without Play
/// Console and without needing a login.
///
/// The id is random, made on first launch and kept in local storage; nothing
/// about the phone or the person is sent. Reinstalling the app makes a new id.
/// Sent on launch and when the app comes back to the foreground, at most once
/// per [_every].
class DevicePing with WidgetsBindingObserver {
  DevicePing._();

  static final instance = DevicePing._();

  static const _every = Duration(hours: 1);

  bool _started = false;
  bool _busy = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    ping();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ping();
  }

  static String _deviceId() {
    final prefs = Prefs.instance;
    final existing = prefs.getString(PrefKeys.deviceId);
    if (existing != null && existing.length == 32) return existing;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    prefs.setString(PrefKeys.deviceId, id);
    return id;
  }

  Future<void> ping() async {
    if (_busy) return;
    final prefs = Prefs.instance;
    final last = prefs.getInt(PrefKeys.devicePingAt);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < _every.inMilliseconds) return;
    _busy = true;
    try {
      String? version;
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      await ApiClient.instance.post('/api/devices/ping', body: {
        'deviceId': _deviceId(),
        'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
        'appVersion': version,
      });
      await prefs.setInt(PrefKeys.devicePingAt, now);
    } catch (_) {
      // Offline or server down: try again next time the app opens.
    } finally {
      _busy = false;
    }
  }
}
