import '../../../../core/config/env_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../domain/entities/image_result.dart';

/// Calls OUR backend proxy (`GET {API_BASE_URL}/images/search?q=...`).
/// The proxy holds the Pexels secret — the app never sends `PEXELS_API_KEY`.
///
/// Not used until `API_BASE_URL` is set to a real host (see `BACKEND_NEXT.md`).
/// Response shape expected (compatible with current [ImageResult] mapping):
/// ```json
/// { "photos": [ { "photographer": "...", "photographer_url": "...",
///   "src": { "small": "...", "medium": "..." } } ] }
/// ```
class ProxyImageRemoteDataSource {
  final ApiClient _client;
  ProxyImageRemoteDataSource(this._client);

  Future<List<ImageResult>> search(String query) async {
    final base = EnvConfig.maybeApiBaseUrl();
    if (base == null) {
      throw const RemoteDataException(
        'API_BASE_URL is not configured for the image proxy.',
      );
    }
    final safeQuery = InputSanitizer.sanitizeSearchTerm(query);
    if (safeQuery.isEmpty) return [];

    final result = await _client.get(
      '$base/images/search',
      queryParameters: {'q': safeQuery},
    );

    return result.when(
      ok: (json) {
        final photos = (json['photos'] as List<dynamic>? ?? []);
        return photos.map((p) {
          final src = p['src'] as Map<String, dynamic>? ?? {};
          return ImageResult(
            thumbnailUrl: src['small'] as String? ?? '',
            fullUrl: src['medium'] as String? ?? '',
            photographer: p['photographer'] as String? ?? 'Unknown',
            photographerUrl: p['photographer_url'] as String?,
          );
        }).where((r) => r.thumbnailUrl.isNotEmpty).toList();
      },
      err: (failure) =>
          throw RemoteDataException(failure.message, cause: failure.cause),
    );
  }
}
