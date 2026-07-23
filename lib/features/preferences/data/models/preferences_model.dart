import 'package:isar/isar.dart';

part 'preferences_model.g.dart';

/// Singleton-row collection — this app has exactly one preferences record,
/// always at isarId 0. Isar doesn't have a "singleton collection" concept,
/// so we enforce it in code (see PreferencesLocalDataSource) rather than
/// adding a second storage mechanism just for one row of settings.
@collection
class PreferencesModel {
  Id isarId = 0;

  late int themeModeIndex;
  late int accentColorValue;
  late String fontFamily;
  late double textScale;
  late List<int> pageOrderIndices;

  static PreferencesModel defaults() => PreferencesModel()
    ..isarId = 0
    ..themeModeIndex = 0
    ..accentColorValue = 0xFF2F6F4F
    ..fontFamily = 'Inter'
    ..textScale = 1.0
    ..pageOrderIndices = const [0, 1, 2];
}
