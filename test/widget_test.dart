// WORKED EXAMPLE for Exercise 1 — read every comment, then write your own
// second test at the bottom (see the TODO).
//
// The big idea of a widget test:
//   1. Build ONE screen in a fake, in-memory environment (no device needed).
//   2. Replace real dependencies (database streams) with fakes via
//      ProviderScope(overrides: [...]). The screen can't tell the difference.
//   3. Assert that what the user WOULD see is actually on screen.
//
// This is why layering matters: HomeScreen only knows about
// `listsStreamProvider`, so we can swap in a fake stream here. If the widget
// talked to Isar directly, we couldn't test it without a real database.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/lists/domain/entities/grocery_list.dart';
import 'package:grocer/features/lists/presentation/providers/lists_provider.dart';
import 'package:grocer/features/lists/presentation/screens/home_screen.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

void main() {
  testWidgets('HomeScreen shows the empty state when there are no lists',
      (WidgetTester tester) async {
    // ARRANGE: build HomeScreen with the lists stream overridden to emit
    // one value: an empty list. No Isar, no disk, no network.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream.value(const <GroceryList>[]),
          ),
        ],
        // MaterialApp provides theme/navigation that Scaffold needs.
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // ACT: pump() renders a frame. The first frame shows the loading
    // spinner; pumping again lets the stream's value arrive and rebuild.
    await tester.pump();

    // ASSERT: the empty-state message defined in home_screen.dart is shown,
    // and no loading spinner remains.
    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HomeScreen shows a card for each list in the stream',
      (WidgetTester tester) async {
    // A hand-built domain object — note how easy this is BECAUSE
    // GroceryList is a plain Dart class with no database baggage.
    final groceries = GroceryList(
      id: 'test-id-1',
      name: 'Weekly groceries',
      frequency: ScheduleFrequency.weekly,
      scheduledFor: DateTime(2026, 7, 10),
      createdAt: DateTime(2026, 7, 1),
      items: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream.value(<GroceryList>[groceries]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget); // frequency chip label
  });

  // Exercise 1 — third test: what happens when the data stream fails?
  testWidgets('HomeScreen shows an error message when the stream fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream<List<GroceryList>>.error('boom'),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    // home_screen.dart renders: 'Could not load lists: $error'
    expect(find.textContaining('Could not load lists'), findsOneWidget);
  });
}
