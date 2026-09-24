import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../router.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import '../widgets/wizard_parts.dart';

final _paymentNumbersProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(billingRepositoryProvider).coinPaymentNumbers(),
);

/// Buying coins, laid out like the site's coin page: the balance banner, a
/// form (package, payment method, the number to Send Money to, transaction id,
/// phone), then the recent requests. Money moves outside the app; an admin
/// credits the coins after checking the transaction.
class CoinsScreen extends ConsumerStatefulWidget {
  const CoinsScreen({super.key});

  @override
  ConsumerState<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends ConsumerState<CoinsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionId = TextEditingController();
  late final _phone = TextEditingController(text: ref.read(currentUserProvider)?.phone ?? '');
  String? _packageId;
  String? _method;
  bool _busy = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _transactionId.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit(String packageId, String method) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(billingRepositoryProvider).requestCoins(
            packageId: packageId,
            method: method,
            transactionId: _transactionId.text.trim(),
            phone: _phone.text.trim(),
          );
      ref.invalidate(coinRequestsProvider);
      _transactionId.clear();
      if (mounted) setState(() => _success = true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'pending_request_exists' => 'You already have a request under review',
          'method_unavailable' =>
            'This payment method is not available right now, please choose another',
          _ => 'Could not send the request, please try again',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    final balance = ref.watch(coinBalanceProvider).valueOrNull ?? 0;
    final packages = ref.watch(coinPackagesProvider).valueOrNull ?? const <CoinPackage>[];
    final requests = ref.watch(coinRequestsProvider).valueOrNull ?? const <CoinPurchaseRequest>[];
    final numbers = ref.watch(_paymentNumbersProvider).valueOrNull ?? const <String, String>{};
    final subscription = ref.watch(subscriptionProvider);

    // Only methods the admin has given a number for; all of them until the
    // numbers load.
    final methods = numbers.isEmpty
        ? paymentMethods
        : paymentMethods.where((m) => (numbers[m] ?? '').isNotEmpty).toList();
    final packageId = packages.any((p) => p.id == _packageId)
        ? _packageId
        : (packages.isEmpty ? null : packages.first.id);
    final method = methods.contains(_method) ? _method : (methods.isEmpty ? null : methods.first);
    final package = packages.where((p) => p.id == packageId).firstOrNull;
    final number = method == null ? '' : (numbers[method] ?? '');
    final hasPending = requests.any((r) => r.status == 'pending');

    return SiteScaffold(
      title: 'Buy Coins',
      subtitle: 'Use coins to unlock biodata and to sponsor services/products',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coinBalanceProvider);
          ref.invalidate(coinRequestsProvider);
          ref.invalidate(subscriptionProvider);
          ref.invalidate(_paymentNumbersProvider);
          await ref.read(coinBalanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!signedIn) ...[
              const SizedBox(height: 24),
              const Text(
                'Please log in first to buy coins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Center(
                child: SiteButton(
                  label: 'Log in / Sign up',
                  onPressed: () => context.push(Routes.login),
                ),
              ),
            ] else ...[
              // Balance banner.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9EC),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0xFFF3E0B0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your current balance',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '🪙 $balance coins',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9A6700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_success)
                WizardCard(
                  children: [
                    const Text('✅', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
                    const Text(
                      'Your request has been submitted',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Once the admin verifies and approves it, the coins will be added to your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textSecondary),
                    ),
                    Center(
                      child: SiteButton(
                        label: 'Make another request',
                        outlined: true,
                        onPressed: () => setState(() => _success = false),
                      ),
                    ),
                  ],
                )
              else
                Form(
                  key: _formKey,
                  child: WizardCard(
                    children: [
                      if (hasPending)
                        const Text(
                          'You already have a request under review.',
                          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                        ),
                      WizardField(
                        label: 'Select a package',
                        child: packages.isEmpty
                            ? const Text(
                                'No coin packages are available right now.',
                                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                              )
                            : AppDropdown(
                                value: packageId,
                                options: packages.map((p) => p.id).toList(),
                                labelBuilder: (id) {
                                  final p = packages.firstWhere((p) => p.id == id);
                                  return '${Fmt.taka(p.takaAmount)} = ${p.coinAmount} coins';
                                },
                                onChanged: (value) => setState(() => _packageId = value),
                              ),
                      ),
                      WizardField(
                        label: 'Payment method',
                        child: AppDropdown(
                          value: method,
                          options: methods,
                          labelBuilder: paymentMethodLabel,
                          onChanged: (value) => setState(() => _method = value),
                        ),
                      ),
                      if (number.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.forestLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Send Money '),
                                TextSpan(
                                  text: package == null ? '' : Fmt.taka(package.takaAmount),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: ' to this ${paymentMethodLabel(method)} number: '),
                                TextSpan(
                                  text: number,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(
                                  text: ', then enter the transaction ID in the form below.',
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: AppColors.forestDark,
                            ),
                          ),
                        ),
                      WizardField(
                        label: 'Transaction ID',
                        child: TextFormField(
                          controller: _transactionId,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [LengthLimitingTextInputFormatter(100)],
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Enter the transaction ID' : null,
                        ),
                      ),
                      WizardField(
                        label: 'Your phone number',
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [LengthLimitingTextInputFormatter(30)],
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Enter your phone number' : null,
                        ),
                      ),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.red)),
                      WizardActions(
                        nextLabel: 'Send request',
                        busyLabel: 'Sending...',
                        busy: _busy,
                        onNext: hasPending || packageId == null || method == null
                            ? null
                            : () => _submit(packageId, method),
                      ),
                    ],
                  ),
                ),
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Your recent requests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _RequestsTable(requests: requests),
              ],
              const SizedBox(height: 24),
              _SubscriptionSection(subscription: subscription.valueOrNull),
            ],
          ],
        ),
      ),
    );
  }
}

/// Package / Method / Status table (`.admin-table`).
class _RequestsTable extends StatelessWidget {
  const _RequestsTable({required this.requests});

  final List<CoinPurchaseRequest> requests;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
    const cell = TextStyle(fontSize: 13);

    Widget row(List<Widget> cells, {bool header = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: header ? AppColors.bg : null,
            border: header ? null : const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(flex: 5, child: cells[0]),
              Expanded(flex: 3, child: cells[1]),
              Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: cells[2])),
            ],
          ),
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          row(const [Text('Package', style: head), Text('Method', style: head), Text('Status', style: head)],
              header: true),
          for (final r in requests)
            row([
              Text('${Fmt.taka(r.takaAmount)} → ${r.coinAmount} coins', style: cell),
              Text(paymentMethodLabel(r.method), style: cell),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: r.status == 'approved' ? AppColors.forestLight : const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  switch (r.status) {
                    'pending' => 'Pending',
                    'approved' => 'Approved',
                    _ => 'Rejected',
                  },
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: r.status == 'approved' ? AppColors.forestDark : const Color(0xFF9A6700),
                  ),
                ),
              ),
            ]),
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
