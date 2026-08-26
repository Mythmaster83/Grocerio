import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListFilter { all, solo, shared }

extension ListFilterX on ListFilter {
  String get label => switch (this) {
        ListFilter.all => 'All',
        ListFilter.solo => 'Solo',
        ListFilter.shared => 'Shared',
      };
}

/// Home's current filter. Deliberately not persisted: it's a momentary view
/// choice, and reopening the app to a filtered list looks like missing data.
final listFilterProvider = StateProvider<ListFilter>((ref) => ListFilter.all);
