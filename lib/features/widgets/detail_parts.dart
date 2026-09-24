import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/photo_gallery.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../router.dart';

// Pieces shared by the detail pages so they read like the website's detail
// views on a phone.

/// "Marketplace › 👗 Fashion › 📘 Menswear" trail (`.breadcrumb-trail`).
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.parts});

  /// Each part's label and, for all but the current page, where it leads.
  final List<(String, VoidCallback?)> parts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            const Text(' › ', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          GestureDetector(
            onTap: parts[i].$2,
            child: Text(
              parts[i].$1,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Square photo viewer with a count badge and a centred thumbnail row
/// (`ListingGallery`); tapping the photo opens it full screen.
class DetailGallery extends StatefulWidget {
  const DetailGallery({
    super.key,
    required this.photos,
    this.placeholderEmoji = '📦',
    this.maxHeight = 340,
  });

  final List<String> photos;
  final String placeholderEmoji;
  final double maxHeight;

  @override
  State<DetailGallery> createState() => _DetailGalleryState();
}

class _DetailGalleryState extends State<DetailGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: ColoredBox(
                color: photos.isEmpty ? AppColors.forestLight : AppColors.bg,
                child: photos.isEmpty
                    ? Center(
                        child: Text(widget.placeholderEmoji, style: const TextStyle(fontSize: 48)),
                      )
                    : Stack(
                        children: [
                          PageView.builder(
                            controller: _controller,
                            itemCount: photos.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => FullScreenGallery.open(
                                context,
                                photos: photos,
                                initialIndex: i,
                              ),
                              child: AppNetworkImage(
                                url: photos[i],
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (photos.length > 1)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_index + 1} / ${photos.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < photos.length; i++)
                GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  child: Opacity(
                    opacity: i == _index ? 1 : 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          width: 2,
                          color: i == _index ? AppColors.forest : AppColors.border,
                        ),
                      ),
                      child: AppNetworkImage(
                        url: photos[i],
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Posted by 🙂 Name" pill linking to the poster's profile (`OwnerChip`).
class OwnerChip extends StatelessWidget {
  const OwnerChip({
    super.key,
    required this.userId,
    required this.name,
    this.photoUrl,
    this.blueBadge = false,
    this.label = 'Posted by',
  });

  final String? userId;
  final String? name;
  final String? photoUrl;
  final bool blueBadge;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (userId == null || (name ?? '').isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.push('/u/$userId'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty) ...[
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
              ],
              Avatar(url: photoUrl, name: name, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              VerifiedBadge(active: blueBadge, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small blue "Follow" / "Following" link beside a poster's name
/// (`FollowInline`). Hidden on the viewer's own posts.
class FollowInline extends ConsumerStatefulWidget {
  const FollowInline({super.key, required this.userId});

  final String? userId;

  @override
  ConsumerState<FollowInline> createState() => _FollowInlineState();
}

class _FollowInlineState extends ConsumerState<FollowInline> {
  bool _busy = false;

  Future<void> _toggle() async {
    final id = widget.userId!;
    if (!ref.read(isSignedInProvider)) {
      context.push(Routes.login);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(meRepositoryProvider).toggleFollow(id);
      ref.invalidate(isFollowingProvider(id));
      ref.invalidate(followListsProvider);
    } catch (_) {
      // Leave the label as it was; the next load shows the real state.
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final me = ref.watch(currentUserProvider);
    if (id == null || me?.id == id) return const SizedBox.shrink();
    final following = ref.watch(isFollowingProvider(id)).valueOrNull ?? false;

    return GestureDetector(
      onTap: _busy ? null : _toggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1877F2).withValues(alpha: _busy ? 0.6 : 1),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a small heading and label/value rows
/// (`.listing-info-card`).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 8),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].$1,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Warm yellow tips box with a heading and bullet list (`.safety-box`).
class SafetyBox extends StatelessWidget {
  const SafetyBox({super.key, required this.title, required this.tips});

  final String title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFF3E0B0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A6700),
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '•  $tip',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded tag (`.badge`); green by default.
class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.color = AppColors.forestDark,
    this.background = AppColors.forestLight,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Scaffold body for a detail page: the site header, then [children] in a
/// padded column, pulled-to-refresh with [onRefresh].
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.header,
    required this.children,
    this.onRefresh,
  });

  final Widget header;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      slivers: [
        header,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
    return Scaffold(
      body: onRefresh == null ? scroll : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
    );
  }
}

/// A page drawn like the site's `.cv-modal` bottom sheet: an optional amber
/// ribbon, a header with [title] / [subtitle] and a round ✕ that goes back,
/// then [children] in the body.
class SheetPage extends StatelessWidget {
  const SheetPage({
    super.key,
    this.title,
    this.subtitle,
    this.ribbon,
    required this.children,
    this.onRefresh,
  });

  final Widget? title;
  final String? subtitle;
  final String? ribbon;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final sponsored = ribbon != null;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: children,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sponsored)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFF0A202), Color(0xFFF7C948)]),
                ),
                child: Text(
                  ribbon!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF402D00),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: sponsored ? const Color(0xFFFFFAF0) : AppColors.surface,
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          DefaultTextStyle.merge(
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                            child: title!,
                          ),
                        if ((subtitle ?? '').isNotEmpty) ...[
                          if (title != null) const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.bg,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.close_rounded, size: 17, color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: onRefresh == null
                  ? list
                  : RefreshIndicator(onRefresh: onRefresh!, child: list),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site's small action button (`.btn .btn-sm`, or `.btn-outline`).
ButtonStyle smallButtonStyle({bool outlined = false, bool block = false}) {
  final base = outlined
      ? OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.forest),
        )
      : FilledButton.styleFrom(backgroundColor: AppColors.forest);
  return base.copyWith(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    minimumSize: WidgetStatePropertyAll(block ? const Size.fromHeight(40) : Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  );
}
