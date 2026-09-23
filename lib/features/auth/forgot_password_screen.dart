import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import 'widgets/auth_scaffold.dart';

/// Two steps on one screen: request a six-digit code by email, then set a new
/// password with it. Submitting the code signs the user straight in.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _requestKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_requestKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppSnackbar.success(
        context,
        'If that email is registered, a reset code is on its way.',
      );
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!(_resetKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).completeReset(
            email: _email.text,
            code: _code.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Password updated. You are signed in.');
      context.go(Routes.home);
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _codeSent ? 'Enter your code' : 'Reset your password',
      subtitle: _codeSent
          ? 'We sent a six-digit code to ${_email.text.trim()}. It expires in 10 minutes.'
          : 'Enter the email address on your account and we will send a reset code.',
      children: [
        Form(
          key: _requestKey,
          child: TextFormField(
            controller: _email,
            enabled: !_codeSent,
            keyboardType: TextInputType.emailAddress,
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
        ),
        if (!_codeSent) ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _requestCode,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset code'),
          ),
        ] else ...[
          const SizedBox(height: 14),
          Form(
            key: _resetKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '6-digit code',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_outlined, size: 20),
                  ),
                  validator: (value) => (value ?? '').trim().length != 6
                      ? 'Enter the 6-digit code'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'New password (at least 6 characters)',
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
                  validator: (value) =>
                      (value ?? '').length < 6 ? 'Use at least 6 characters' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _reset,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Set new password'),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSent = false),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Use a different email'),
            ),
          ),
        ],
      ],
    );
  }
}
