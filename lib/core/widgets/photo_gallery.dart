import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../config.dart';
import '../theme.dart';
import 'app_network_image.dart';

/// Swipeable header gallery with page dots, used on service, listing, biodata
/// and doctor detail screens. Tapping opens the full-screen viewer.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    super.key,
    required this.photos,
    this.height = 260,
    this.placeholderIcon = Icons.image_outlined,
    this.heroPrefix,
  });

  final List<String> photos;
  final double height;
  final IconData placeholderIcon;
  final String? heroPrefix;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: widget.height,
        color: AppColors.forestLight,
        alignment: Alignment.center,
        child: Icon(
          widget.placeholderIcon,
          size: 48,
          color: AppColors.forest.withValues(alpha: 0.3),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => FullScreenGallery.open(
                context,
                photos: widget.photos,
                initialIndex: index,
              ),
              child: AppNetworkImage(
                url: widget.photos[index],
                width: double.infinity,
                height: widget.height,
                placeholderIcon: widget.placeholderIcon,
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinch-to-zoom full screen viewer.
class FullScreenGallery extends StatefulWidget {
  const FullScreenGallery({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<String> photos;
  final int initialIndex;

  static void open(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
  }) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            FullScreenGallery(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (value) => setState(() => _index = value),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(
                AppConfig.absoluteUrl(widget.photos[index]) ?? '',
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  if (widget.photos.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small thumbnail strip used under a gallery or in edit forms.
class PhotoThumbRow extends StatelessWidget {
  const PhotoThumbRow({
    super.key,
    required this.photos,
    this.onRemove,
    this.size = 74,
  });

  final List<String> photos;
  final void Function(int index)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Stack(
          children: [
            GestureDetector(
              onTap: () => FullScreenGallery.open(
                context,
                photos: photos,
                initialIndex: index,
              ),
              child: AppNetworkImage(
                url: photos[index],
                width: size,
                height: size,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove!(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
