import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/blue_badge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';

final _blueBadgeProvider = FutureProvider.autoDispose<BlueBadgeInfo>(
  (ref) => ref.watch(billingRepositoryProvider).blueBadge(),
);

/// "Get Blue Tick", like the site's /blue-tick page: the current tick, the
/// coin balance, and the packages to buy (or extend) it with coins.
class BlueTickScreen extends ConsumerStatefulWidget {
  const BlueTickScreen({super.key});

  @override
  ConsumerState<BlueTickScreen> createState() => _BlueTickScreenState();
}

class _BlueTickScreenState extends ConsumerState<BlueTickScreen> {
  String? _busyId;

  Future<void> _buy(BlueBadgePackage pkg, bool extending) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(extending ? 'Extend blue tick?' : 'Buy blue tick?'),
        content: Text('${pkg.label} for ${pkg.coinCost} coins.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text('Pay ${pkg.coinCost} coins')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyId = pkg.id);
    try {
      await ref.read(billingRepositoryProvider).buyBlueBadge(pkg.id);
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref.read(authControllerProvider.notifier).updateLocalUser(user.copyWith(blueBadge: true));
      }
      ref.invalidate(_blueBadgeProvider);
      ref.invalidate(coinBalanceProvider);
      if (mounted) AppSnackbar.success(context, 'Done! Your blue tick is on.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'insufficient_coins') {
        final cost = error.data?['cost'];
        final balance = error.data?['coinBalance'];
        final buy = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Not enough coins'),
            content: Text('This package costs $cost coins — you have $balance.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Close')),
              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Buy coins')),
            ],
          ),
        );
        if (buy == true && mounted) context.push(Routes.coins);
      } else if (error.code == 'already_permanent') {
        AppSnackbar.show(context, 'Your blue tick is already permanent.');
      } else {
        AppSnackbar.error(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    final info = ref.watch(_blueBadgeProvider);

    return SiteScaffold(
      title: 'Get Blue Tick',
      subtitle: 'Show people your account is trusted — a blue tick next to your name everywhere on CHT Plus',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_blueBadgeProvider.future),
        child: info.when(
          loading: () => const AppLoader(),
          error: (error, _) => ListView(
            children: [ErrorView(message: '$error', onRetry: () => ref.invalidate(_blueBadgeProvider))],
          ),
          data: (data) {
            final status = data.status;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StatusCard(signedIn: signedIn, status: status),
                const SizedBox(height: 14),
                if (data.packages.isEmpty)
                  const EmptyNote('The blue tick isn’t on sale right now. Please check back later.')
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: [
                      for (final p in data.packages)
                        _PackageCard(
                          pkg: p,
                          busy: _busyId == p.id,
                          label: !signedIn
                              ? 'Log in to buy'
                              : status?.permanent == true
                                  ? 'Already permanent'
                                  : status?.active == true
                                      ? 'Extend'
                                      : 'Buy',
                          onTap: !signedIn
                              ? () => context.push(Routes.login)
                              : status?.permanent == true || _busyId != null
                                  ? null
                                  : () => _buy(p, status?.active == true),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                const Text(
                  'The tick turns on as soon as you pay. Buying while it’s active adds the time to your current end date. '
                  'The admin can remove a tick that is misused.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.signedIn, required this.status});

  final bool signedIn;
  final BlueBadgeStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final active = s?.active == true;
    final title = !signedIn
        ? 'Log in to get the blue tick'
        : active
            ? 'Your blue tick is on'
            : 'You don’t have the blue tick yet';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF5FE) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? const Color(0xFFB9DCF8) : AppColors.border),
      ),
      child: Row(
        children: [
          const VerifiedBadge(active: true, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (active)
                  Text(
                    s!.permanent ? 'It never expires' : 'Valid until ${Fmt.date(s.expiresAt)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                if (s != null)
                  Text(
                    'Your balance: 🪙 ${s.coinBalance} coins',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg, required this.busy, required this.label, required this.onTap});

  final BlueBadgePackage pkg;
  final bool busy;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(pkg.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '🪙 ${pkg.coinCost}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.forestDark),
          ),
          const SizedBox(height: 8),
          busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : SiteButton(label: label, onPressed: onTap),
        ],
      ),
    );
  }
}
