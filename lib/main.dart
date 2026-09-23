import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/prefs.dart';
import 'core/storage/token_store.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read local state before the first frame so a returning user lands straight
  // on their signed-in home screen instead of flashing a login prompt.
  await Prefs.init();
  await TokenStore.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final container = ProviderContainer();
  // Confirms the stored token against the server; the UI does not wait for it.
  unawaited(container.read(authControllerProvider.notifier).restore());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ChtPlusApp(),
    ),
  );
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
