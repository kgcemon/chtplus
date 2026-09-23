import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/biodata.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';

class BiodataListScreen extends ConsumerStatefulWidget {
  const BiodataListScreen({super.key});

  @override
  ConsumerState<BiodataListScreen> createState() => _BiodataListScreenState();
}

class _BiodataListScreenState extends ConsumerState<BiodataListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final trimmed = value.trim();
      ref.read(biodataFiltersProvider.notifier).state = ref
          .read(biodataFiltersProvider)
          .copyWith(search: trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(biodataFiltersProvider);
    final biodata = ref.watch(biodataListProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrimony'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'My biodata',
              onPressed: () => context.push(Routes.myBiodata),
              icon: const Icon(Icons.folder_shared_outlined),
            ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => AppDialogs.sheet<void>(
              context,
              child: _BiodataFilterSheet(
                initial: filters,
                onApply: (value) =>
                    ref.read(biodataFiltersProvider.notifier).state = value,
              ),
            ),
            icon: Badge(
              isLabelVisible: filters.hasActiveFilters,
              backgroundColor: AppColors.amber,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by biodata no, profession or area…',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _Chip(
                      label: 'Everyone',
                      selected: filters.gender == null,
                      onTap: () => ref.read(biodataFiltersProvider.notifier).state =
                          filters.copyWith(gender: null),
                    ),
                    _Chip(
                      label: 'Grooms',
                      selected: filters.gender == 'পুরুষ',
                      onTap: () => ref.read(biodataFiltersProvider.notifier).state =
                          filters.copyWith(gender: 'পুরুষ'),
                    ),
                    _Chip(
                      label: 'Brides',
                      selected: filters.gender == 'মহিলা',
                      onTap: () => ref.read(biodataFiltersProvider.notifier).state =
                          filters.copyWith(gender: 'মহিলা'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(signedIn ? '/biodata/submit' : Routes.login),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Submit biodata'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(biodataListProvider);
          await ref.read(biodataListProvider.future);
        },
        child: biodata.when(
          loading: () => const _GridSkeleton(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(biodataListProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.favorite_outline_rounded,
                    title: 'No biodata found',
                    message: filters.hasActiveFilters
                        ? 'Try widening your filters — for example a broader age range or district.'
                        : 'No verified biodata has been published yet.',
                    actionLabel: filters.hasActiveFilters ? 'Clear filters' : null,
                    onAction: filters.hasActiveFilters
                        ? () => ref.read(biodataFiltersProvider.notifier).state =
                            const BiodataFilters()
                        : null,
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 272,
              ),
              itemBuilder: (context, index) => BiodataCard(biodata: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BiodataFilterSheet extends StatefulWidget {
  const _BiodataFilterSheet({required this.initial, required this.onApply});

  final BiodataFilters initial;
  final ValueChanged<BiodataFilters> onApply;

  @override
  State<_BiodataFilterSheet> createState() => _BiodataFilterSheetState();
}

class _BiodataFilterSheetState extends State<_BiodataFilterSheet> {
  late BiodataFilters _value = widget.initial;
  late RangeValues _ageRange = RangeValues(
    (widget.initial.minAge ?? 18).toDouble(),
    (widget.initial.maxAge ?? 60).toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Filter biodata',
              trailing: TextButton(
                onPressed: () => setState(() {
                  _value = BiodataFilters(gender: _value.gender);
                  _ageRange = const RangeValues(18, 60);
                }),
                child: const Text('Reset'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                children: [
                  FormRowField(
                    label: 'Marital status',
                    child: AppDropdown(
                      value: _value.maritalStatus,
                      options: BiodataOptions.maritalStatuses,
                      includeEmpty: true,
                      emptyLabel: 'Any',
                      onChanged: (value) => setState(
                        () => _value = _value.copyWith(maritalStatus: value),
                      ),
                    ),
                  ),
                  FormRowField(
                    label: 'District',
                    child: DistrictPicker(
                      value: _value.district,
                      onChanged: (value) =>
                          setState(() => _value = _value.copyWith(district: value)),
                    ),
                  ),
                  FormRowField(
                    label:
                        'Age range: ${_ageRange.start.round()} – ${_ageRange.end.round()} years',
                    child: RangeSlider(
                      values: _ageRange,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: AppColors.forest,
                      labels: RangeLabels(
                        '${_ageRange.start.round()}',
                        '${_ageRange.end.round()}',
                      ),
                      onChanged: (value) => setState(() {
                        _ageRange = value;
                        _value = _value.copyWith(
                          minAge: value.start.round(),
                          maxAge: value.end.round(),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
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
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.forestLight,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.forestDark : AppColors.text,
        ),
        side: BorderSide(color: selected ? AppColors.forest : AppColors.border),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 272,
      ),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 138, radius: AppRadius.card),
          SizedBox(height: 10),
          SkeletonBox(width: 90, height: 13),
          SizedBox(height: 8),
          SkeletonBox(height: 10),
          SizedBox(height: 8),
          SkeletonBox(width: 120, height: 10),
        ],
      ),
    );
  }
}
