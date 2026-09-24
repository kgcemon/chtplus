import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../data/marketplace_repository.dart';
import '../../models/catalog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';
import '../home/widgets/home_header.dart';
import '../widgets/cards.dart';
import '../widgets/site_layout.dart';

/// The Market tab, laid out like the site's "All Products" page: title with
/// the active category, a "+ Sell" button, a filter card (category, district,
/// thana, search) and products two to a row.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  late final _search = TextEditingController(text: ref.read(listingFiltersProvider).search);
  late bool _searchOpen = _search.text.isNotEmpty;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategoryId;
    if (category != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _update((f) => f.copyWith(categoryId: category)),
      );
    }
  }

  @override
  void didUpdateWidget(covariant MarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategoryId != oldWidget.initialCategoryId &&
        widget.initialCategoryId != null) {
      _update((f) => f.copyWith(categoryId: widget.initialCategoryId));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(ListingFilters Function(ListingFilters) change) {
    final notifier = ref.read(listingFiltersProvider.notifier);
    notifier.state = change(notifier.state);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      _update((f) => f.copyWith(search: trimmed.isEmpty ? null : trimmed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(listingFiltersProvider);
    final listings = ref.watch(listingsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider).valueOrNull ?? const [];

    final active = categories.where((c) => c.id == filters.categoryId).firstOrNull;
    final parent = active?.parentId == null
        ? null
        : categories.where((c) => c.id == active!.parentId).firstOrNull;
    final hasFilters = filters.district != null || filters.area != null || filters.search != null;

    String label(Category c) => '${c.icon ?? ''} ${c.name}'.trim();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(listingsProvider);
          await ref.read(listingsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const HomeHeader(),
            SliverToBoxAdapter(
              child: PageHead(
                title: const Text('All Products'),
                subtitle: active == null
                    ? 'Select a category as needed'
                    : '${parent == null ? '' : '${label(parent)} › '}${label(active)} category products',
                action: SiteButton(
                  label: '+ Sell',
                  onPressed: () => context.push(
                    ref.read(isSignedInProvider) ? '/marketplace/sell' : Routes.login,
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
                            title: 'Category',
                            value: filters.categoryId,
                            onChanged: (id) => _update((f) => f.copyWith(categoryId: id)),
                            options: [
                              const FilterOption(null, '🗂️ All categories'),
                              for (final top in categories.where((c) => c.isTopLevel)) ...[
                                FilterOption(top.id, '${label(top)} (all)'),
                                for (final sub in categories.where((c) => c.parentId == top.id))
                                  FilterOption(sub.id, '      ${label(sub)}'),
                              ],
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
                        decoration: const InputDecoration(hintText: 'Search products'),
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
                            _update(
                              (f) => f.copyWith(district: null, area: null, search: null),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ...listings.when(
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
                    onRetry: () => ref.invalidate(listingsProvider),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [SliverToBoxAdapter(child: EmptyNote('No products have been added'))]
                  : [
                      SliverCardGrid(
                        spacing: 8,
                        itemCount: items.length,
                        itemBuilder: (context, index) => ListingCard(listing: items[index]),
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
