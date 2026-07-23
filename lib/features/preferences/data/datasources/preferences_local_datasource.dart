import 'package:isar/isar.dart';
import '../models/preferences_model.dart';
import '../../../../core/errors/exceptions.dart';

class PreferencesLocalDataSource {
  final Isar _isar;
  PreferencesLocalDataSource(this._isar);

  Future<PreferencesModel> load() async {
    try {
      final existing = await _isar.preferencesModels.get(0);
      final model = existing ?? PreferencesModel.defaults();
      if (existing == null) {
        await _isar.writeTxn(() => _isar.preferencesModels.put(model));
      }
      return model;
    } catch (e) {
      throw StorageException('Failed to load preferences', cause: e);
    }
  }

  Future<void> save(PreferencesModel model) async {
    try {
      await _isar.writeTxn(() => _isar.preferencesModels.put(model));
    } catch (e) {
      throw StorageException('Failed to save preferences', cause: e);
    }
  }

}