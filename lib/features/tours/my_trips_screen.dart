import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../models/tour.dart';
import '../../providers/core_providers.dart';
import '../widgets/site_layout.dart';
import '../widgets/site_scaffold.dart';
import 'tour_widgets.dart';

final myTripsProvider = FutureProvider.autoDispose<List<Tour>>(
  (ref) => ref.watch(tourRepositoryProvider).myTrips(),
);

/// Tours I've asked to join, with each request's status (site: /tours/my).
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(myTripsProvider);
    return SiteScaffold(
      title: 'My trips',
      subtitle: 'Tours you’ve asked to join',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myTripsProvider.future),
        child: trips.when(
          loading: () => const AppLoader(),
          error: (e, _) => ListView(children: [ErrorView(message: '$e', onRetry: () => ref.invalidate(myTripsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const EmptyNote('You haven’t joined a tour yet.'),
                    Center(child: SiteButton(label: 'Find a tour', onPressed: () => context.push('/tours'))),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    for (final t in list) ...[
                      TourCardTile(
                        tour: t,
                        footer: t.status == 'cancelled'
                            ? TourBadge.forTour('cancelled')
                            : t.myBookingStatus == null
                                ? null
                                : TourBadge.forBooking(t.myBookingStatus!),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
