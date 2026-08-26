import 'package:uuid/uuid.dart';
import '../../../../core/backend/supabase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../domain/zip_relevance.dart';
import '../datasources/price_local_datasource.dart';
import '../models/price_report_model.dart';

/// Writes shopper-submitted prices.
///
/// There is exactly one way a price enters the app, and this is it. No API
/// counterpart exists, which is the whole reason the reporting flow has to be
/// low-friction: an annoying sheet means an empty database, and an empty
/// database makes every price screen look broken.
class PriceService {
  final PriceLocalDataSource _local;
  final PreferencesLocalDataSource _preferences;
  final Uuid _uuid;

  PriceService(this._local, this._preferences, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  /// Highest accepted price. A crude guard, but it catches the fat-finger
  /// "$329 milk" that would otherwise poison every cheapest-price calculation
  /// for everyone once reports sync.
  static const maxAcceptedPrice = 9999.99;

  Future<Result<void>> submitReport({
    required int canonicalItemId,
    required int storeId,
    required String storeSlug,
    required double price,
    required String unit,
    String? zip,
  }) async {
    if (price <= 0) {
      return const Result.err(ValidationFailure('Enter a price above zero.'));
    }
    if (price > maxAcceptedPrice) {
      return const Result.err(
        ValidationFailure('That price looks too high — check the amount.'),
      );
    }

    try {
      final prefs = await _preferences.load();
      // Account id when signed in, otherwise a stable per-install id. The
      // account id is what RLS matches on when this report later syncs.
      final userId = SupabaseConfig.clientOrNull?.auth.currentUser?.id;
      final reporterId = userId ?? prefs.deviceId ?? _uuid.v4();
      final reportZip = normalizeZip(zip ?? prefs.priceZip);

      await _local.put(
        PriceReportModel()
          ..publicId = _uuid.v4()
          ..canonicalItemId = canonicalItemId
          ..storeId = storeId
          ..price = price
          ..unit = unit
          ..reportedAt = DateTime.now()
          ..reportedBy = reporterId
          ..zip = reportZip,
      );

      // Remembering the store is what turns the second report into "type a
      // number and hit enter".
      if (prefs.deviceId != reporterId || prefs.lastReportedStoreSlug != storeSlug) {
        prefs
          ..deviceId = userId == null ? reporterId : prefs.deviceId
          ..lastReportedStoreSlug = storeSlug;
        await _preferences.save(prefs);
      }

      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not save the price', cause: e));
    }
  }
}
