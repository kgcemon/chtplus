import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/doctor_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';

class DoctorListScreen extends ConsumerStatefulWidget {
  const DoctorListScreen({super.key});

  @override
  ConsumerState<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends ConsumerState<DoctorListScreen> {
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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      ref.read(doctorFiltersProvider.notifier).state = ref
          .read(doctorFiltersProvider)
          .copyWith(q: trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(doctorFiltersProvider);
    final doctors = ref.watch(doctorsProvider);
    final departments = ref.watch(diseaseDepartmentsProvider).valueOrNull ?? const [];
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctors'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'My appointments',
              onPressed: () => context.push(Routes.myAppointments),
              icon: const Icon(Icons.event_note_outlined),
            ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => AppDialogs.sheet<void>(
              context,
              child: _DoctorFilterSheet(
                initial: filters,
                onApply: (value) =>
                    ref.read(doctorFiltersProvider.notifier).state = value,
              ),
            ),
            icon: Badge(
              isLabelVisible: filters.district != null ||
                  filters.area != null ||
                  filters.organizationId != null,
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
                    hintText: 'Search by name or specialty…',
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
                      label: 'All departments',
                      selected: filters.departmentId == null,
                      onTap: () => ref.read(doctorFiltersProvider.notifier).state =
                          filters.copyWith(departmentId: null),
                    ),
                    for (final department in departments)
                      _Chip(
                        label: department.name,
                        selected: filters.departmentId == department.id,
                        onTap: () => ref.read(doctorFiltersProvider.notifier).state =
                            filters.copyWith(departmentId: department.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doctorsProvider);
          await ref.read(doctorsProvider.future);
        },
        child: doctors.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => const Row(
              children: [
                SkeletonBox(width: 54, height: 54, radius: 27),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 110, height: 10),
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
                onRetry: () => ref.invalidate(doctorsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'No doctors found',
                    message: filters.hasActiveFilters
                        ? 'Try a different department, hospital or district.'
                        : 'No doctors are listed yet.',
                    actionLabel: filters.hasActiveFilters ? 'Clear filters' : null,
                    onAction: filters.hasActiveFilters
                        ? () => ref.read(doctorFiltersProvider.notifier).state =
                            const DoctorFilters()
                        : null,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => DoctorCard(doctor: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DoctorFilterSheet extends ConsumerStatefulWidget {
  const _DoctorFilterSheet({required this.initial, required this.onApply});

  final DoctorFilters initial;
  final ValueChanged<DoctorFilters> onApply;

  @override
  ConsumerState<_DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends ConsumerState<_DoctorFilterSheet> {
  late DoctorFilters _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final organizations = ref.watch(organizationsProvider).valueOrNull ?? const [];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Filter doctors',
            trailing: TextButton(
              onPressed: () => setState(
                () => _value = DoctorFilters(
                  departmentId: _value.departmentId,
                  q: _value.q,
                ),
              ),
              child: const Text('Reset'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              children: [
                FormRowField(
                  label: 'Hospital / clinic',
                  child: AppDropdown(
                    value: _value.organizationId,
                    options: organizations.map((o) => o.id).toList(),
                    includeEmpty: true,
                    emptyLabel: 'Any',
                    hint: 'Choose a hospital or clinic',
                    labelBuilder: (id) =>
                        organizations.firstWhere((o) => o.id == id).name,
                    onChanged: (value) => setState(
                      () => _value = _value.copyWith(organizationId: value),
                    ),
                  ),
                ),
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
