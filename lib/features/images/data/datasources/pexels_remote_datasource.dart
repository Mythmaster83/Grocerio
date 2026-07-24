import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../domain/entities/image_result.dart';

/// Talks to Pexels' search endpoint. This is THE call site that carries the
/// client-embedded-API-key risk documented in env_config.dart — before
/// public release, route this through a backend proxy instead of calling
/// Pexels directly from the client.
class PexelsRemoteDataSource {
  final ApiClient _client;
  static const _baseUrl = 'https://api.pexels.com/v1/search';

  PexelsRemoteDataSource(this._client);

  Future<List<ImageResult>> search(String query) async {
    final safeQuery = InputSanitizer.sanitizeSearchTerm(query);
    if (safeQuery.isEmpty) return [];

    final result = await _client.get(
      _baseUrl,
      queryParameters: {'query': safeQuery, 'per_page': 5},
      headers: _client.pexelsHeaders(),
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
      err: (failure) => throw RemoteDataException(failure.message, cause: failure.cause),
    );
  }
}
