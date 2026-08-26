import '../../../../core/utils/result.dart';
import '../entities/canonical_item.dart';
import '../entities/item_category.dart';

abstract class CatalogRepository {
  Future<Result<List<CanonicalItem>>> getAll();

  Future<CanonicalItem?> getById(int canonicalItemId);

  /// Maps free text to a catalog entry, or null when nothing matches well
  /// enough. Lives on the repository (not the UI) so every write path resolves
  /// identically — typed, voice, or pasted.
  Future<CanonicalItem?> resolve(String rawName);

  /// Name and alias search for the price lookup screen.
  Future<Result<List<CanonicalItem>>> search(
    String query, {
    ItemCategory? category,
    int limit = 30,
  });

  /// Creates a user-defined catalog product for free-text that matched nothing.
  /// Enables pricing (and later sync) for names like "dumbbells" without
  /// waiting for a seed update.
  Future<Result<CanonicalItem>> createCustom(String rawName);
}
