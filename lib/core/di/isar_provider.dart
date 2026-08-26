import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/catalog/data/models/canonical_item_model.dart';
import '../../features/lists/data/models/grocery_list_model.dart';
import '../../features/preferences/data/models/preferences_model.dart';
import '../../features/pricing/data/models/price_report_model.dart';
import '../../features/stores/data/models/store_model.dart';
import '../utils/app_logger.dart';

/// Single Isar instance for the whole app, opened once in main() before
/// runApp and overridden into the provider tree. Every datasource depends
/// on THIS provider â€” never opens Isar itself â€” so tests can override it
/// with an in-memory instance.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'isarProvider must be overridden in main() after Isar.open() completes.',
  );
});

/// Bumped when the on-disk schema changes in a way that can corrupt old rows.
/// A new name starts empty; signed-in users restore lists and prices from
/// Supabase on the next sync. Unsigned local-only data does not come back,
/// which is why schema bumps should stay rare.
const _isarDbName = 'grocer_v7';

/// Every collection the app persists. Kept in one list because a schema missing
/// from it fails on first query at runtime, not at compile time.
final _schemas = [
  GroceryListModelSchema,
  PreferencesModelSchema,
  StoreModelSchema,
  CanonicalItemModelSchema,
  PriceReportModelSchema,
];

Future<Isar> openAppIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  await _deleteLegacyDbIfPresent(dir.path);

  try {
    return await Isar.open(
      _schemas,
      directory: dir.path,
      name: _isarDbName,
      inspector: false,
    );
  } catch (e, st) {
    // Do not delete the current database on a failed open. Shared lists and
    // contributed prices may exist only here until the next successful sync,
    // and wiping them to recover from a corrupt file is worse than a crash
    // the user can report.
    logger.error('Isar open failed', e, st);
    rethrow;
  }
}

Future<void> _deleteLegacyDbIfPresent(String directory) async {
  // Wipe older alpha DB names so schema bumps do not corrupt embedded rows.
  for (final name in [
    'default',
    'grocer',
    'grocer_v2',
    'grocer_v3',
    'grocer_v4',
    'grocer_v5',
    'grocer_v6',
  ]) {
    await _deleteIsarFiles(directory, name);
  }
}

Future<void> _deleteIsarFiles(String directory, String name) async {
  for (final fileName in [
    '$name.isar',
    '$name.isar.lock',
  ]) {
    final file = File('$directory${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      try {
        await file.delete();
        logger.info('Deleted legacy/corrupt Isar file: $fileName');
      } catch (e, st) {
        logger.error('Could not delete $fileName', e, st);
      }
    }
  }
}
