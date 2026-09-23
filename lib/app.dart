import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/push_provider.dart';
import 'router.dart';

class ChtPlusApp extends ConsumerWidget {
  const ChtPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts push registration once the remote config has loaded; it is a
    // no-op when the admin has not configured OneSignal.
    ref.watch(pushServiceProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('bn')],
      builder: (context, child) {
        // Pins text scaling to a sane range so a very large system font does
        // not break the card layouts.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.25,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
