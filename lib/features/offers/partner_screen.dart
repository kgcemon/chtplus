import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/offer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../tours/tour_widgets.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_scaffold.dart';
import 'offer_widgets.dart';
import 'offers_screen.dart';

final partnerProvider = FutureProvider.autoDispose<PartnerState>(
  (ref) => ref.watch(offerRepositoryProvider).partner(),
);

const _errors = {
  'invalid_input': 'Please fill in every required field.',
  'invalid_link': 'The link must start with http:// or https://',
  'invalid_price': 'The offer price must be lower than the regular price.',
  'missing_discount': 'Enter the offer price, or describe the deal (e.g. “Buy 1 get 1”).',
  'invalid_valid_days': 'Code validity must be 1 to 90 days.',
  'invalid_per_user': 'Times per person must be 0 (no limit) to 10.',
  'invalid_cooldown': 'The wait between uses must be 0 to 365 days.',
  'invalid_total': 'The total number of codes must be at least 1.',
  'invalid_end_date': 'The end date must be today or later.',
  'not_partner': 'Your partner account isn’t approved.',
  'already_pending': 'Your request is already waiting for review.',
  'invalid_code': 'Enter the 6-character code, e.g. CHT-7K4P2Q.',
  'code_not_found': 'No code like this for your offers.',
  'code_not_active': 'This code can’t be used any more.',
};

/// The partner panel, like the site's /offers/partner: apply to be a partner,
/// see the review status, and once approved check customers' codes and post
/// and manage offers.
class PartnerScreen extends ConsumerWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(partnerProvider);
    return SiteScaffold(
      title: 'CHT Plus partner',
      subtitle: 'Give special offers to CHT Plus users and bring new customers to your business',
      body: state.when(
        loading: () => const AppLoader(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(partnerProvider)),
        data: (s) => switch (s.status) {
          null || 'rejected' => _ApplyForm(state: s),
          'pending' => const _Message(icon: '⏳', title: 'Request received', body: 'CHT Plus will review it soon — you’ll get a notification when you can start posting offers.'),
          'blocked' => const _Message(icon: '⛔', title: 'Account suspended', body: 'Your partner account has been suspended. Please contact CHT Plus.'),
          _ => _PartnerHome(state: s),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(icon, textAlign: TextAlign.center, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
      ],
    );
  }
}

// --- apply ------------------------------------------------------------------------

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({required this.state});

  final PartnerState state;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final _key = GlobalKey<FormState>();
  final _c = {for (final k in ['businessName', 'phone', 'area', 'address', 'link', 'about']) k: TextEditingController()};
  String? _category;
  List<String> _logo = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c['phone']!.text = ref.read(currentUserProvider)?.phone ?? '';
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_category == null) {
      AppSnackbar.error(context, 'Choose the type of business.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(offerRepositoryProvider).applyAsPartner(
        {for (final e in _c.entries) e.key: e.value.text.trim(), 'category': _category!},
        logoPath: _logo.isEmpty ? null : _logo.first,
      );
      ref.invalidate(partnerProvider);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, _errors[e.code] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? need(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    return Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.state.status == 'rejected')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Your last request was declined${widget.state.adminNote != null ? ': ${widget.state.adminNote}' : '.'} You can apply again.',
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9EC),
              border: Border.all(color: const Color(0xFFF3E0B0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'How it works\n'
              '1. Send this form — CHT Plus checks your business.\n'
              '2. Once approved, post offers (e.g. bike wash ৳100 → ৳50 for CHT Plus users).\n'
              '3. Customers get a code in the app and show it at your shop; you check it here and mark it used.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          FormRowField(
            label: 'Business name',
            required: true,
            child: TextFormField(controller: _c['businessName'], maxLength: 150, validator: need, decoration: const InputDecoration(hintText: 'e.g. Hill View Bike Wash')),
          ),
          FormRowField(
            label: 'Type of business',
            required: true,
            child: AppDropdown(
              value: _category,
              options: widget.state.categories,
              hint: 'Choose…',
              labelBuilder: (s) => s,
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          FormRowField(label: 'Phone', required: true, child: TextFormField(controller: _c['phone'], keyboardType: TextInputType.phone, validator: need)),
          FormRowField(
            label: 'Area',
            required: true,
            child: TextFormField(controller: _c['area'], maxLength: 150, validator: need, decoration: const InputDecoration(hintText: 'e.g. Khagrachari Sadar')),
          ),
          FormRowField(
            label: 'Full address (optional)',
            child: TextFormField(controller: _c['address'], maxLength: 255, decoration: const InputDecoration(hintText: 'Road, market, landmark')),
          ),
          FormRowField(
            label: 'Facebook page / website (optional)',
            child: TextFormField(controller: _c['link'], keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://facebook.com/…')),
          ),
          FormRowField(
            label: 'About your business',
            required: true,
            child: TextFormField(controller: _c['about'], minLines: 3, maxLines: 8, maxLength: 2000, validator: need),
          ),
          FormRowField(
            label: 'Logo (optional)',
            child: PhotoPickerField(
              maxPhotos: 1,
              existingUrls: const [],
              newPaths: _logo,
              onExistingRemoved: (_) {},
              onNewPathsChanged: (paths) => setState(() => _logo = paths),
            ),
          ),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending...' : 'Send request')),
        ],
      ),
    );
  }
}

// --- approved partner -------------------------------------------------------------

class _PartnerHome extends ConsumerStatefulWidget {
  const _PartnerHome({required this.state});

  final PartnerState state;

  @override
  ConsumerState<_PartnerHome> createState() => _PartnerHomeState();
}

class _PartnerHomeState extends ConsumerState<_PartnerHome> {
  final _code = TextEditingController();
  CodeCheck? _check;
  String? _checkError;
  bool _busy = false;

  /// The offer being edited (null = a new one), while the form is open.
  Offer? _editing;
  bool _showForm = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify({bool redeem = false}) async {
    if (_code.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _checkError = null;
    });
    try {
      final result = await ref.read(offerRepositoryProvider).verify(_code.text.trim(), redeem: redeem);
      setState(() => _check = result);
      if (redeem) ref.invalidate(partnerProvider);
    } on ApiException catch (e) {
      final data = e.data;
      setState(() {
        _check = data is Map<String, dynamic> ? CodeCheck.fromJson(data) : null;
        _checkError = _errors[e.code] ?? e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(Offer o, String status) async {
    try {
      await ref.read(offerRepositoryProvider).setStatus(o.id, status);
      ref.invalidate(partnerProvider);
      ref.invalidate(offersProvider);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(partnerProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.businessName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${s.category ?? ''} · ${s.area ?? ''} — your offers go live right away',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Check a customer's code.
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Check a customer’s code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _verify(),
                        onChanged: (_) {
                          if (_check != null || _checkError != null) {
                            setState(() {
                              _check = null;
                              _checkError = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(hintText: 'CHT-XXXXXX'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _busy ? null : () => _verify(), child: const Text('Check')),
                  ],
                ),
                if (_checkError != null) ...[
                  const SizedBox(height: 8),
                  Text(_checkError!, style: const TextStyle(color: AppColors.red)),
                ],
                if (_check != null) ...[
                  const SizedBox(height: 10),
                  _CheckResult(check: _check!, busy: _busy, onRedeem: () => _verify(redeem: true)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_showForm)
            _OfferForm(
              key: ValueKey(_editing?.id ?? 'new'),
              offer: _editing,
              onDone: (saved) {
                setState(() => _showForm = false);
                if (saved) {
                  ref.invalidate(partnerProvider);
                  ref.invalidate(offersProvider);
                }
              },
            )
          else
            FilledButton(
              onPressed: () => setState(() {
                _editing = null;
                _showForm = true;
              }),
              child: const Text('+ Add a new offer'),
            ),

          const SizedBox(height: 20),
          const Text('Your offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (s.offers.isEmpty)
            const Text('You haven’t posted an offer yet.', style: TextStyle(color: AppColors.textSecondary))
          else
            for (final o in s.offers) ...[
              OfferCardTile(
                offer: o,
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _statusBadge(o),
                        TourBadge('🎟️ ${o.claimedCount} given · ✅ ${o.redeemedCount} used'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _editing = o;
                            _showForm = true;
                          }),
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        if (o.status == 'active')
                          OutlinedButton(onPressed: () => _setStatus(o, 'paused'), child: const Text('Pause'))
                        else
                          FilledButton(onPressed: () => _setStatus(o, 'active'), child: const Text('Resume')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

          if (s.redemptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recently used codes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final r in s.redemptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.code} · ${r.offerTitle} · ${r.userName}', style: const TextStyle(fontSize: 13.5)),
                          Text(
                            '${formatOfferDay(r.redeemedAt)} ${r.redeemedAt.length >= 16 ? r.redeemedAt.substring(11, 16) : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(Offer o) {
    const amber = Color(0xFF9A6A00);
    const amberBg = Color(0xFFFFF3D6);
    if (o.adminHidden) return const TourBadge('Hidden by CHT Plus', color: AppColors.red, background: Color(0xFFFDECEB));
    if (o.status == 'paused') return const TourBadge('Paused', color: amber, background: amberBg);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (o.endsOn != null && o.endsOn!.compareTo(today) < 0) return const TourBadge('Ended', color: amber, background: amberBg);
    return const TourBadge('Live');
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.check, required this.busy, required this.onRedeem});

  final CodeCheck check;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final c = check.claim;
    final badge = check.redeemed
        ? const TourBadge('✅ Marked as used')
        : switch (c.status) {
            'active' => const TourBadge('Valid — not used yet'),
            'redeemed' => const TourBadge('Already used', color: Color(0xFF9A6A00), background: Color(0xFFFFF3D6)),
            _ => const TourBadge('Expired', color: AppColors.red, background: Color(0xFFFDECEB)),
          };
    final price = check.offerPrice != null ? 'Price ${offerTaka(check.offerPrice!)}' : check.discountLabel;
    final when = c.status == 'active'
        ? ' · valid until ${formatOfferDay(c.expiresAt)}'
        : c.status == 'redeemed' && c.redeemedAt != null
            ? ' · used ${formatOfferDay(c.redeemedAt!)}'
            : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: 6),
          Text(check.offerTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            '$price${check.userName != null ? ' · ${check.userName}' : ''}$when',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          if (c.status == 'active' && !check.redeemed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onRedeem,
                style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                child: const Text('Give the discount & mark used'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- add / edit an offer --------------------------------------------------------

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({super.key, this.offer, required this.onDone});

  final Offer? offer;

  /// Called with true after saving, false on Cancel.
  final ValueChanged<bool> onDone;

  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late String _perUser;
  String? _endsOn;
  List<String> _photo = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.offer;
    // The deal in words, unless it is just the "50% OFF" worked out from the prices.
    final words = o == null || o.discountLabel == '${o.percentOff}% OFF' ? '' : o.discountLabel;
    _c = {
      'title': TextEditingController(text: o?.title ?? ''),
      'regularPrice': TextEditingController(text: o?.regularPrice?.toString() ?? ''),
      'offerPrice': TextEditingController(text: o?.offerPrice?.toString() ?? ''),
      'discountText': TextEditingController(text: words),
      'description': TextEditingController(text: o?.description ?? ''),
      'terms': TextEditingController(text: o?.terms ?? ''),
      'codeValidDays': TextEditingController(text: (o?.codeValidDays ?? 7).toString()),
      'cooldownDays': TextEditingController(text: (o?.cooldownDays ?? 0).toString()),
      'totalLimit': TextEditingController(text: o?.totalLimit?.toString() ?? ''),
    };
    _perUser = (o?.perUserLimit ?? 1).toString();
    _endsOn = o?.endsOn;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(offerRepositoryProvider).save(
        {
          for (final e in _c.entries) e.key: e.value.text.trim(),
          'perUserLimit': _perUser,
          'endsOn': _endsOn ?? '',
        },
        id: widget.offer?.id,
        photoPath: _photo.isEmpty ? null : _photo.first,
      );
      if (!mounted) return;
      AppSnackbar.success(context, widget.offer == null ? 'Your offer is live!' : 'Offer updated.');
      widget.onDone(true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, _errors[e.code] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? need(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    const number = TextInputType.number;
    final now = DateTime.now();

    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
        );

    return Form(
      key: _key,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.offer == null ? 'New offer' : 'Edit offer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            FormRowField(
              label: 'Title',
              required: true,
              child: TextFormField(controller: _c['title'], maxLength: 200, validator: need, decoration: const InputDecoration(hintText: 'e.g. Full bike wash')),
            ),
            pair(
              FormRowField(
                label: 'Regular price (৳)',
                child: TextFormField(controller: _c['regularPrice'], keyboardType: number, decoration: const InputDecoration(hintText: 'e.g. 100')),
              ),
              FormRowField(
                label: 'Price for CHT Plus users (৳)',
                child: TextFormField(controller: _c['offerPrice'], keyboardType: number, decoration: const InputDecoration(hintText: 'e.g. 50')),
              ),
            ),
            FormRowField(
              label: 'Or describe the deal (optional)',
              child: TextFormField(
                controller: _c['discountText'],
                maxLength: 60,
                decoration: const InputDecoration(hintText: 'e.g. 20% OFF, Buy 1 get 1, Free delivery'),
              ),
            ),
            FormRowField(
              label: 'Details',
              child: TextFormField(
                controller: _c['description'],
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(hintText: 'What the customer gets'),
              ),
            ),
            FormRowField(
              label: 'Terms (one per line)',
              child: TextFormField(
                controller: _c['terms'],
                minLines: 2,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(hintText: 'Only on Friday and Saturday\nNot with other offers'),
              ),
            ),
            pair(
              FormRowField(
                label: 'Code valid for (days)',
                required: true,
                child: TextFormField(controller: _c['codeValidDays'], keyboardType: number, validator: need),
              ),
              FormRowField(
                label: 'Times per person',
                required: true,
                child: AppDropdown(
                  value: _perUser,
                  options: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '0'],
                  labelBuilder: (v) => v == '0' ? 'No limit' : v,
                  onChanged: (v) => setState(() => _perUser = v ?? '1'),
                ),
              ),
            ),
            pair(
              FormRowField(
                label: 'Wait between uses (days)',
                child: TextFormField(controller: _c['cooldownDays'], keyboardType: number),
              ),
              FormRowField(
                label: 'Total codes (blank = no limit)',
                child: TextFormField(controller: _c['totalLimit'], keyboardType: number, decoration: const InputDecoration(hintText: 'e.g. 100')),
              ),
            ),
            FormRowField(
              label: 'Last day of the offer (optional)',
              child: Row(
                children: [
                  Expanded(
                    child: DateField(
                      value: _endsOn,
                      hint: 'No end date',
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 730)),
                      onChanged: (v) => setState(() => _endsOn = v),
                    ),
                  ),
                  if (_endsOn != null)
                    IconButton(
                      tooltip: 'No end date',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _endsOn = null),
                    ),
                ],
              ),
            ),
            FormRowField(
              label: 'Photo (optional)',
              child: PhotoPickerField(
                maxPhotos: 1,
                existingUrls: const [],
                newPaths: _photo,
                onExistingRemoved: (_) {},
                onNewPathsChanged: (paths) => setState(() => _photo = paths),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Saving...' : widget.offer == null ? 'Post offer' : 'Save changes'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _busy ? null : () => widget.onDone(false), child: const Text('Cancel')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
