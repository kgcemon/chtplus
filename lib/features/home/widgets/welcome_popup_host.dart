import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';
import '../../../core/theme.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../providers/catalog_providers.dart';

/// Shows the admin-configured welcome image once per day, the way the website's
/// `WelcomePopup` does.
class WelcomePopupHost extends ConsumerStatefulWidget {
  const WelcomePopupHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WelcomePopupHost> createState() => _WelcomePopupHostState();
}

class _WelcomePopupHostState extends ConsumerState<WelcomePopupHost> {
  bool _handled = false;

  bool _shownToday() {
    final last = Prefs.instance.getString(PrefKeys.welcomePopupSeenAt);
    if (last == null) return false;
    final seen = DateTime.tryParse(last);
    if (seen == null) return false;
    return DateTime.now().difference(seen).inHours < 24;
  }

  Future<void> _maybeShow() async {
    if (_handled || _shownToday()) return;
    _handled = true;

    final popup = ref.read(welcomePopupProvider).valueOrNull;
    if (popup == null || !mounted) return;

    await Prefs.instance
        .setString(PrefKeys.welcomePopupSeenAt, DateTime.now().toIso8601String());
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            GestureDetector(
              onTap: popup.url == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      Launchers.url(context, popup.url);
                    },
              child: AppNetworkImage(
                url: popup.imageUrl,
                fit: BoxFit.contain,
                placeholderIcon: Icons.campaign_outlined,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Waiting for the config means the popup only appears once there is
    // something to show, never as an empty flash.
    ref.listen(welcomePopupProvider, (_, next) {
      if (next.valueOrNull != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
      }
    });
    // Touch the provider so it starts loading.
    ref.watch(welcomePopupProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: widget.child,
    );
  }
}
