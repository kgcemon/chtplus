import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../providers/catalog_providers.dart';
import '../google_signin_service.dart';

/// Shared chrome for the sign-in, register and reset screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 36),
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.forestDark,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: const Text(
                'C+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google" button. It hides itself when the admin has not set a
/// Google client id, matching the website.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, required this.onCredential});

  final Future<void> Function(String credential) onCredential;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _start(String clientId) async {
    setState(() => _busy = true);
    try {
      final token = await GoogleSignInService.instance.idToken(clientId);
      // null means the person backed out of the account chooser — stay quiet.
      if (token == null) return;
      await widget.onCredential(token);
    } on GoogleSignInFailure catch (error) {
      // Previously this failed silently, which made a misconfigured client id
      // look like a dead button.
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appRemoteConfigProvider).valueOrNull;
    final clientId = config?.googleClientId ?? '';
    if (clientId.isEmpty || !GoogleSignInService.instance.isSupported) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _start(clientId),
          icon: _busy
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.g_mobiledata_rounded, size: 26),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// Small helper the auth screens use to report a failure consistently.
void showAuthError(BuildContext context, Object error) {
  AppSnackbar.error(context, error.toString());
}
