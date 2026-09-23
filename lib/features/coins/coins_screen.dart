import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/billing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../widgets/form_fields.dart';

/// Coins pay for biodata unlocks and boosts.
///
/// Money moves outside the app: the user sends the amount over bKash or Nagad
/// and submits the transaction id here, and an admin credits the coins after
/// checking it. Nothing is charged inside the app.
class CoinsScreen extends ConsumerWidget {
  const CoinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);
    final packages = ref.watch(coinPackagesProvider);
    final requests = ref.watch(coinRequestsProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Coins')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coinBalanceProvider);
          ref.invalidate(coinRequestsProvider);
          ref.invalidate(subscriptionProvider);
          await ref.read(coinBalanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _BalanceCard(balance: balance.valueOrNull ?? 0),
            const SizedBox(height: 22),
            const Text(
              'Buy coins',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send the amount over bKash or Nagad, then submit the transaction id. '
              'An admin adds the coins to your balance after checking it.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            packages.when(
              loading: () => const AppLoader(),
              error: (error, _) => ErrorView(message: '$error', compact: true),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.monetization_on_outlined,
                    message: 'No coin packages are available right now.',
                    compact: true,
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 124,
                  ),
                  itemBuilder: (context, index) => _PackageCard(
                    package: items[index],
                    onTap: () => _buy(context, ref, items[index]),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _SubscriptionSection(subscription: subscription.valueOrNull),
            const SizedBox(height: 24),
            const Text(
              'Your requests',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            requests.when(
              loading: () => const AppLoader(),
              error: (error, _) => ErrorView(message: '$error', compact: true),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'You have not requested any coins yet.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final request in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestTile(request: request),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, CoinPackage package) async {
    final submitted = await AppDialogs.sheet<bool>(
      context,
      child: _PaymentSheet(
        title: 'Buy ${package.coinAmount} coins',
        amountLabel: Fmt.taka(package.takaAmount),
        onSubmit: ({
          required String method,
          required String transactionId,
          required String phone,
        }) =>
            ref.read(billingRepositoryProvider).requestCoins(
                  packageId: package.id,
                  method: method,
                  transactionId: transactionId,
                  phone: phone,
                ),
      ),
    );
    if (submitted == true) {
      ref.invalidate(coinRequestsProvider);
      if (context.mounted) {
        AppSnackbar.success(context, 'Request sent. An admin will review it shortly.');
      }
    }
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestDark, AppColors.forest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your balance',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$balance',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'coins',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const Text('🪙', style: TextStyle(fontSize: 44)),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onTap});

  final CoinPackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 7),
              Text(
                '${package.coinAmount}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'coins',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            Fmt.taka(package.takaAmount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.forestDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection({required this.subscription});

  final SubscriptionRequest? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Matrimony subscription',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'A subscription opens every verified biodata without spending coins.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subscription == null)
                const Text(
                  'You do not have a subscription.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                )
              else ...[
                Row(
                  children: [
                    StatusPill.forStatus(subscription!.status),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.taka(subscription!.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (subscription!.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subscription!.isActive
                        ? 'Active until ${Fmt.date(subscription!.expiresAt)}'
                        : 'Expired on ${Fmt.date(subscription!.expiresAt)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: subscription?.status == 'pending'
                    ? null
                    : () => _request(context, ref),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(
                  subscription?.status == 'pending'
                      ? 'Request awaiting review'
                      : subscription?.isActive == true
                          ? 'Renew subscription'
                          : 'Request a subscription',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final amountText = await AppDialogs.prompt(
      context,
      title: 'Subscription amount',
      hint: 'Amount you paid, in taka',
      keyboardType: TextInputType.number,
      confirmLabel: 'Next',
    );
    final amount = num.tryParse((amountText ?? '').trim());
    if (amount == null || amount <= 0) return;
    if (!context.mounted) return;

    final submitted = await AppDialogs.sheet<bool>(
      context,
      child: _PaymentSheet(
        title: 'Matrimony subscription',
        amountLabel: Fmt.taka(amount),
        onSubmit: ({
          required String method,
          required String transactionId,
          required String phone,
        }) =>
            ref.read(billingRepositoryProvider).requestSubscription(
                  method: method,
                  transactionId: transactionId,
                  phone: phone,
                  amount: amount,
                ),
      ),
    );
    if (submitted == true) {
      ref.invalidate(subscriptionProvider);
      if (context.mounted) {
        AppSnackbar.success(context, 'Request sent. An admin will review it shortly.');
      }
    }
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final CoinPurchaseRequest request;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '🪙 ${request.coinAmount}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.taka(request.takaAmount),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${paymentMethodLabel(request.method)} · ${request.transactionId ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Fmt.relative(request.requestedAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusPill.forStatus(request.status),
        ],
      ),
    );
  }
}

/// Collects the payment method, transaction id and the number the money was
/// sent from.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.title,
    required this.amountLabel,
    required this.onSubmit,
  });

  final String title;
  final String amountLabel;
  final Future<void> Function({
    required String method,
    required String transactionId,
    required String phone,
  }) onSubmit;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _transactionId = TextEditingController();
  final _phone = TextEditingController();
  String _method = paymentMethods.first;
  bool _busy = false;

  @override
  void dispose() {
    _transactionId.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_transactionId.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Enter the transaction id and your number.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        method: _method,
        transactionId: _transactionId.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: widget.title,
              subtitle: 'Amount to send: ${widget.amountLabel}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                children: [
                  FormRowField(
                    label: 'Payment method',
                    required: true,
                    child: Row(
                      children: [
                        for (final method in paymentMethods)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: method == paymentMethods.last ? 0 : 10,
                              ),
                              child: InkWell(
                                onTap: () => setState(() => _method = method),
                                borderRadius: BorderRadius.circular(AppRadius.field),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _method == method
                                        ? AppColors.forestLight
                                        : AppColors.surface,
                                    border: Border.all(
                                      color: _method == method
                                          ? AppColors.forest
                                          : AppColors.border,
                                      width: _method == method ? 1.6 : 1,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.field),
                                  ),
                                  child: Text(
                                    paymentMethodLabel(method),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _method == method
                                          ? AppColors.forestDark
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  FormRowField(
                    label: 'Transaction id',
                    required: true,
                    hint: 'The TrxID from the confirmation message.',
                    child: TextField(
                      controller: _transactionId,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      decoration: const InputDecoration(hintText: 'e.g. 9F7K2L8MNQ'),
                    ),
                  ),
                  FormRowField(
                    label: 'Number you sent from',
                    required: true,
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: const InputDecoration(hintText: '01XXXXXXXXX'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
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
                        : const Text('Submit request'),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
