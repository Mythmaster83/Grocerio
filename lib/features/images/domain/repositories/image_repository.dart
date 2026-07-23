import '../../../../core/utils/result.dart';
import '../entities/image_result.dart';

abstract class ImageRepository {
  Future<Result<List<ImageResult>>> search(String query);
}
