import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/isar_provider.dart';
import '../../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../../data/datasources/price_local_datasource.dart';
import '../../data/repositories/price_repository_impl.dart';
import '../../data/services/price_service.dart';
import '../../domain/entities/store_price.dart';
import '../../domain/repositories/price_repository.dart';

final priceLocalDataSourceProvider = Provider<PriceLocalDataSource>((ref) {
  return PriceLocalDataSource(ref.watch(isarProvider));
});

final priceServiceProvider = Provider<PriceService>((ref) {
  return PriceService(
    ref.watch(priceLocalDataSourceProvider),
    PreferencesLocalDataSource(ref.watch(isarProvider)),
  );
});

final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepositoryImpl(
    ref.watch(priceLocalDataSourceProvider),
    ref.watch(storesRepositoryProvider),
  );
});

/// Live prices for one catalog item. Keyed by canonical id, so items that never
/// resolved (null id) simply never create a subscription.
final itemPriceProvider =
    StreamProvider.autoDispose.family<PriceComparison, int>((ref, canonicalItemId) {
  return ref.watch(priceRepositoryProvider).watchCheapestFor(canonicalItemId);
});

/// Fires whenever any price report is written. Sync watches this so a report
/// made on an airplane still uploads once the device is back online, without
/// every sheet having to remember to call sync.
final priceReportsTickProvider = StreamProvider<void>((ref) {
  return ref.watch(priceLocalDataSourceProvider).watchReports();
});
