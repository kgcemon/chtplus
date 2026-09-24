import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/data_labels.dart';
import '../../core/widgets/common.dart';
import '../../models/biodata.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../home/widgets/home_header.dart';
import '../widgets/cards.dart';
import '../widgets/site_layout.dart';

/// The Biodata tab, laid out like the site's "All Biodata" page: title with a
/// "Submit new biodata" button, a filter card (looking for, district, upazila,
/// marital status) and biodata two to a row.
class BiodataListScreen extends ConsumerWidget {
  const BiodataListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(biodataFiltersProvider);
    final biodata = ref.watch(biodataListProvider);

    void update(BiodataFilters Function(BiodataFilters) change) {
      final notifier = ref.read(biodataFiltersProvider.notifier);
      notifier.state = change(notifier.state);
    }

    final hasFilters = filters.gender != null ||
        filters.district != null ||
        filters.area != null ||
        filters.maritalStatus != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(biodataListProvider);
          await ref.read(biodataListProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const HomeHeader(),
            SliverToBoxAdapter(
              child: PageHead(
                title: const Text('All Biodata'),
                subtitle: 'View all verified biodata',
                action: SiteButton(
                  label: 'Submit new biodata',
                  onPressed: () => context.push(
                    ref.read(isSignedInProvider) ? '/biodata/submit' : Routes.login,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilterSelect(
                            title: 'Looking for',
                            value: filters.gender,
                            onChanged: (v) => update((f) => f.copyWith(gender: v)),
                            options: const [
                              FilterOption(null, 'Everyone'),
                              FilterOption('পুরুষ', 'Groom'),
                              FilterOption('মহিলা', 'Bride'),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AreaFilterSelect(
                            districtName: filters.district,
                            value: filters.area,
                            onChanged: (v) => update((f) => f.copyWith(area: v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterSelect(
                            title: 'Marital status',
                            value: filters.maritalStatus,
                            onChanged: (v) => update((f) => f.copyWith(maritalStatus: v)),
                            options: [
                              const FilterOption(null, 'All marital statuses'),
                              for (final m in BiodataOptions.maritalStatuses)
                                FilterOption(m, dataLabel(m)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SiteButton(
                          label: 'Reset',
                          outlined: true,
                          onPressed: () => ref.read(biodataFiltersProvider.notifier).state =
                              const BiodataFilters(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ...biodata.when(
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
                    onRetry: () => ref.invalidate(biodataListProvider),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [SliverToBoxAdapter(child: EmptyNote('No biodata found'))]
                  : [
                      SliverCardGrid(
                        spacing: 8,
                        itemCount: items.length,
                        itemBuilder: (context, index) => BiodataCard(biodata: items[index]),
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
