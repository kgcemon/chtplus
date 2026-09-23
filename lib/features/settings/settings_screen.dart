import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../auth/google_signin_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = 'Version ${info.version} (${info.buildNumber})');
      }
    }).catchError((_) => null);
  }

  Future<void> _toggleChat(bool enabled) async {
    try {
      await ref.read(chatRepositoryProvider).updateSettings(chatEnabled: enabled);
      ref.invalidate(chatSettingsProvider);
      if (mounted) {
        AppSnackbar.success(
          context,
          enabled
              ? 'Others can message you again.'
              : 'Messaging is off. Nobody can start a new chat with you.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to post, message or book.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;

    await GoogleSignInService.instance.signOut();
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go(Routes.home);
  }

  /// Play policy requires an in-app way to delete an account. The server
  /// anonymizes the row: sign-in stops working and personal fields are cleared.
  Future<void> _deleteAccount() async {
    final first = await AppDialogs.confirm(
      context,
      title: 'Delete your account?',
      message:
          'Your name, email, phone, photos and profile details will be erased and you will not be able to sign in again.\n\n'
          'Services, adverts and biodata you posted keep the contact details written on them, so admins can remove them separately. '
          'This cannot be undone.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!first || !mounted) return;

    final typed = await AppDialogs.prompt(
      context,
      title: 'Confirm deletion',
      hint: 'Type DELETE to confirm',
      confirmLabel: 'Delete my account',
    );
    if (typed?.trim().toUpperCase() != 'DELETE' || !mounted) return;

    try {
      await AppDialogs.withBlockingProgress(
        context,
        () => ref.read(meRepositoryProvider).deleteAccount(),
      );
      await GoogleSignInService.instance.signOut();
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      AppSnackbar.success(context, 'Your account has been deleted.');
      context.go(Routes.home);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatSettings = ref.watch(chatSettingsProvider).valueOrNull;
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & privacy')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (signedIn) ...[
            const _GroupLabel('Privacy'),
            _Group(
              children: [
                SwitchListTile.adaptive(
                  value: chatSettings?.chatEnabled ?? true,
                  onChanged: chatSettings == null ? null : _toggleChat,
                  secondary: const Icon(Icons.chat_bubble_outline_rounded,
                      color: AppColors.forestDark),
                  title: const Text(
                    'Allow messages',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'When off, nobody can start a chat with you.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  activeThumbColor: AppColors.forest,
                ),
                const Divider(height: 1, indent: 56),
                _Tile(
                  icon: Icons.visibility_outlined,
                  label: 'Who can see my details',
                  subtitle: 'Set each profile field to public, followers or only me',
                  onTap: () => context.push('/profile/edit'),
                ),
              ],
            ),
            const _GroupLabel('Account'),
            _Group(
              children: [
                _Tile(
                  icon: Icons.person_outline_rounded,
                  label: 'Edit profile',
                  onTap: () => context.push('/profile/edit'),
                ),
                const Divider(height: 1, indent: 56),
                _Tile(
                  icon: Icons.monetization_on_outlined,
                  label: 'Coins & subscription',
                  onTap: () => context.push(Routes.coins),
                ),
                const Divider(height: 1, indent: 56),
                _Tile(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  onTap: _signOut,
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You are browsing as a guest',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to post services, sell items, message people and book appointments.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.push(Routes.login),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                      ),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          const _GroupLabel('About CHT Plus'),
          _Group(
            children: [
              _Tile(
                icon: Icons.info_outline_rounded,
                label: 'About',
                onTap: () => context.push(Routes.about),
              ),
              const Divider(height: 1, indent: 56),
              _Tile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: () => Launchers.url(context, AppConfig.privacyPolicyUrl),
              ),
              const Divider(height: 1, indent: 56),
              _Tile(
                icon: Icons.language_rounded,
                label: 'Open the website',
                subtitle: AppConfig.websiteUrl.replaceFirst('https://', ''),
                onTap: () => Launchers.url(context, AppConfig.websiteUrl),
              ),
              const Divider(height: 1, indent: 56),
              _Tile(
                icon: Icons.share_outlined,
                label: 'Share CHT Plus',
                onTap: () => Launchers.share(
                  'CHT Plus — local services, blood donors, marketplace, matrimony and doctor appointments for Khagrachari, Rangamati and Bandarban.\n${AppConfig.websiteUrl}',
                ),
              ),
            ],
          ),
          if (signedIn) ...[
            const _GroupLabel('Danger zone'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: _deleteAccount,
                leading: const Icon(Icons.delete_forever_outlined,
                    color: AppColors.red),
                title: const Text(
                  'Delete my account',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                ),
                subtitle: const Text(
                  'Permanently erase your personal details. This cannot be undone.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          Center(
            child: Text(
              _version.isEmpty ? 'CHT Plus' : 'CHT Plus · $_version',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: AppColors.forestDark),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
    );
  }
}
