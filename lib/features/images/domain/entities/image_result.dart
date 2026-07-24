class ImageResult {
  final String thumbnailUrl;
  final String fullUrl;
  final String photographer;
  final String? photographerUrl;

  const ImageResult({
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.photographer,
    this.photographerUrl,
  });
}
