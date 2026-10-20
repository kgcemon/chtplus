import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/tour.dart';
import '../../providers/core_providers.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import 'tour_widgets.dart';

final toursProvider = FutureProvider.autoDispose.family<List<Tour>, String>(
  (ref, q) => ref.watch(tourRepositoryProvider).list(q: q),
);

/// Upcoming group tours, like the site's /tours page.
class ToursScreen extends ConsumerStatefulWidget {
  const ToursScreen({super.key});

  @override
  ConsumerState<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends ConsumerState<ToursScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tours = ref.watch(toursProvider(_q));
    return SiteScaffold(
      title: '🧳 Group Tours',
      subtitle: 'Travel the hills together — join a tour or organize your own',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(toursProvider(_q).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                SiteButton(label: 'My trips', outlined: true, onPressed: () => context.push('/tours/my')),
                const SizedBox(width: 8),
                SiteButton(label: 'Organize a tour', onPressed: () => context.push('/tours/organize')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search: Sajek, Nilgiri, Kaptai…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _search.clear();
                          _q = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            tours.when(
              loading: () => const AppLoader(),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(toursProvider(_q))),
              data: (list) => list.isEmpty
                  ? EmptyNote(_q.isEmpty ? 'No upcoming tours right now.' : 'No upcoming tours for “$_q”.')
                  : Column(
                      children: [
                        for (final t in list) ...[TourCardTile(tour: t), const SizedBox(height: 12)],
                      ],
                    ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Payment is made directly to the organizer. CHT Plus checks organizers before they can post, '
              'but please confirm the details with them before you pay.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
