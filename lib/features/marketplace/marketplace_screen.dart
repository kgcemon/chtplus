import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils/data_labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/marketplace_repository.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategoryId;
    if (category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(listingFiltersProvider.notifier).state =
            ref.read(listingFiltersProvider).copyWith(categoryId: category);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategoryId != oldWidget.initialCategoryId &&
        widget.initialCategoryId != null) {
      ref.read(listingFiltersProvider.notifier).state = ref
          .read(listingFiltersProvider)
          .copyWith(categoryId: widget.initialCategoryId);
    }
  }

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
      ref.read(listingFiltersProvider.notifier).state = ref
          .read(listingFiltersProvider)
          .copyWith(search: trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(listingFiltersProvider);
    final listings = ref.watch(listingsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];

    // When a top-level category is picked, its subcategories replace the
    // top-level strip, mirroring the site's category navigation.
    final selected = categories.where((c) => c.id == filters.categoryId).firstOrNull;
    final parentId = selected == null
        ? null
        : (selected.isTopLevel ? selected.id : selected.parentId);
    final strip = parentId == null
        ? categories.where((c) => c.isTopLevel).toList()
        : categories.where((c) => c.parentId == parentId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            tooltip: 'Sort',
            onPressed: () => _openSort(context, filters),
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => AppDialogs.sheet<void>(
              context,
              child: _ListingFilterSheet(
                initial: filters,
                onApply: (value) =>
                    ref.read(listingFiltersProvider.notifier).state = value,
              ),
            ),
            icon: Badge(
              isLabelVisible: filters.district != null ||
                  filters.area != null ||
                  filters.condition != null,
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
                    hintText: 'Search products…',
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
                      label: parentId == null ? 'All' : '← All categories',
                      selected: filters.categoryId == null,
                      onTap: () => ref.read(listingFiltersProvider.notifier).state =
                          filters.copyWith(categoryId: null),
                    ),
                    for (final category in strip)
                      _Chip(
                        label: '${category.icon ?? ''} ${category.name}'.trim(),
                        selected: filters.categoryId == category.id,
                        onTap: () => ref.read(listingFiltersProvider.notifier).state =
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
          ref.read(isSignedInProvider) ? '/marketplace/sell' : Routes.login,
        ),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sell_outlined),
        label: const Text('Sell'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(listingsProvider);
          await ref.read(listingsProvider.future);
        },
        child: listings.when(
          loading: () => const _GridSkeleton(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 70),
              ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(listingsProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Nothing here yet',
                    message: filters.hasActiveFilters
                        ? 'Try another category, area or search term.'
                        : 'No products have been listed yet. Be the first to sell something.',
                    actionLabel: filters.hasActiveFilters ? 'Clear filters' : 'Sell an item',
                    onAction: filters.hasActiveFilters
                        ? () => ref.read(listingFiltersProvider.notifier).state =
                            const ListingFilters()
                        : () => context.push(
                              ref.read(isSignedInProvider)
                                  ? '/marketplace/sell'
                                  : Routes.login,
                            ),
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
                mainAxisExtent: 262,
              ),
              itemBuilder: (context, index) => ListingCard(listing: items[index]),
            );
          },
        ),
      ),
    );
  }

  void _openSort(BuildContext context, ListingFilters filters) {
    AppDialogs.sheet<void>(
      context,
      isScrollControlled: false,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Sort by'),
            for (final sort in ListingSort.values)
              ListTile(
                onTap: () {
                  ref.read(listingFiltersProvider.notifier).state =
                      filters.copyWith(sort: sort);
                  Navigator.of(context).pop();
                },
                leading: Icon(
                  filters.sort == sort
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: filters.sort == sort ? AppColors.forest : AppColors.border,
                ),
                title: Text(sort.label, style: const TextStyle(fontSize: 14.5)),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ListingFilterSheet extends StatefulWidget {
  const _ListingFilterSheet({required this.initial, required this.onApply});

  final ListingFilters initial;
  final ValueChanged<ListingFilters> onApply;

  @override
  State<_ListingFilterSheet> createState() => _ListingFilterSheetState();
}

class _ListingFilterSheetState extends State<_ListingFilterSheet> {
  late ListingFilters _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Filter products',
            trailing: TextButton(
              onPressed: () => setState(
                () => _value = ListingFilters(
                  categoryId: _value.categoryId,
                  sort: _value.sort,
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
                  label: 'Condition',
                  child: AppDropdown(
                    value: _value.condition,
                    options: marketplaceConditions,
                    includeEmpty: true,
                    emptyLabel: 'Any condition',
                    onChanged: (value) =>
                        setState(() => _value = _value.copyWith(condition: value)),
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
        mainAxisExtent: 262,
      ),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 132, radius: AppRadius.card),
          SizedBox(height: 10),
          SkeletonBox(height: 13),
          SizedBox(height: 8),
          SkeletonBox(width: 90, height: 14),
          SizedBox(height: 8),
          SkeletonBox(width: 120, height: 10),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
