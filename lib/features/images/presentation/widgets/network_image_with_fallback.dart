import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Every remote image in the app goes through this widget — never a bare
/// Image.network. Covers the "API images with fallback icons" requirement
/// AND fixes the old app's broken image-source redirects: if [imageUrl] is
/// null, empty, or fails to load, we render an icon instead of a broken-
/// image glyph or an indefinite spinner.
///
/// When [photographerUrl] is set, tapping opens the photographer's page
/// (Pexels attribution).
class NetworkImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final String? photographerUrl;
  final String? photographerName;
  final double size;
  final IconData fallbackIcon;

  const NetworkImageWithFallback({
    super.key,
    required this.imageUrl,
    this.photographerUrl,
    this.photographerName,
    this.size = 48,
    this.fallbackIcon = Icons.shopping_basket_outlined,
  });

  Future<void> _openAttribution(BuildContext context) async {
    final raw = photographerUrl;
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attribution available')),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !(await canLaunchUrl(uri))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open photographer link')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final scheme = Theme.of(context).colorScheme;
    final hasAttribution =
        photographerUrl != null && photographerUrl!.trim().isNotEmpty;

    final child = (url == null || url.isEmpty)
        ? _fallback(scheme)
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedImage(
              imageUrl: url,
              width: size,
              height: size,
              fallback: _fallback(scheme),
            ),
          );

    return GestureDetector(
      onTap: hasAttribution ? () => _openAttribution(context) : null,
      onLongPress: () => _openAttribution(context),
      child: Tooltip(
        message: photographerName != null && photographerName!.isNotEmpty
            ? 'Photo: $photographerName'
            : 'Image attribution',
        child: child,
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
