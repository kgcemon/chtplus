import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Where to go once signed in — set when a guarded screen bounced here.
  final String? next;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onSignedIn() {
    if (!mounted) return;
    final next = widget.next;
    if (next != null && next.isNotEmpty && next != Routes.login) {
      context.go(next);
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
          );
      _onSignedIn();
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google(String credential) async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle(credential);
      _onSignedIn();
    } on ApiException catch (error) {
      if (mounted) showAuthError(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Log in',
      subtitle: '',
      tab: AuthTab.login,
      children: [
        GoogleSignInButton(onCredential: _google),
        Form(
          key: _formKey,
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: FieldLabel('Email')),
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
              const Align(alignment: Alignment.centerLeft, child: FieldLabel('Password')),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Password',
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
                    (value ?? '').isEmpty ? 'Enter your password' : null,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(
              '${Routes.forgotPassword}?email=${Uri.encodeComponent(_email.text.trim())}',
            ),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Log in'),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New here?',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => context.push(
                widget.next == null
                    ? Routes.register
                    : '${Routes.register}?next=${Uri.encodeComponent(widget.next!)}',
              ),
              child: const Text('Create an account'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.home),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Continue without signing in'),
          ),
        ),
      ],
    );
  }
}
