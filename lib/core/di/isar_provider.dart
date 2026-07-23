import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/lists/data/models/grocery_list_model.dart';
import '../../features/preferences/data/models/preferences_model.dart';

/// Single Isar instance for the whole app, opened once in main() before
/// runApp and overridden into the provider tree. Every datasource depends
/// on THIS provider — never opens Isar itself — so tests can override it
/// with an in-memory instance.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'isarProvider must be overridden in main() after Isar.open() completes.',
  );
});

Future<Isar> openAppIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [GroceryListModelSchema, PreferencesModelSchema],
    directory: dir.path,
    inspector: false, // disable Isar Inspector in release builds
  );
}
