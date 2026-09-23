import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_providers.dart';
import '../../providers/home_provider.dart';
import '../../router.dart';
import '../widgets/cards.dart';
import 'widgets/banner_slider.dart';
import 'widgets/home_header.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/quick_nav.dart';
import 'widgets/welcome_popup_host.dart';

/// The app's landing screen, laid out to match the website's home page:
/// banners, quick links, then a section per feature in the viewer's preferred
/// order.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final order = ref.watch(homeSectionOrderProvider);

    return WelcomePopupHost(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeFeedProvider);
            ref.invalidate(chatUnreadCountProvider);
            ref.invalidate(notificationsProvider);
            await ref.read(homeFeedProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              const HomeHeader(),
              ...feed.when(
                loading: () => const [HomeSkeleton()],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      message: '$error',
                      onRetry: () => ref.invalidate(homeFeedProvider),
                    ),
                  ),
                ],
                data: (data) => _sections(context, ref, data, order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    HomeFeed data,
    List<String> order,
  ) {
    return [
      SliverToBoxAdapter(child: BannerSlider(banners: data.banners)),
      const SliverToBoxAdapter(child: QuickNav()),
      for (final key in order) ...switch (key) {
        'services' => _servicesSections(context, data),
        'donors' => _donorsSection(context, data),
        'marketplace' => _marketplaceSections(context, data),
        'biodata' => _biodataSection(context, data),
        'doctors' => _doctorsSection(context, data),
        _ => const <Widget>[],
      },
      SliverToBoxAdapter(child: _FooterCta(ref: ref)),
    ];
  }

  // --- Services --------------------------------------------------------------

  List<Widget> _servicesSections(BuildContext context, HomeFeed data) {
    final services = data.topServices;
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Service categories',
          subtitle: 'Find reliable service providers',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.services),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: data.serviceCategories.length,
            itemExtent: 82,
            itemBuilder: (context, index) {
              final category = data.serviceCategories[index];
              return CategoryTile(
                category: category,
                onTap: () => context.go('${Routes.services}?category=${category.id}'),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Popular providers',
          subtitle: 'Top-rated and verified service providers',
        ),
      ),
      if (services.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(message: 'No services have been added yet.', compact: true),
        )
      else
        SliverToBoxAdapter(
          child: _HorizontalCards(
            height: 244,
            itemWidth: 172,
            itemCount: services.length,
            builder: (index) => ServiceCard(service: services[index], compact: true),
          ),
        ),
    ];
  }

  // --- Blood donors ----------------------------------------------------------

  List<Widget> _donorsSection(BuildContext context, HomeFeed data) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Blood donors',
          subtitle: 'Find a blood donor in an emergency',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.donors),
        ),
      ),
      if (data.donors.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(message: 'No donors have registered yet.', compact: true),
        )
      else
        SliverList.separated(
          itemCount: data.donors.length > 5 ? 5 : data.donors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DonorCard(donor: data.donors[index]),
          ),
        ),
    ];
  }

  // --- Marketplace -----------------------------------------------------------

  List<Widget> _marketplaceSections(BuildContext context, HomeFeed data) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Marketplace',
          subtitle: 'Buy and sell products locally',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.marketplace),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: data.marketplaceCategories.length,
            itemExtent: 82,
            itemBuilder: (context, index) {
              final category = data.marketplaceCategories[index];
              return CategoryTile(
                category: category,
                onTap: () =>
                    context.go('${Routes.marketplace}?category=${category.id}'),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (data.listings.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(message: 'No products have been added yet.', compact: true),
        )
      else
        SliverToBoxAdapter(
          child: _HorizontalCards(
            height: 262,
            itemWidth: 168,
            itemCount: data.listings.length,
            builder: (index) => ListingCard(listing: data.listings[index]),
          ),
        ),
    ];
  }

  // --- Matrimony -------------------------------------------------------------

  List<Widget> _biodataSection(BuildContext context, HomeFeed data) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Matrimony',
          subtitle: 'View verified biodata',
          actionLabel: 'View all',
          onAction: () => context.go(Routes.biodata),
        ),
      ),
      if (data.biodata.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(message: 'No biodata has been added yet.', compact: true),
        )
      else
        SliverToBoxAdapter(
          child: _HorizontalCards(
            height: 272,
            itemWidth: 168,
            itemCount: data.biodata.length,
            builder: (index) => BiodataCard(biodata: data.biodata[index]),
          ),
        ),
    ];
  }

  // --- Doctors ---------------------------------------------------------------

  List<Widget> _doctorsSection(BuildContext context, HomeFeed data) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Doctor appointments',
          subtitle: 'Book an appointment with an experienced doctor',
          actionLabel: 'View all',
          onAction: () => context.push(Routes.doctors),
        ),
      ),
      if (data.doctors.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(message: 'No doctors are listed yet.', compact: true),
        )
      else
        SliverToBoxAdapter(
          child: _HorizontalCards(
            height: 176,
            itemWidth: 140,
            itemCount: data.doctors.length,
            builder: (index) => DoctorCard(doctor: data.doctors[index], compact: true),
          ),
        ),
    ];
  }
}

/// Horizontally scrolling row of cards, built lazily with a fixed extent so
/// scrolling stays smooth however many items arrive.
class _HorizontalCards extends StatelessWidget {
  const _HorizontalCards({
    required this.height,
    required this.itemWidth,
    required this.itemCount,
    required this.builder,
  });

  final double height;
  final double itemWidth;
  final int itemCount;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemExtent: itemWidth + 10,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(width: itemWidth, child: builder(index)),
        ),
      ),
    );
  }
}

class _FooterCta extends StatelessWidget {
  const _FooterCta({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.forestDark, AppColors.forest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Want to add your business or service?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join CHT Plus and reach thousands of people across Khagrachari, Rangamati and Bandarban.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: () => context.push(
                    signedIn ? '/services/add' : Routes.login,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forestDark,
                  ),
                  child: const Text('Add a service'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => context.push(
                    signedIn ? '/marketplace/sell' : Routes.login,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Sell an item'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
