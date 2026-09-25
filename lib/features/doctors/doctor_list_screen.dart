import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/doctor_repository.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../home/widgets/home_header.dart';
import '../home/widgets/quick_nav.dart';
import '../widgets/cards.dart';
import '../widgets/site_layout.dart';

/// Symptom shortcuts from the site's `DepartmentSymptomPicker`: each searches
/// for the department keyword that treats it.
const _symptoms = <(String, String, String)>[
  ('🤒', 'Fever, cold & cough', 'মেডিসিন'),
  ('👶', 'Children’s problems', 'শিশু'),
  ('🧴', 'Skin diseases & allergies', 'চর্ম'),
  ('❤️', 'Heart disease', 'হৃদ'),
  ('🤰', 'Gynecology & pregnancy', 'স্ত্রীরোগ'),
  ('🦷', 'Dental problems', 'দাঁত'),
  ('👁️', 'Eye problems', 'চোখ'),
  ('🦴', 'Bone & joint pain', 'অর্থো'),
  ('🩸', 'Diabetes & hormones', 'ডায়াবেটিস'),
  ('🫘', 'Kidney & urology problems', 'কিডনি'),
  ('🧠', 'Mental health', 'মানসিক'),
  ('👂', 'Nose, ear & throat', 'ইএনটি'),
];

/// Best-effort emoji for a free-text department name, as the site guesses it.
String _departmentIcon(String name) {
  bool has(List<String> words) => words.any(name.contains);
  if (has(['শিশু'])) return '👶';
  if (has(['স্ত্রী', 'গাইনি', 'গর্ভ'])) return '🤰';
  if (has(['হৃদ', 'কার্ডিও'])) return '❤️';
  if (has(['চর্ম', 'স্কিন'])) return '🧴';
  if (has(['দাঁত', 'ডেন্টাল'])) return '🦷';
  if (has(['চোখ', 'চক্ষু'])) return '👁️';
  if (has(['হাড়', 'অর্থো'])) return '🦴';
  if (has(['কিডনি', 'ইউরো'])) return '🫘';
  if (has(['মস্তিষ্ক', 'নিউরো'])) return '🧠';
  if (has(['ক্যান্সার', 'অনকো'])) return '🎗️';
  if (has(['মানসিক', 'সাইকিয়া'])) return '🧠';
  if (has(['নাক', 'কান', 'গলা', 'ইএনটি'])) return '👂';
  return '🩺';
}

/// Laid out like the site's "Doctor Appointments" page: a search box with
/// Division / Symptoms tile grids, a filter card, then doctors two to a row.
class DoctorListScreen extends ConsumerStatefulWidget {
  const DoctorListScreen({super.key});

  @override
  ConsumerState<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends ConsumerState<DoctorListScreen> {
  late final _search = TextEditingController(text: ref.read(doctorFiltersProvider).q);
  Timer? _debounce;
  bool _symptomTab = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(DoctorFilters Function(DoctorFilters) change) {
    final notifier = ref.read(doctorFiltersProvider.notifier);
    notifier.state = change(notifier.state);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      _update((f) => f.copyWith(q: trimmed.isEmpty ? null : trimmed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(doctorFiltersProvider);
    final doctors = ref.watch(doctorsProvider);
    final departments = ref.watch(diseaseDepartmentsProvider).valueOrNull ?? const [];
    final organizations = ref.watch(organizationsProvider).valueOrNull ?? const [];
    final hasFilters =
        filters.organizationId != null || filters.district != null || filters.area != null;

    const tileGrid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisExtent: 120,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doctorsProvider);
          await ref.read(doctorsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const HomeHeader(),
            const SliverToBoxAdapter(
              child: PageHead(
                title: Text('Doctor Appointments'),
                subtitle: 'List of experienced doctors',
              ),
            ),
            SliverToBoxAdapter(
              child: FilterCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search by doctor name or department',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Pill(
                          label: 'Division',
                          active: !_symptomTab,
                          onTap: () => setState(() => _symptomTab = false),
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          label: 'Symptoms',
                          active: _symptomTab,
                          onTap: () => setState(() => _symptomTab = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_symptomTab && departments.isEmpty)
                      const Text(
                        'No departments have been added yet',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: tileGrid,
                        itemCount: _symptomTab ? _symptoms.length : departments.length,
                        itemBuilder: (context, index) {
                          if (_symptomTab) {
                            final (emoji, label, q) = _symptoms[index];
                            return HomeTile(
                              emoji: emoji,
                              label: label,
                              maxLines: 2,
                              onTap: () {
                                _search.text = q;
                                _update((f) => f.copyWith(q: q, departmentId: null));
                              },
                            );
                          }
                          final d = departments[index];
                          final selected = filters.departmentId == d.id;
                          return HomeTile(
                            emoji: _departmentIcon(d.name),
                            label: d.name,
                            maxLines: 2,
                            selected: selected,
                            // Tapping the chosen department again clears it.
                            onTap: () => _update(
                              (f) => f.copyWith(departmentId: selected ? null : d.id),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilterSelect(
                      title: 'Hospital / clinic',
                      value: filters.organizationId,
                      onChanged: (v) => _update((f) => f.copyWith(organizationId: v)),
                      options: [
                        const FilterOption(null, 'All hospitals / clinics'),
                        for (final o in organizations) FilterOption(o.id, o.name),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DistrictFilterSelect(
                            value: filters.district,
                            onChanged: (v) => _update((f) => f.copyWith(district: v, area: null)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AreaFilterSelect(
                            districtName: filters.district,
                            value: filters.area,
                            onChanged: (v) => _update((f) => f.copyWith(area: v)),
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
                          onPressed: () => _update(
                            (f) => f.copyWith(organizationId: null, district: null, area: null),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ...doctors.when(
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
                    onRetry: () => ref.invalidate(doctorsProvider),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [SliverToBoxAdapter(child: EmptyNote('No doctors have been added'))]
                  : [
                      SliverCardGrid(
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            DoctorCard(doctor: items[index], compact: true),
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

/// Rounded tab pill (`.pill-nav` button).
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.forest : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.forest : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
