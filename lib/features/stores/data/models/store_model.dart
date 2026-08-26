import 'package:isar_community/isar.dart';
import '../../domain/entities/store.dart';

part 'store_model.g.dart';

@collection
class StoreModel {
  Id isarId = Isar.autoIncrement;

  /// Seed-provided stable key ("walmart-atlanta-ga-30303"), unique so seeding
  /// is idempotent across app upgrades.
  @Index(unique: true, replace: true)
  late String slug;

  late String name;

  /// Brand key ("walmart") shared by every location of that chain.
  @Index()
  late String chainSlug;

  String? addressLine;
  String? city;

  @Index(caseSensitive: false)
  String? state;

  String? zip;

  double? latitude;
  double? longitude;

  bool trackedByUser = false;

  String? logoAssetPath;

  Store toDomain() => Store(
        id: isarId,
        slug: slug,
        name: name,
        chainSlug: chainSlug,
        addressLine: addressLine,
        city: city,
        state: state,
        zip: zip,
        latitude: latitude,
        longitude: longitude,
        trackedByUser: trackedByUser,
        logoAssetPath: logoAssetPath,
      );
}
