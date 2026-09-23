import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// Every remote image in the app goes through here: it resolves relative
/// `/uploads/...` paths, caches to disk, and decodes at the size actually drawn
/// so large photos do not blow up memory on a mid-range phone.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
    this.decodeWidth,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.absoluteUrl(url);
    final radius = borderRadius ?? BorderRadius.zero;

    if (resolved == null) {
      return ClipRRect(
        borderRadius: radius,
        child: _Placeholder(
          width: width,
          height: height,
          icon: placeholderIcon,
        ),
      );
    }

    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final targetWidth = decodeWidth ??
        (width != null && width!.isFinite ? (width! * ratio).round() : null);

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: targetWidth,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => _Placeholder(width: width, height: height, icon: placeholderIcon),
        errorWidget: (_, __, ___) => _Placeholder(
          width: width,
          height: height,
          icon: Icons.broken_image_outlined,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height, required this.icon});

  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.forestLight,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.forest.withValues(alpha: 0.35), size: 26),
    );
  }
}
