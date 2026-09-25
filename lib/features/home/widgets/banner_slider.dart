import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/launchers.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../models/catalog.dart';

/// Auto-advancing hero banner, mirroring `HeroBannerSlider` on the site: a
/// 3:1 frame in the `.hero` strip, with the dots floating over its lower edge.
class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key, required this.banners});

  final List<BannerItem> banners;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  /// `.hero-slider` below 640px: radius 14 and a soft drop shadow.
  static final _sliderRadius = BorderRadius.circular(14);
  static const _sliderShadow = BoxShadow(
    color: Color(0x2E000000),
    blurRadius: 20,
    offset: Offset(0, 8),
  );

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant BannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      // `.hero { padding: clamp(10px, 2vw, 16px) 0 }` plus the 16px container.
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _sliderRadius,
          boxShadow: const [_sliderShadow],
        ),
        child: ClipRRect(
          borderRadius: _sliderRadius,
          child: AspectRatio(
            // Same 3:1 frame as the site, so the whole banner shows uncropped.
            aspectRatio: 3 / 1,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.banners.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final banner = widget.banners[index];
                    return GestureDetector(
                      onTap: banner.url == null
                          ? null
                          : () => Launchers.url(context, banner.url),
                      child: AppNetworkImage(
                        url: banner.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholderIcon: Icons.campaign_outlined,
                      ),
                    );
                  },
                ),
                if (widget.banners.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < widget.banners.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: i == _index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                i == _index ? 4 : 3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
