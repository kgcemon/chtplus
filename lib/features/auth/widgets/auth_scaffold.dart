import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../providers/catalog_providers.dart';
import '../../../router.dart';
import '../google_signin_service.dart';

/// Which tab of the sign-in sheet a screen is.
enum AuthTab { login, register, none }

/// Shared chrome for the sign-in, register and reset screens, drawn like the
/// site's sign-in popup: "Log in" / "New account" tabs with a round ✕, then
/// the form. The reset screen ([AuthTab.none]) shows its title instead.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.tab = AuthTab.none,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final AuthTab tab;

  @override
  Widget build(BuildContext context) {
    void close() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(Routes.home);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
          children: [
            Row(
              children: [
                if (tab == AuthTab.none) ...[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _TabButton(
                      label: 'Log in',
                      active: tab == AuthTab.login,
                      onTap: () => context.replace(Routes.login),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TabButton(
                      label: 'New account',
                      active: tab == AuthTab.register,
                      onTap: () => context.replace(Routes.register),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Material(
                  color: AppColors.bg,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: close,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.close_rounded, size: 17, color: AppColors.text),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (subtitle.isNotEmpty) ...[
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One half of the Log in / New account switch (`.cv-tab`).
class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.forest : AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: active ? AppColors.forest : AppColors.border),
      ),
      child: InkWell(
        onTap: active ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey field caption above an input, as the site's forms label them.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _start(clientId),
          icon: _busy
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4285F4),
                  ),
                ),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.text,
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              'By continuing you agree to the ',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            _LegalLink('Terms of use', AppConfig.termsUrl),
            const Text(
              ' and ',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            _LegalLink('Privacy policy', AppConfig.privacyPolicyUrl),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or use your email',
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
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Launchers.url(context, url),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.forestDark,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Small helper the auth screens use to report a failure consistently.
void showAuthError(BuildContext context, Object error) {
  AppSnackbar.error(context, error.toString());
}
