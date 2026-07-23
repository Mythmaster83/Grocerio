import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/lists/data/models/grocery_list_model.dart';
import '../../features/preferences/data/models/preferences_model.dart';
import '../utils/app_logger.dart';

/// Single Isar instance for the whole app, opened once in main() before
/// runApp and overridden into the provider tree. Every datasource depends
/// on THIS provider — never opens Isar itself — so tests can override it
/// with an in-memory instance.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'isarProvider must be overridden in main() after Isar.open() completes.',
  );
});

/// Bumped when the on-disk schema changes in a way that can corrupt old rows
/// (e.g. adding `lastMissedOn`). Alpha: start a fresh DB rather than migrate.
const _isarDbName = 'grocer_v2';

Future<Isar> openAppIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  await _deleteLegacyDbIfPresent(dir.path);

  try {
    return await Isar.open(
      [GroceryListModelSchema, PreferencesModelSchema],
      directory: dir.path,
      name: _isarDbName,
      inspector: false,
    );
  } catch (e, st) {
    // Schema mismatch or corrupted file — wipe and reopen once (alpha-safe).
    logger.error('Isar open failed; recreating database', e, st);
    await _deleteIsarFiles(dir.path, _isarDbName);
    return Isar.open(
      [GroceryListModelSchema, PreferencesModelSchema],
      directory: dir.path,
      name: _isarDbName,
      inspector: false,
    );
  }
}

Future<void> _deleteLegacyDbIfPresent(String directory) async {
  // Pre-v2 used Isar's default name ("default"). Leave those files behind
  // rather than risk reading rows written before lastMissedOn existed.
  for (final name in ['default', 'grocer']) {
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
