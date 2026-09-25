import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils/launchers.dart';
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
      const SliverToBoxAdapter(child: _FooterCta()),
      const SliverToBoxAdapter(child: _SiteFooter()),
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
        const SizedBox(height: 36),
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
            if (i > 0) const SizedBox(height: 14),
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
        const SizedBox(height: 24),
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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

  // `.section-head-actions .btn` below 480px: `padding: 6px 8px; font-size: 11px`.
  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static const _buttonText = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
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
    return HomeTileGrid(
      children: [
        for (final category in categories)
          HomeTile(
            emoji: (category.icon ?? '').isEmpty ? '📌' : category.icon!,
            label: category.name,
            onTap: () => onTap(category),
          ),
      ],
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
      // `.empty-note` has 10px of padding inside a paragraph's own 13.5px margin.
      padding: const EdgeInsets.symmetric(vertical: 23.5),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }
}

/// The site's `.cta` panel: one gradient card in a plain `.section`, with the
/// single Contact button the site shows there.
class _FooterCta extends StatelessWidget {
  const _FooterCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join CHT Plus and reach thousands of people.',
              style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13.5, height: 1.3),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Launchers.call(context, AppConfig.supportPhone),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.forestDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('\u{1F4DE} Contact'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site's `.site-footer`: logo and tagline, the useful links, then the
/// contact block over a thin divider and the copyright line.
class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  /// `rgba(255, 255, 255, .75)`, the colour of every footer link and note.
  static const _muted = Color(0xBFFFFFFF);
  static const _linkStyle = TextStyle(fontSize: 13, color: _muted, height: 1.3);

  @override
  Widget build(BuildContext context) {
    return Container(
      // `.site-footer { padding: 36px 0 20px; margin-top: 12px }`.
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 20),
      color: AppColors.forestDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(alignment: Alignment.centerLeft, child: SiteLogo(height: 44)),
          const SizedBox(height: 25),
          const Text(AppConfig.tagline, style: _linkStyle),
          const SizedBox(height: 24),
          const _FooterHeading('Useful links'),
          _FooterLink('Services', () => context.go(Routes.services)),
          _FooterLink('Marketplace', () => context.go(Routes.marketplace)),
          _FooterLink('Matrimony', () => context.go(Routes.biodata)),
          _FooterLink('Doctor Appointments', () => context.push(Routes.doctors)),
          _FooterLink('Blood Donors', () => context.go(Routes.donors)),
          _FooterLink('About Us', () => Launchers.url(context, AppConfig.aboutUrl)),
          const SizedBox(height: 16),
          const _FooterHeading('Contact'),
          _FooterLink(
            '\u{1F4DE} ${AppConfig.supportPhone}',
            () => Launchers.call(context, AppConfig.supportPhone),
          ),
          _FooterLink(
            '\u{1F4AC} WhatsApp: ${AppConfig.supportPhone}',
            () => Launchers.url(context, AppConfig.supportWhatsappUrl),
          ),
          const SizedBox(height: 13),
          const Text('\u{1F4CD} ${AppConfig.officeAddress}', style: _linkStyle),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1, color: Color(0x26FFFFFF)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Copyright \u00A9 2026 CHT Plus. All rights reserved',
              style: TextStyle(fontSize: 12.5, color: Color(0x99FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterHeading extends StatelessWidget {
  const _FooterHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(label, style: _SiteFooter._linkStyle),
      ),
    );
  }
}
