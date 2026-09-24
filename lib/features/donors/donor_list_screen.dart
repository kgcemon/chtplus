import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/donor_repository.dart';
import '../../models/donor.dart';
import '../../providers/feature_providers.dart';
import '../home/widgets/home_header.dart';
import '../widgets/cards.dart';
import '../widgets/site_layout.dart';

/// The Blood tab, laid out like the site's "All Blood Donors" page: title,
/// a filter card with blood group, district and thana, then one donor per row.
class DonorListScreen extends ConsumerWidget {
  const DonorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(donorFiltersProvider);
    final donors = ref.watch(donorsProvider);

    void update(DonorFilters Function(DonorFilters) change) {
      final notifier = ref.read(donorFiltersProvider.notifier);
      notifier.state = change(notifier.state);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(donorsProvider);
          await ref.read(donorsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const HomeHeader(),
            const SliverToBoxAdapter(
              child: PageHead(
                title: Text('All Blood Donors'),
                subtitle: 'Contact a blood donor quickly in an emergency',
              ),
            ),
            SliverToBoxAdapter(
              child: FilterCard(
                child: Row(
                  children: [
                    Expanded(
                      child: FilterSelect(
                        title: 'Blood group',
                        value: filters.bloodGroup,
                        onChanged: (v) => update((f) => f.copyWith(bloodGroup: v)),
                        options: [
                          const FilterOption(null, 'All groups'),
                          for (final g in bloodGroups) FilterOption(g, g),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DistrictFilterSelect(
                        value: filters.district,
                        onChanged: (v) => update((f) => f.copyWith(district: v, area: null)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AreaFilterSelect(
                        districtName: filters.district,
                        value: filters.area,
                        onChanged: (v) => update((f) => f.copyWith(area: v)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...donors.when(
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (error, _) => [
                SliverToBoxAdapter(
                  child: ErrorView(
                    message: '$error',
                    onRetry: () => ref.invalidate(donorsProvider),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [SliverToBoxAdapter(child: EmptyNote('No blood donors have been added'))]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) => DonorCard(donor: items[index]),
                        ),
                      ),
                    ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
