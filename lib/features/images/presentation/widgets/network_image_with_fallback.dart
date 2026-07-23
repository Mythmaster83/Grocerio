import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Every remote image in the app goes through this widget — never a bare
/// Image.network. Covers the "API images with fallback icons" requirement
/// AND fixes the old app's broken image-source redirects: if [imageUrl] is
/// null, empty, or fails to load, we render an icon instead of a broken-
/// image glyph or an indefinite spinner.
class NetworkImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final IconData fallbackIcon;

  const NetworkImageWithFallback({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.fallbackIcon = Icons.shopping_basket_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final scheme = Theme.of(context).colorScheme;

    if (url == null || url.isEmpty) {
      return _fallback(scheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedImage(
        imageUrl: url,
        width: size,
        height: size,
        fallback: _fallback(scheme),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(fallbackIcon, color: scheme.onSurfaceVariant, size: size * 0.5),
      );
}

/// Isolated so the fallback logic above stays simple and testable without
/// mocking the network image cache directly.
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final Widget fallback;

  const CachedImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
