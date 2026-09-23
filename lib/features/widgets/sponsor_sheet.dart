import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/billing.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

enum SponsorTarget { service, listing }

/// Spends coins to push a service or an advert to the top of its list. Boosts
/// stack: buying again while one is running extends it rather than resetting.
class SponsorSheet extends ConsumerStatefulWidget {
  const SponsorSheet({super.key, required this.target, required this.id});

  final SponsorTarget target;
  final String id;

  static Future<bool> open(
    BuildContext context, {
    required SponsorTarget target,
    required String id,
  }) async {
    final result = await AppDialogs.sheet<bool>(
      context,
      child: SponsorSheet(target: target, id: id),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SponsorSheet> createState() => _SponsorSheetState();
}

class _SponsorSheetState extends ConsumerState<SponsorSheet> {
  String? _selectedId;
  bool _busy = false;

  Future<void> _boost(SponsorPackage package) async {
    setState(() => _busy = true);
    try {
      if (widget.target == SponsorTarget.service) {
        await ref.read(serviceRepositoryProvider).sponsor(
              id: widget.id,
              packageId: package.id,
            );
      } else {
        await ref.read(marketplaceRepositoryProvider).sponsor(
              id: widget.id,
              packageId: package.id,
            );
      }
      ref.invalidate(coinBalanceProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.success(context, 'Boost activated for ${package.durationDays} days.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (error.code == 'insufficient_coins') {
        final cost = error.data?['cost'];
        AppSnackbar.error(
          context,
          'You need $cost coins for this package. Top up to continue.',
        );
        Navigator.of(context).pop(false);
        context.push(Routes.coins);
        return;
      }
      AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = widget.target == SponsorTarget.service
        ? ref.watch(serviceSponsorPackagesProvider)
        : ref.watch(marketplaceSponsorPackagesProvider);
    final balance = ref.watch(coinBalanceProvider).valueOrNull ?? 0;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Boost with coins',
            subtitle: 'Appear at the top of the list and on the home page.',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.forestLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '$balance',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          packages.when(
            loading: () => const AppLoader(),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorView(message: '$error', compact: true),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.bolt_outlined,
                    message: 'No boost packages are available right now.',
                    compact: true,
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(
                  children: [
                    for (final package in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PackageTile(
                          package: package,
                          selected: _selectedId == package.id,
                          affordable: balance >= package.coinCost,
                          onTap: () => setState(() => _selectedId = package.id),
                        ),
                      ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: _busy || _selectedId == null
                          ? null
                          : () => _boost(
                                items.firstWhere((p) => p.id == _selectedId),
                              ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Activate boost'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        context.push(Routes.coins);
                      },
                      child: const Text('Buy more coins'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final SponsorPackage package;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestLight : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.forest : AppColors.border,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${package.durationDays} days at the top',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '🪙 ${package.coinCost}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: affordable ? AppColors.forestDark : AppColors.red,
                  ),
                ),
                if (!affordable)
                  const Text(
                    'Not enough',
                    style: TextStyle(fontSize: 10.5, color: AppColors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
