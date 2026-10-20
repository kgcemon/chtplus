import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/tour.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../router.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import 'tour_widgets.dart';

final tourDetailProvider = FutureProvider.autoDispose.family<TourDetail, String>(
  (ref, id) => ref.watch(tourRepositoryProvider).detail(id),
);

const _errors = {
  'not_enough_seats': 'Not enough seats left for that many people.',
  'already_requested': 'You have already asked to join this tour.',
  'own_tour': 'This is your own tour.',
  'tour_started': 'This tour has already started.',
  'already_decided': 'That request was already decided.',
};

/// One group tour, like the site's /tours/:id: the details, a join form (or
/// your request's status), and for its organizer the join requests.
class TourDetailScreen extends ConsumerStatefulWidget {
  const TourDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends ConsumerState<TourDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(tourDetailProvider(widget.id));
      if (done != null && mounted) AppSnackbar.success(context, done);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, _errors[e.code] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens (or starts) the in-app chat with the tour's organizer.
  Future<void> _message(String userId, String name) async {
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    try {
      final conversationId = await ref.read(chatRepositoryProvider).startConversation(userId);
      if (mounted) context.push('/chat/$conversationId?name=${Uri.encodeComponent(name)}');
    } on ApiException catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.code == 'chat_disabled' ? 'This organizer has turned chat off — please call instead.' : e.message);
      }
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openJoinSheet(Tour tour) async {
    final repo = ref.read(tourRepositoryProvider);
    final seats = TextEditingController(text: '1');
    final phone = TextEditingController(text: ref.read(currentUserProvider)?.phone ?? '');
    final note = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(sheet).bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Join this tour', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: seats,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'People (max ${tour.seatsLeft < 20 ? tour.seatsLeft : 20})'),
            ),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Your phone')),
            const SizedBox(height: 10),
            TextField(controller: note, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Note to the organizer (optional)')),
            const SizedBox(height: 6),
            const Text(
              'Nothing is paid here. Once the organizer confirms, pay them directly.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Ask to join')),
          ],
        ),
      ),
    );
    if (send != true) return;
    final n = int.tryParse(seats.text) ?? 0;
    if (n < 1 || phone.text.trim().isEmpty) {
      if (mounted) AppSnackbar.error(context, 'Enter the number of people and your phone number.');
      return;
    }
    await _run(
      () => repo.join(tour.id, seats: n, phone: phone.text.trim(), note: note.text.trim().isEmpty ? null : note.text.trim()),
      done: 'Request sent! The organizer will confirm your place.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tourDetailProvider(widget.id));
    return SiteScaffold(
      title: 'Group Tour',
      showTitle: false,
      body: detail.when(
        loading: () => const AppLoader(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(tourDetailProvider(widget.id))),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(tourDetailProvider(widget.id).future),
          child: _body(d),
        ),
      ),
    );
  }

  Widget _body(TourDetail d) {
    final t = d.tour;
    final signedIn = ref.watch(isSignedInProvider);
    final repo = ref.read(tourRepositoryProvider);
    final mine = d.myBooking;
    final canJoin = t.status == 'approved' && !d.isOrganizer;
    const block = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.all(Radius.circular(14)),
      border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
    );
    const h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

    String? statusNote = switch (t.status) {
      'pending' => 'Waiting for admin approval — only you can see this tour.',
      'rejected' => 'Not approved by the admin${t.adminNote != null ? ' (${t.adminNote})' : ''}.',
      'cancelled' => 'This tour has been cancelled.',
      _ => null,
    };

    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(t.isOfficial ? 13 : 16),
      child: AspectRatio(
            aspectRatio: 16 / 9,
            child: (t.photoUrl ?? '').isNotEmpty
                ? AppNetworkImage(url: t.photoUrl)
                : Container(
                    color: AppColors.forestLight,
                    alignment: Alignment.center,
                    child: const Text('🏞️', style: TextStyle(fontSize: 56)),
                  ),
          ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        if (t.isOfficial) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.forestDark, AppColors.forest]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD166)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFF0A202), Color(0xFFFFD166)]),
                  ),
                  child: const Text('★', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF3D2A00))),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Official CHT Plus Tour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text('Organized and managed by the CHT Plus team', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: officialTourGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x40F0A202), blurRadius: 26, offset: Offset(0, 8))],
            ),
            child: cover,
          ),
        ] else
          cover,
        if (statusNote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9EC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3E0B0)),
            ),
            child: Text(statusNote, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
        const SizedBox(height: 12),
        Text(t.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final line in [
          '📍  ${t.destination}',
          '🗓️  ${tourDates(t)} · ${tourLength(t)}',
          '🚩  ${t.meetingPoint}',
          '💺  ${t.seatsLeft > 0 ? '${t.seatsLeft} of ${t.seats} seats left' : 'Full (${t.seats} seats)'}',
        ])
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: const TextStyle(fontSize: 14))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(tourPrice(t.price), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.forestDark)),
              const SizedBox(width: 8),
              const Text('per person · paid to the organizer', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (t.organizer.official)
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.forestLight, shape: BoxShape.circle),
                      child: const Text('🌄', style: TextStyle(fontSize: 22)),
                    )
                  else
                    Avatar(url: t.organizer.photoUrl, name: t.organizer.name, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(t.organizer.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                            VerifiedBadge(active: t.organizer.blueBadge, size: 13),
                          ],
                        ),
                        Text(
                          t.organizer.official ? 'Official CHT Plus tour' : 'Organizer',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SiteButton(label: '📞 Call', onPressed: () => Launchers.call(context, t.contactPhone)),
                  // Organizer tours: in-app chat (not on your own tour).
                  // Official tours have no organizer account: WhatsApp the team.
                  if (!d.isOrganizer)
                    SiteButton(
                      label: '💬 Message',
                      outlined: true,
                      onPressed: () => t.organizer.userId != null
                          ? _message(t.organizer.userId!, t.organizer.name)
                          : Launchers.whatsapp(
                              context,
                              t.contactPhone,
                              text: 'Hi, I\'m asking about the tour "${t.title}" on CHT Plus.',
                            ),
                    ),
                  if (t.organizer.userId != null)
                    SiteButton(label: 'Profile', outlined: true, onPressed: () => context.push('/u/${t.organizer.userId}')),
                ],
              ),
            ],
          ),
        ),
        if (t.includeLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: block,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What’s included', style: h3),
                const SizedBox(height: 8),
                for (final line in t.includeLines)
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('✅  $line', style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ],
        if (t.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: block,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Details', style: h3),
                const SizedBox(height: 8),
                Text(t.description, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
        if (canJoin) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: block,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Join this tour', style: h3),
                const SizedBox(height: 10),
                if (!signedIn)
                  FilledButton(onPressed: () => context.push(Routes.login), child: const Text('Log in to join'))
                else if (mine != null && mine.isActive) ...[
                  Row(
                    children: [
                      Text('Your request: ${mine.seats} ${mine.seats == 1 ? 'seat' : 'seats'}  '),
                      TourBadge.forBooking(mine.status),
                    ],
                  ),
                  if (mine.status == 'accepted')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Call the organizer at ${t.contactPhone} to pay and get the final details.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SiteButton(
                    label: 'Cancel my request',
                    outlined: true,
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm('Cancel your place?', 'The organizer will be told.')) {
                              await _run(() => repo.cancelMyBooking(t.id), done: 'Your request was cancelled.');
                            }
                          },
                  ),
                ] else if (t.seatsLeft <= 0)
                  const Text('This tour is full.', style: TextStyle(color: AppColors.textSecondary))
                else ...[
                  if (mine?.status == 'rejected')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Your last request was declined — you can ask again.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  FilledButton(onPressed: _busy ? null : () => _openJoinSheet(t), child: const Text('Ask to join')),
                ],
              ],
            ),
          ),
        ],
        if (d.isOrganizer) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: block,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join requests (${d.bookings.length})', style: h3),
                if (d.bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No one has asked to join yet.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                for (final b in d.bookings) ...[
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(url: b.photoUrl, name: b.name, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: b.userId == null ? null : () => context.push('/u/${b.userId}'),
                              child: Row(
                                children: [
                                  Flexible(child: Text(b.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  VerifiedBadge(active: b.blueBadge, size: 12),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Launchers.call(context, b.phone),
                              child: Text(
                                '${b.seats} ${b.seats == 1 ? 'seat' : 'seats'} · ${b.phone}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ),
                            if ((b.note ?? '').isNotEmpty)
                              Text('“${b.note}”', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            if (b.status == 'pending')
                              Row(
                                children: [
                                  SiteButton(
                                    label: 'Accept',
                                    onPressed: _busy ? null : () => _run(() => repo.decide(t.id, b.id, accept: true)),
                                  ),
                                  const SizedBox(width: 6),
                                  SiteButton(
                                    label: 'Decline',
                                    outlined: true,
                                    onPressed: _busy ? null : () => _run(() => repo.decide(t.id, b.id, accept: false)),
                                  ),
                                ],
                              )
                            else
                              TourBadge.forBooking(b.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (t.status != 'cancelled') ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm('Cancel this tour?', 'Everyone who asked to join will be told.')) {
                              await _run(() => repo.cancelTour(t.id), done: 'The tour was cancelled.');
                            }
                          },
                    child: const Text('Cancel this tour'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
