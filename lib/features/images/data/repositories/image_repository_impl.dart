import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/image_result.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/pexels_remote_datasource.dart';

class ImageRepositoryImpl implements ImageRepository {
  final PexelsRemoteDataSource _remote;
  ImageRepositoryImpl(this._remote);

  @override
  Future<Result<List<ImageResult>>> search(String query) async {
    try {
      final results = await _remote.search(query);
      return Result.ok(results);
    } on RemoteDataException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(NetworkFailure('Could not search for images.', cause: e));
    } catch (e, st) {
      logger.error('Unexpected image search error', e, st);
      return Result.err(UnknownFailure('Unexpected error searching for images.', cause: e));
    }
  }
}
