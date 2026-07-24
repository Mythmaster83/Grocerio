import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/image_result.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/pexels_remote_datasource.dart';
import '../datasources/proxy_image_remote_datasource.dart';

/// Prefers the backend proxy when `API_BASE_URL` is configured; otherwise
/// falls back to direct Pexels (MVP / local-dev path).
class ImageRepositoryImpl implements ImageRepository {
  final PexelsRemoteDataSource _pexels;
  final ProxyImageRemoteDataSource _proxy;
  final bool useProxy;

  ImageRepositoryImpl({
    required PexelsRemoteDataSource pexels,
    required ProxyImageRemoteDataSource proxy,
    required this.useProxy,
  })  : _pexels = pexels,
        _proxy = proxy;

  @override
  Future<Result<List<ImageResult>>> search(String query) async {
    try {
      final results =
          useProxy ? await _proxy.search(query) : await _pexels.search(query);
      return Result.ok(results);
    } on RemoteDataException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(NetworkFailure('Could not search for images.', cause: e));
    } catch (e, st) {
      logger.error('Unexpected image search error', e, st);
      return Result.err(
        UnknownFailure('Unexpected error searching for images.', cause: e),
      );
    }
  }
}
