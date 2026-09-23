import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/service_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategoryId;
    if (category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(serviceFiltersProvider.notifier).state =
            ref.read(serviceFiltersProvider).copyWith(categoryId: category);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ServiceListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tapping a category tile on home re-enters this branch with a new id.
    if (widget.initialCategoryId != oldWidget.initialCategoryId &&
        widget.initialCategoryId != null) {
      ref.read(serviceFiltersProvider.notifier).state =
          ref.read(serviceFiltersProvider).copyWith(categoryId: widget.initialCategoryId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Redraw so the clear button appears as soon as there is text, then
    // debounce the request itself — typing should not fire one per keystroke.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      ref.read(serviceFiltersProvider.notifier).state = ref
          .read(serviceFiltersProvider)
          .copyWith(search: trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(serviceFiltersProvider);
    final services = ref.watch(servicesProvider);
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _openFilters(context),
            icon: Badge(
              isLabelVisible: filters.district != null ||
                  filters.area != null ||
                  filters.paidOnly,
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
                  decoration: InputDecoration(
                    hintText: 'Search providers…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: filters.categoryId == null,
                      onTap: () => ref.read(serviceFiltersProvider.notifier).state =
                          filters.copyWith(categoryId: null),
                    ),
                    for (final category in categories)
                      _CategoryChip(
                        label: '${category.icon ?? ''} ${category.name}'.trim(),
                        selected: filters.categoryId == category.id,
                        onTap: () => ref.read(serviceFiltersProvider.notifier).state =
                            filters.copyWith(categoryId: category.id),
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
          ref.read(isSignedInProvider) ? '/services/add' : Routes.login,
        ),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add service'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(servicesProvider);
          await ref.read(servicesProvider.future);
        },
        child: services.when(
          loading: () => const _GridSkeleton(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(servicesProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.handyman_outlined,
                    title: 'No services found',
                    message: filters.hasActiveFilters
                        ? 'Try removing a filter or searching for something else.'
                        : 'No services have been added yet. Be the first to add one.',
                    actionLabel: filters.hasActiveFilters ? 'Clear filters' : null,
                    onAction: filters.hasActiveFilters
                        ? () => ref.read(serviceFiltersProvider.notifier).state =
                            const ServiceFilters()
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
                mainAxisExtent: 246,
              ),
              itemBuilder: (context, index) => ServiceCard(service: items[index]),
            );
          },
        ),
      ),
    );
  }

  void _openFilters(BuildContext context) {
    AppDialogs.sheet<void>(
      context,
      child: _ServiceFilterSheet(
        initial: ref.read(serviceFiltersProvider),
        onApply: (value) =>
            ref.read(serviceFiltersProvider.notifier).state = value,
      ),
    );
  }
}

class _ServiceFilterSheet extends StatefulWidget {
  const _ServiceFilterSheet({required this.initial, required this.onApply});

  final ServiceFilters initial;
  final ValueChanged<ServiceFilters> onApply;

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late ServiceFilters _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Filter services',
            trailing: TextButton(
              onPressed: () => setState(
                () => _value = ServiceFilters(categoryId: _value.categoryId),
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
                  value: _value.paidOnly,
                  onChanged: (value) =>
                      setState(() => _value = _value.copyWith(paidOnly: value)),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Sponsored providers only',
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        mainAxisExtent: 246,
      ),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 140, radius: AppRadius.card),
          SizedBox(height: 10),
          SkeletonBox(height: 13),
          SizedBox(height: 8),
          SkeletonBox(width: 110, height: 10),
          SizedBox(height: 8),
          SkeletonBox(width: 90, height: 10),
        ],
      ),
    );
  }
}
