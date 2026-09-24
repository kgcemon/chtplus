import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/catalog.dart';
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

/// The app's landing screen, laid out like the website's home page on a phone:
/// banner, quick links, then one tinted section per feature (in the viewer's
/// preferred order) with its cards in grids rather than sideways rows.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Section tints, copied from `.section-*` in the site's stylesheet.
  static const _servicesTint = Color(0xFFEEF7F1);
  static const _donorsTint = Color(0xFFFDECEB);
  static const _marketplaceTint = Color(0xFFEEF3FB);
  static const _biodataTint = Color(0xFFF8EEF8);
  static const _doctorsTint = Color(0xFFEAFAF8);

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
    final signedIn = ref.watch(isSignedInProvider);
    // Adding something needs an account; send guests to log in first.
    void add(String path) => context.push(signedIn ? path : Routes.login);

    return [
      SliverToBoxAdapter(child: BannerSlider(banners: data.banners)),
      const SliverToBoxAdapter(child: QuickNav()),
      for (final key in order)
        SliverToBoxAdapter(
          child: switch (key) {
            'services' => _servicesSection(context, data, add),
            'donors' => _donorsSection(context, data, add),
            'marketplace' => _marketplaceSection(context, data, add),
            'biodata' => _biodataSection(context, data, add),
            'doctors' => _doctorsSection(context, data),
            _ => const SizedBox.shrink(),
          },
        ),
      SliverToBoxAdapter(child: _FooterCta(onAdd: add)),
    ];
  }

  // --- Services --------------------------------------------------------------

  Widget _servicesSection(
    BuildContext context,
    HomeFeed data,
    void Function(String) add,
  ) {
    final services = data.topServices;
    return _Section(
      tint: _servicesTint,
      children: [
        _SectionHead(
          title: 'Service Categories',
          subtitle: 'Find reliable service providers',
          onViewAll: () => context.go(Routes.services),
          actionLabel: 'Add a service',
          onAction: () => add('/services/add'),
        ),
        // Two rows of categories, as on the site; the rest are one tap away.
        _CategoryGrid(
          categories: data.serviceCategories.take(6).toList(),
          onTap: (c) => context.go('${Routes.services}?category=${c.id}'),
        ),
        const SizedBox(height: 26),
        const _SectionHead(
          title: 'Popular Providers',
          subtitle: 'Top-rated and verified service providers',
        ),
        if (services.isEmpty)
          const _EmptyNote('No services have been added')
        else
          _CardGrid(
            children: [
              for (final s in services.take(6)) ServiceCard(service: s, compact: true),
            ],
          ),
      ],
    );
  }

  // --- Blood donors ----------------------------------------------------------

  Widget _donorsSection(
    BuildContext context,
    HomeFeed data,
    void Function(String) add,
  ) {
    return _Section(
      tint: _donorsTint,
      children: [
        _SectionHead(
          title: 'Blood Donors',
          subtitle: 'Find a blood donor in an emergency.',
          onViewAll: () => context.go(Routes.donors),
          actionLabel: 'Join',
          onAction: () => add('/donors/register'),
        ),
        if (data.donors.isEmpty)
          const _EmptyNote('No blood donors have been added')
        else
          for (final (i, donor) in data.donors.take(5).indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            DonorCard(donor: donor),
          ],
      ],
    );
  }

  // --- Marketplace -----------------------------------------------------------

  Widget _marketplaceSection(
    BuildContext context,
    HomeFeed data,
    void Function(String) add,
  ) {
    return _Section(
      tint: _marketplaceTint,
      children: [
        _SectionHead(
          title: 'Marketplace',
          subtitle: 'Buy and sell products locally',
          onViewAll: () => context.go(Routes.marketplace),
          actionLabel: 'Sell',
          onAction: () => add('/marketplace/sell'),
        ),
        _CategoryGrid(
          categories: data.marketplaceCategories,
          onTap: (c) => context.go('${Routes.marketplace}?category=${c.id}'),
        ),
        const SizedBox(height: 22),
        if (data.listings.isEmpty)
          const _EmptyNote('No products have been added')
        else
          _CardGrid(
            spacing: 8,
            children: [
              for (final l in data.listings.take(6)) ListingCard(listing: l),
            ],
          ),
      ],
    );
  }

  // --- Matrimony -------------------------------------------------------------

  Widget _biodataSection(
    BuildContext context,
    HomeFeed data,
    void Function(String) add,
  ) {
    return _Section(
      tint: _biodataTint,
      children: [
        _SectionHead(
          title: 'Matrimony',
          subtitle: 'View verified biodata.',
          onViewAll: () => context.go(Routes.biodata),
          actionLabel: 'Submit new biodata',
          onAction: () => add('/biodata/submit'),
        ),
        if (data.biodata.isEmpty)
          const _EmptyNote('No biodata has been added')
        else
          _CardGrid(
            spacing: 8,
            children: [
              for (final b in data.biodata.take(6)) BiodataCard(biodata: b),
            ],
          ),
      ],
    );
  }

  // --- Doctors ---------------------------------------------------------------

  Widget _doctorsSection(BuildContext context, HomeFeed data) {
    return _Section(
      tint: _doctorsTint,
      children: [
        _SectionHead(
          title: 'Doctor Appointments',
          subtitle: 'Book an appointment with an experienced doctor.',
          actionLabel: 'View all',
          onAction: () => context.push(Routes.doctors),
        ),
        if (data.doctors.isEmpty)
          const _EmptyNote('No doctors have been added')
        else
          _CardGrid(
            children: [
              for (final d in data.doctors.take(6)) DoctorCard(doctor: d, compact: true),
            ],
          ),
      ],
    );
  }
}

/// One full-width home section on its own faint tint, like the site's
/// `.section-services`, `.section-donors`, …
class _Section extends StatelessWidget {
  const _Section({required this.tint, required this.children});

  final Color tint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Title and subtitle on the left, the site's small "View all" (outlined) and
/// primary action (filled) buttons on the right, kept on one row.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.title,
    required this.subtitle,
    this.onViewAll,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onViewAll;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 7);
  static const _buttonText = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static final _buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (onViewAll != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest),
                padding: _buttonPadding,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: _buttonText,
                shape: _buttonShape,
              ),
              child: const Text('View all'),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                padding: _buttonPadding,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: _buttonText,
                shape: _buttonShape,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three-per-row category tiles (the site's `.cat-grid` on a phone).
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.onTap});

  final List<Category> categories;
  final void Function(Category) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 104,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return HomeTile(
          emoji: (category.icon ?? '').isEmpty ? '📌' : category.icon!,
          label: category.name,
          onTap: () => onTap(category),
        );
      },
    );
  }
}

/// Cards two to a row — the site's two-column card grids on a phone.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children, this.spacing = 10});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) SizedBox(height: spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: spacing),
              Expanded(
                child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FooterCta extends StatelessWidget {
  const _FooterCta({required this.onAdd});

  final void Function(String path) onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.forest, AppColors.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Want to add your business or service?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join CHT Plus and reach thousands of people.',
              style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => onAdd('/services/add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forestDark,
                  ),
                  child: const Text('Add a service'),
                ),
                OutlinedButton(
                  onPressed: () => onAdd('/marketplace/sell'),
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
