import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/tour.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../widgets/form_fields.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import 'tour_widgets.dart';

final organizerProvider = FutureProvider.autoDispose<OrganizerState>(
  (ref) => ref.watch(tourRepositoryProvider).organizer(),
);

const _errors = {
  'invalid_input': 'Please fill in every required field.',
  'invalid_link': 'The link must start with http:// or https://',
  'invalid_dates': 'Dates must be today or later, and the end on/after the start.',
  'invalid_seats': 'Seats must be a whole number from 1 to 500.',
  'invalid_price': 'Enter the price per person in taka (0 for free).',
  'not_organizer': 'Your organizer account isn’t approved.',
  'already_pending': 'Your request is already waiting for review.',
};

/// "Organize a tour", like the site's /tours/organize: apply to be an
/// organizer, see the review status, and once approved post tours and
/// follow them.
class OrganizeTourScreen extends ConsumerWidget {
  const OrganizeTourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(organizerProvider);
    return SiteScaffold(
      title: 'Organize a tour',
      subtitle: 'Post group tours for others to join — after a quick check by CHT Plus',
      body: state.when(
        loading: () => const AppLoader(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(organizerProvider)),
        data: (s) => switch (s.status) {
          null || 'rejected' => _ApplyForm(state: s),
          'pending' => const _Message(icon: '⏳', title: 'Request received', body: 'CHT Plus will review it soon — you’ll get a notification when you can start posting tours.'),
          'blocked' => const _Message(icon: '⛔', title: 'Account suspended', body: 'Your organizer account has been suspended. Please contact CHT Plus.'),
          _ => _OrganizerHome(state: s),
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

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({required this.state});

  final OrganizerState state;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _phone = TextEditingController(text: ref.read(currentUserProvider)?.phone ?? '');
  final _link = TextEditingController();
  final _about = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _link.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(tourRepositoryProvider).applyAsOrganizer(
            orgName: _name.text.trim(),
            phone: _phone.text.trim(),
            link: _link.text.trim(),
            about: _about.text.trim(),
          );
      ref.invalidate(organizerProvider);
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
          const Text(
            'Tell us who you are. Once CHT Plus approves you, you can post tours that people can join.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FormRowField(label: 'Name of your group / agency', required: true, child: TextFormField(controller: _name, maxLength: 150, validator: need)),
          FormRowField(label: 'Phone', required: true, child: TextFormField(controller: _phone, keyboardType: TextInputType.phone, validator: need)),
          FormRowField(
            label: 'Facebook page / website (optional)',
            child: TextFormField(controller: _link, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://facebook.com/…')),
          ),
          FormRowField(
            label: 'About you and the tours you’ve run',
            required: true,
            child: TextFormField(controller: _about, minLines: 3, maxLines: 8, maxLength: 2000, validator: need),
          ),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending...' : 'Send request')),
        ],
      ),
    );
  }
}

class _OrganizerHome extends ConsumerStatefulWidget {
  const _OrganizerHome({required this.state});

  final OrganizerState state;

  @override
  ConsumerState<_OrganizerHome> createState() => _OrganizerHomeState();
}

class _OrganizerHomeState extends ConsumerState<_OrganizerHome> {
  final _key = GlobalKey<FormState>();
  final _c = {
    for (final k in ['title', 'destination', 'meetingPoint', 'seats', 'price', 'includes', 'description', 'contactPhone'])
      k: TextEditingController(),
  };
  DateTime? _start;
  DateTime? _end;
  List<String> _photo = const [];
  bool _showForm = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c['seats']!.text = '20';
    _c['contactPhone']!.text = ref.read(currentUserProvider)?.phone ?? '';
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: (start ? _start : _end ?? _start) ?? now,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end == null || _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_start == null || _end == null) {
      AppSnackbar.error(context, 'Pick the start and end dates.');
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await ref.read(tourRepositoryProvider).create(
        {
          for (final e in _c.entries) e.key: e.value.text.trim(),
          'startDate': _ymd(_start!),
          'endDate': _ymd(_end!),
        },
        photoPath: _photo.isEmpty ? null : _photo.first,
      );
      if (!mounted) return;
      AppSnackbar.success(context, status == 'approved' ? 'Your tour is live!' : 'Tour submitted — it will go live once the admin approves it.');
      for (final k in ['title', 'destination', 'meetingPoint', 'price', 'includes', 'description']) {
        _c[k]!.clear();
      }
      setState(() {
        _start = null;
        _end = null;
        _photo = const [];
        _showForm = false;
      });
      ref.invalidate(organizerProvider);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, _errors[e.code] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    String? need(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    String dateLabel(DateTime? d) => d == null ? 'Pick a date' : '${d.day}/${d.month}/${d.year}';

    return RefreshIndicator(
      onRefresh: () => ref.refresh(organizerProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.orgName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  s.autoApprove ? 'Your tours go live right away' : 'New tours go live after a quick admin check',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_showForm)
            FilledButton(onPressed: () => setState(() => _showForm = true), child: const Text('+ Post a new tour'))
          else
            Form(
              key: _key,
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('New tour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    FormRowField(
                      label: 'Title',
                      required: true,
                      child: TextFormField(controller: _c['title'], maxLength: 200, validator: need, decoration: const InputDecoration(hintText: 'e.g. Sajek 2 days 1 night')),
                    ),
                    FormRowField(
                      label: 'Destination',
                      required: true,
                      child: TextFormField(controller: _c['destination'], maxLength: 150, validator: need, decoration: const InputDecoration(hintText: 'e.g. Sajek Valley')),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FormRowField(
                            label: 'Start date',
                            required: true,
                            child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(dateLabel(_start))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FormRowField(
                            label: 'End date',
                            required: true,
                            child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(dateLabel(_end))),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FormRowField(
                            label: 'Total seats',
                            required: true,
                            child: TextFormField(controller: _c['seats'], keyboardType: TextInputType.number, validator: need),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FormRowField(
                            label: 'Price per person (৳)',
                            required: true,
                            child: TextFormField(controller: _c['price'], keyboardType: TextInputType.number, validator: need),
                          ),
                        ),
                      ],
                    ),
                    FormRowField(
                      label: 'Meeting point and time',
                      required: true,
                      child: TextFormField(
                        controller: _c['meetingPoint'],
                        maxLength: 255,
                        validator: need,
                        decoration: const InputDecoration(hintText: 'e.g. Shapla Chattar, Khagrachari — 6:00 AM'),
                      ),
                    ),
                    FormRowField(
                      label: 'Contact phone',
                      required: true,
                      child: TextFormField(controller: _c['contactPhone'], keyboardType: TextInputType.phone, validator: need),
                    ),
                    FormRowField(
                      label: 'What’s included (one per line)',
                      child: TextFormField(
                        controller: _c['includes'],
                        minLines: 3,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(hintText: 'Chander gari both ways\nCottage, 1 night\n3 meals'),
                      ),
                    ),
                    FormRowField(
                      label: 'Details',
                      child: TextFormField(
                        controller: _c['description'],
                        minLines: 4,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(hintText: 'Plan for each day, what to bring, rules…'),
                      ),
                    ),
                    FormRowField(
                      label: 'Cover photo (optional)',
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
                        Expanded(child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Posting...' : 'Post tour'))),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => setState(() => _showForm = false), child: const Text('Cancel')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Your tours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (s.tours.isEmpty)
            const EmptyNote('You haven’t posted a tour yet.')
          else
            for (final t in s.tours) ...[
              TourCardTile(
                tour: t,
                footer: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TourBadge.forTour(t.status),
                    if (t.pendingRequests > 0)
                      TourBadge('${t.pendingRequests} new requests', color: const Color(0xFF9A6A00), background: const Color(0xFFFFF3D6)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
