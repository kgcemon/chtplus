import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/service_repository.dart';
import '../../models/catalog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../home/widgets/banner_slider.dart';
import '../home/widgets/home_header.dart';
import '../home/widgets/quick_nav.dart';
import '../widgets/cards.dart';
import '../widgets/site_layout.dart';

/// The Services tab, in the website's two steps: first every category as a
/// searchable tile grid under the service banners, then — once a category is
/// picked — that category's providers with district/thana filters.
class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  @override
  void initState() {
    super.initState();
    final category = widget.initialCategoryId;
    if (category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setCategory(category));
    }
  }

  @override
  void didUpdateWidget(covariant ServiceListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tapping a category tile on home re-enters this branch with a new id.
    if (widget.initialCategoryId != oldWidget.initialCategoryId &&
        widget.initialCategoryId != null) {
      _setCategory(widget.initialCategoryId);
    }
  }

  /// A new category starts with no leftover district, thana or search.
  void _setCategory(String? id) =>
      ref.read(serviceFiltersProvider.notifier).state = ServiceFilters(categoryId: id);

  void _addService() =>
      context.push(ref.read(isSignedInProvider) ? '/services/add' : Routes.login);

  @override
  Widget build(BuildContext context) {
    final categoryId = ref.watch(serviceFiltersProvider.select((f) => f.categoryId));

    return PopScope(
      // Back from a category returns to the category grid, as on the site.
      canPop: categoryId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setCategory(null);
      },
      child: Scaffold(
        body: categoryId == null
            ? _CategoryBrowser(onPick: (c) => _setCategory(c.id), onAdd: _addService)
            : _CategoryProviders(onBack: () => _setCategory(null), onAdd: _addService),
      ),
    );
  }
}

// --- Step 1: every category ---------------------------------------------------

class _CategoryBrowser extends ConsumerStatefulWidget {
  const _CategoryBrowser({required this.onPick, required this.onAdd});

  final ValueChanged<Category> onPick;
  final VoidCallback onAdd;

  @override
  ConsumerState<_CategoryBrowser> createState() => _CategoryBrowserState();
}

class _CategoryBrowserState extends ConsumerState<_CategoryBrowser> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(serviceBannersProvider).valueOrNull ?? const [];
    final categories = ref.watch(serviceCategoriesProvider);
    final q = _query.text.trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(serviceBannersProvider);
        ref.invalidate(serviceCategoriesProvider);
        await ref.read(serviceCategoriesProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          const HomeHeader(),
          SliverToBoxAdapter(child: BannerSlider(banners: banners)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search categories... e.g. Doctor, Electrician',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Text('🔍', style: TextStyle(fontSize: 16)),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SiteButton(label: 'Add a service', onPressed: widget.onAdd),
                ],
              ),
            ),
          ),
          ...categories.when(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: ErrorView(
                  message: '$error',
                  onRetry: () => ref.invalidate(serviceCategoriesProvider),
                ),
              ),
            ],
            data: (all) {
              final shown = q.isEmpty
                  ? all
                  : all.where((c) => c.name.toLowerCase().contains(q)).toList();
              if (shown.isEmpty) {
                return const [SliverToBoxAdapter(child: EmptyNote('No categories found'))];
              }
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    itemCount: shown.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 110,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final category = shown[index];
                      return HomeTile(
                        emoji: (category.icon ?? '').isEmpty ? '📌' : category.icon!,
                        label: category.name,
                        maxLines: 2,
                        onTap: () => widget.onPick(category),
                      );
                    },
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

// --- Step 2: one category's providers -------------------------------------------

class _CategoryProviders extends ConsumerStatefulWidget {
  const _CategoryProviders({required this.onBack, required this.onAdd});

  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  ConsumerState<_CategoryProviders> createState() => _CategoryProvidersState();
}

class _CategoryProvidersState extends ConsumerState<_CategoryProviders> {
  late final _search = TextEditingController(text: ref.read(serviceFiltersProvider).search);
  late bool _searchOpen = (_search.text).isNotEmpty;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(ServiceFilters Function(ServiceFilters) change) {
    final notifier = ref.read(serviceFiltersProvider.notifier);
    notifier.state = change(notifier.state);
  }

  void _onSearchChanged(String value) {
    // Debounced: typing should not fire one request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      _update((f) => f.copyWith(search: trimmed.isEmpty ? null : trimmed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(serviceFiltersProvider);
    final services = ref.watch(servicesProvider);
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];
    final active = categories.where((c) => c.id == filters.categoryId).firstOrNull;
    final hasFilters = filters.district != null || filters.area != null || filters.search != null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(servicesProvider);
        await ref.read(servicesProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          const HomeHeader(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SiteButton(
                  label: '← All categories',
                  outlined: true,
                  onPressed: widget.onBack,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PageHead(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              title: Text(
                active == null
                    ? 'All Services'
                    : '${active.icon ?? ''} ${active.name}'.trim(),
              ),
              subtitle: active == null
                  ? 'All providers'
                  : '${active.name} category — all providers',
              action: SiteButton(label: '+ Add a service', onPressed: widget.onAdd),
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
                          title: 'Category',
                          value: filters.categoryId,
                          onChanged: (id) => ref.read(serviceFiltersProvider.notifier).state =
                              ServiceFilters(categoryId: id),
                          options: [
                            const FilterOption(null, '🗂️ All categories'),
                            for (final c in categories)
                              FilterOption(c.id, '${c.icon ?? ''} ${c.name}'.trim()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
                      SearchToggleButton(
                        active: _searchOpen,
                        onTap: () => setState(() => _searchOpen = !_searchOpen),
                      ),
                    ],
                  ),
                  if (_searchOpen) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      autofocus: _search.text.isEmpty,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or description',
                      ),
                    ),
                  ],
                  if (hasFilters) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SiteButton(
                        label: 'Reset',
                        outlined: true,
                        onPressed: () {
                          _search.clear();
                          ref.read(serviceFiltersProvider.notifier).state =
                              ServiceFilters(categoryId: filters.categoryId);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ...services.when(
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
                  onRetry: () => ref.invalidate(servicesProvider),
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? const [SliverToBoxAdapter(child: EmptyNote('There are no services in this category'))]
                : [
                    SliverCardGrid(
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          ServiceCard(service: items[index], compact: true),
                    ),
                  ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
