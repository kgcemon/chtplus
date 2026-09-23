import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/donor_repository.dart';
import '../../models/donor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';

class DonorListScreen extends ConsumerWidget {
  const DonorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(donorFiltersProvider);
    final donors = ref.watch(donorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood donors'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => AppDialogs.sheet<void>(
              context,
              child: _DonorFilterSheet(
                initial: filters,
                onApply: (value) =>
                    ref.read(donorFiltersProvider.notifier).state = value,
              ),
            ),
            icon: Badge(
              isLabelVisible: filters.district != null || filters.area != null,
              backgroundColor: AppColors.amber,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _BloodChip(
                      label: 'All groups',
                      selected: filters.bloodGroup == null,
                      onTap: () => ref.read(donorFiltersProvider.notifier).state =
                          filters.copyWith(bloodGroup: null),
                    ),
                    for (final group in bloodGroups)
                      _BloodChip(
                        label: group,
                        selected: filters.bloodGroup == group,
                        onTap: () => ref.read(donorFiltersProvider.notifier).state =
                            filters.copyWith(bloodGroup: group),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: Colors.white70),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'A donor can give blood again 120 days after donating.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ),
                    Switch.adaptive(
                      value: filters.availableOnly,
                      onChanged: (value) =>
                          ref.read(donorFiltersProvider.notifier).state =
                              filters.copyWith(availableOnly: value),
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.forest,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          ref.read(isSignedInProvider) ? '/donors/register' : Routes.login,
        ),
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: const Text('Become a donor'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(donorsProvider);
          await ref.read(donorsProvider.future);
        },
        child: donors.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => const Row(
              children: [
                SkeletonBox(width: 52, height: 52, radius: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 100, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(donorsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.bloodtype_outlined,
                    title: 'No donors found',
                    message: filters.hasActiveFilters
                        ? 'Try another blood group, district or turn off the availability filter.'
                        : 'No one has registered as a donor yet.',
                    actionLabel: filters.hasActiveFilters ? 'Clear filters' : null,
                    onAction: filters.hasActiveFilters
                        ? () => ref.read(donorFiltersProvider.notifier).state =
                            const DonorFilters()
                        : null,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => DonorCard(donor: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BloodChip extends StatelessWidget {
  const _BloodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.red : AppColors.text,
        ),
        side: BorderSide(
          color: selected ? AppColors.red : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
    );
  }
}

class _DonorFilterSheet extends StatefulWidget {
  const _DonorFilterSheet({required this.initial, required this.onApply});

  final DonorFilters initial;
  final ValueChanged<DonorFilters> onApply;

  @override
  State<_DonorFilterSheet> createState() => _DonorFilterSheetState();
}

class _DonorFilterSheetState extends State<_DonorFilterSheet> {
  late DonorFilters _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Filter donors',
            trailing: TextButton(
              onPressed: () => setState(
                () => _value = DonorFilters(bloodGroup: _value.bloodGroup),
              ),
              child: const Text('Reset'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              children: [
                FormRowField(
                  label: 'District',
                  child: DistrictPicker(
                    value: _value.district,
                    onChanged: (value) => setState(
                      () => _value = _value.copyWith(district: value, area: null),
                    ),
                  ),
                ),
                FormRowField(
                  label: 'Area',
                  child: UpazilaPicker(
                    districtName: _value.district,
                    value: _value.area,
                    onChanged: (value) =>
                        setState(() => _value = _value.copyWith(area: value)),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _value.availableOnly,
                  onChanged: (value) =>
                      setState(() => _value = _value.copyWith(availableOnly: value)),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Available to donate now',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  activeThumbColor: AppColors.forest,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: FilledButton(
              onPressed: () {
                widget.onApply(_value);
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Show results'),
            ),
          ),
        ],
      ),
    );
  }
}
