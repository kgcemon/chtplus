import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.next});

  final String? next;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  // Set once the server has emailed a sign-up code to this address.
  String? _verifyEmail;
  // Filled from an invite link the user opened (/r/<code>), like the site.
  late final _referralCode = TextEditingController(
    text: ref.read(authRepositoryProvider).pendingReferralCode(),
  );
  bool _obscure = true;
  bool _busy = false;
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _referralCode.dispose();
    super.dispose();
  }

  void _onSignedIn() {
    if (!mounted) return;
    // A new account always lands on onboarding; the router's redirect handles
    // sending them on from there.
    context.go(Routes.home);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      showAuthError(context, 'Please accept the privacy policy to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      final needsCode = await ref.read(authControllerProvider.notifier).register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            referralCode: _referralEnabled ? _referralCode.text : null,
          );
      if (!needsCode) {
        _onSignedIn();
      } else if (mounted) {
        setState(() {
          _verifyEmail = _email.text.trim().toLowerCase();
          _code.clear();
        });
      }
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, _signupErrors[error.code] ?? error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _signupErrors = {
    'too_many_signups': 'Too many new accounts from this network — please try again later.',
    'too_many_codes': 'Too many codes sent — please try again later.',
    'invalid_code': 'That code is not right — check the email and try again.',
    'code_expired': 'That code has expired — send a new one.',
    'too_many_attempts': 'Too many wrong tries — send a new code.',
    'no_pending_signup': 'Please start the sign-up again.',
  };

  Future<void> _verify() async {
    final email = _verifyEmail;
    if (email == null || _code.text.trim().length != 6) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(email: email, code: _code.text.trim());
      _onSignedIn();
    } on ApiException catch (error) {
      if (!mounted) return;
      final left = error.data?['attemptsLeft'];
      showAuthError(
        context,
        '${_signupErrors[error.code] ?? error.message}${error.code == 'invalid_code' && left != null ? ' ($left tries left)' : ''}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = _verifyEmail;
    if (email == null) return;
    try {
      await ref.read(authRepositoryProvider).resendSignupCode(email);
      if (mounted) AppSnackbar.success(context, 'A new code has been sent.');
    } on ApiException catch (error) {
      if (!mounted) return;
      final wait = error.data?['waitSeconds'];
      showAuthError(
        context,
        error.code == 'wait' && wait != null ? 'Please wait $wait seconds before asking again.' : (_signupErrors[error.code] ?? error.message),
      );
    }
  }

  /// Step 2 of an email sign-up: the 6-digit code.
  Widget _codeStep() {
    return AuthScaffold(
      title: 'Check your email',
      subtitle: '',
      tab: AuthTab.register,
      children: [
        Text.rich(
          TextSpan(
            text: 'We sent a 6-digit code to ',
            children: [
              TextSpan(text: _verifyEmail, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
              const TextSpan(text: '. Enter it to finish creating your account.'),
            ],
          ),
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _verify(),
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: '······', counterText: ''),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy || _code.text.trim().length != 6 ? null : _verify,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Verify and create account'),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: _resend, child: const Text('Send the code again')),
            TextButton(onPressed: () => setState(() => _verifyEmail = null), child: const Text('Use a different email')),
          ],
        ),
        const Text(
          'Can’t find it? Check the spam folder.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _google(String credential) async {
    try {
      // A code typed here counts for a Google sign-up too: the Google call
      // sends the stored code (see AuthRepository.googleSignIn).
      final typed = _referralCode.text.trim();
      if (_referralEnabled && typed.isNotEmpty) {
        await ref.read(authRepositoryProvider).savePendingReferralCode(typed);
      }
      await ref.read(authControllerProvider.notifier).signInWithGoogle(credential);
      _onSignedIn();
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, error.message);
    }
  }

  bool get _referralEnabled =>
      ref.read(appRemoteConfigProvider).valueOrNull?.referralEnabled ?? false;

  @override
  Widget build(BuildContext context) {
    if (_verifyEmail != null) return _codeStep();
    final referralEnabled =
        ref.watch(appRemoteConfigProvider).valueOrNull?.referralEnabled ?? false;
    return AuthScaffold(
      title: 'New account',
      subtitle: '',
      tab: AuthTab.register,
      children: [
        GoogleSignInButton(onCredential: _google),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Enter your email address';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                    return 'That email address does not look right';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Password (at least 6 characters)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
              if (referralEnabled) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referralCode,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Referral code (optional)',
                    prefixIcon: Icon(Icons.card_giftcard_rounded, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => setState(() => _agreed = !_agreed),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (value) => setState(() => _agreed = value ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'I agree to the ',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Launchers.url(context, AppConfig.termsUrl),
                          child: const Text(
                            'terms of use',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.forestDark,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          ' and ',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Launchers.url(context, AppConfig.privacyPolicyUrl),
                          child: const Text(
                            'privacy policy',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.forestDark,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          '.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Create account'),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
