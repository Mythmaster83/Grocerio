import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/canonical_item.dart';
import '../../domain/entities/item_category.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/services/item_resolution_service.dart';
import '../datasources/catalog_local_datasource.dart';
import '../models/canonical_item_model.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final CatalogLocalDataSource _local;
  final ItemResolutionService _resolver;
  final Uuid _uuid;

  /// Seeded once; custom products invalidate this on write.
  List<CanonicalItem>? _cache;

  CatalogRepositoryImpl(
    this._local, {
    ItemResolutionService resolver = const ItemResolutionService(),
    Uuid? uuid,
  })  : _resolver = resolver,
        _uuid = uuid ?? const Uuid();

  Future<List<CanonicalItem>> _loadCatalog() async {
    final cached = _cache;
    if (cached != null) return cached;
    final models = await _local.getAll();
    final items = models.map((m) => m.toDomain()).toList(growable: false);
    _cache = items;
    return items;
  }

  void _invalidateCache() => _cache = null;

  @override
  Future<Result<List<CanonicalItem>>> getAll() async {
    try {
      return Result.ok(await _loadCatalog());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load the catalog', cause: e));
    }
  }

  @override
  Future<CanonicalItem?> getById(int canonicalItemId) async {
    try {
      final catalog = await _loadCatalog();
      for (final item in catalog) {
        if (item.id == canonicalItemId) return item;
      }
      return null;
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return null;
    }
  }

  @override
  Future<CanonicalItem?> resolve(String rawName) async {
    try {
      return _resolver.resolve(rawName, await _loadCatalog());
    } on StorageException catch (e, st) {
      logger.error('Item resolution skipped', e.cause, st);
      return null;
    }
  }

  @override
  Future<Result<List<CanonicalItem>>> search(
    String query, {
    ItemCategory? category,
    int limit = 30,
  }) async {
    try {
      final normalized = normalizeItemName(query);
      final catalog = await _loadCatalog();

      final matches = <CanonicalItem>[];
      for (final item in catalog) {
        if (category != null && item.category != category) continue;
        if (normalized.isEmpty) {
          matches.add(item);
        } else if (item.aliasKeywords.any((a) => a.contains(normalized))) {
          matches.add(item);
        }
        if (matches.length >= limit) break;
      }
      matches.sort((a, b) => a.name.compareTo(b.name));
      return Result.ok(matches);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not search the catalog', cause: e));
    }
  }

  @override
  Future<Result<CanonicalItem>> createCustom(String rawName) async {
    final name = InputSanitizer.sanitizeFreeText(
      rawName,
      maxLength: InputSanitizer.maxItemNameLength,
    );
    if (name.isEmpty) {
      return const Result.err(ValidationFailure('Enter a product name.'));
    }

    try {
      // Prefer an existing match so "dumbbells" typed twice does not fork
      // into two price identities.
      final existing = await resolve(name);
      if (existing != null) return Result.ok(existing);

      final normalized = normalizeItemName(name);
      final model = CanonicalItemModel()
        ..slug = 'custom-${_uuid.v4()}'
        ..name = name
        ..nameLower = name.toLowerCase()
        ..category = ItemCategoryDb.other
        ..aliasKeywords = [
          if (normalized.isNotEmpty) normalized,
          name.toLowerCase(),
        ];

      await _local.putAll([model]);
      _invalidateCache();

      final saved = await _local.getBySlug(model.slug);
      if (saved == null) {
        return const Result.err(
          StorageFailure('Could not save the custom product'),
        );
      }
      return Result.ok(saved.toDomain());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(
        StorageFailure('Could not save the custom product', cause: e),
      );
    }
  }
}
