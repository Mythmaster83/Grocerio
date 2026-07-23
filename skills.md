# Skills / Conventions

Concrete "how we do things here" for any agent (human or AI) extending this
codebase. If you're about to write code and you're unsure which pattern
applies, this file should answer it before you guess.

## 1. Adding a new feature — the checklist

Use `features/lists/` as the reference implementation for every step below.

1. **Folder**: `lib/features/<feature_name>/{data,domain,presentation}/...`
   matching the existing subfolder names exactly (`data/models`,
   `data/datasources`, `data/repositories`, `domain/entities`,
   `domain/repositories`, `domain/usecases`, `presentation/providers`,
   `presentation/screens`, `presentation/widgets`). Don't invent new
   top-level folder names per feature — consistency is what lets an agent
   navigate a feature it's never seen by pattern-matching to one it has.
2. **Domain first**: write the entity (plain Dart class, `Equatable`) and
   the abstract repository interface before touching Isar. If you can't
   describe the feature's operations as method signatures with no
   Isar/Dio/Flutter types in them, the domain isn't well-formed yet.
3. **Data second**: Isar model with `toDomain()`, a datasource that throws
   `StorageException`/`RemoteDataException`, a repository impl that
   catches those and returns `Result<T>`.
4. **DI file**: one `<feature>_di.dart` in `presentation/providers/`
   exposing plain `Provider`s for datasource -> repository -> usecases
   (see `lists_di.dart`). Don't scatter `Provider((ref) => ...)`
   definitions across multiple files for the same feature.
5. **Presentation**: `StreamProvider`/`FutureProvider` for reads,
   `AsyncNotifier` for writes (see §3 in `architecture.md` for which one
   and why). Widgets consume providers via `ConsumerWidget`/
   `ConsumerStatefulWidget` and contain no business logic — if a widget
   method is more than "call a controller method and handle the boolean/
   Result it returns," that logic belongs in the notifier, not the widget.
6. **Register Isar schema**: if you added an `@collection` class, add its
   `Schema` to `openAppIsar()` in `core/di/isar_provider.dart`. Forgetting
   this fails silently at first write, not at compile time — it's the
   single most common mistake when adding a new persisted type.
7. **Run codegen**: `flutter pub run build_runner build --delete-conflicting-outputs`
   after adding/editing any `@collection`/`@embedded` class.

## 2. Naming conventions

- Domain entities: singular noun, no suffix (`GroceryItem`, not
  `GroceryItemEntity`).
- Isar persistence classes: `<Entity>Model` (`GroceryItemModel`).
- Repository interfaces: `<Feature>Repository` in `domain/repositories/`;
  implementations: `<Feature>RepositoryImpl` in `data/repositories/`.
- Riverpod read providers: `<noun>StreamProvider` /
  `<noun>FutureProvider`. Write/mutation notifiers:
  `<Feature>ActionsController` or `<Feature>Controller` — "Controller" is
  reserved for `AsyncNotifier`/`Notifier` classes, not for anything else,
  so grepping for "Controller" reliably finds every stateful mutation
  point in the app.
- Files: `snake_case.dart` matching the primary class name.

## 3. Error handling — don't reinvent this per feature

- Data layer throws `StorageException` / `RemoteDataException`
  (`core/errors/exceptions.dart`). Don't add a third exception type without
  a specific reason — most failures fit one of these two.
- Repository impls translate to `Result<T>` (`core/utils/result.dart`).
  Every repository method returns `Future<Result<T>>` or a
  `Stream<T>` (streams don't wrap in `Result` — a broken stream is
  handled via `AsyncValue.error` on the consuming `StreamProvider`
  instead).
- `AppFailure.message` must be a complete, user-safe sentence — assume it
  gets rendered directly in a SnackBar or inline error text. Put raw
  exception detail in `cause`, not `message`.
- Validation (empty name, non-positive quantity, etc.) happens in the
  repository impl, before the datasource is called — see
  `ListsRepositoryImpl.addItem` for the pattern. Don't push validation
  into the UI layer as the only line of defense; a widget can be bypassed
  by a future caller (another screen, a test, an agent-written script)
  that the validation logic must still hold against.

## 4. State management do's and don'ts

**Do:**
- One `AsyncNotifier` per feature for mutations (`ListActionsController`,
  `PreferencesController`), covering all write operations for that
  feature.
- `ref.watch()` in `build()` methods for anything the widget should
  rebuild on; `ref.read()` inside callbacks (button `onPressed`, etc.) —
  this is the standard Riverpod rule and this codebase follows it without
  exception. If you write `ref.watch()` inside a callback, that's a bug.
- `.autoDispose` on any provider scoped to a single screen's lifetime
  (list detail stream, for example) so subscriptions are freed on
  navigation away.

**Don't:**
- Don't introduce `setState` for anything that represents domain data.
  `setState` is acceptable *only* for pure local UI state that has no
  representation in the domain layer — e.g. `ItemTile._editing` (whether
  the row is currently showing its edit form) is fine as `setState`
  because "is this row's edit UI open" is not a fact about the grocery
  item, it's a fact about this widget instance.
- Don't call `ref.read(...).state = ...` directly on a notifier from a
  widget to bypass its public methods. If a notifier's public API doesn't
  support what you need, extend the API — don't reach around it.

## 5. Testing expectations

- `test/unit/`: domain and data layer. Repository impls should be tested
  against a fake/mock datasource (use `mocktail`, already a dependency) —
  not against a real Isar instance, so tests run fast and don't leave
  database files behind.
- `test/widget/`: presentation layer, with `ProviderScope(overrides: [...])`
  substituting fake repositories/notifiers — never a real Isar or network
  call in a widget test.
- Priority order if you can only write a few tests before a deadline:
  1. `ListsRepositoryImpl` validation paths (empty name, negative
     quantity) — these are the app's actual data-integrity guarantees.
  2. `ScheduleFrequency.nextOccurrence()` — pure function, easy to get
     wrong on month-boundary edge cases, cheap to verify exhaustively.
  3. `ItemTile` checkbox toggle — this is the specific bug class the prior
     iteration shipped with; a regression test here is disproportionately
     valuable relative to its cost.

## 6. Things that look like a good idea but aren't (learned the hard way,
      encoded here so the lesson isn't re-learned)

- **Don't add a second persistence layer** (e.g. `shared_preferences`
  alongside Isar) for "just one small setting." `PreferencesModel` exists
  precisely so every setting has one home. Two storage engines is two
  places a value can drift, two things to back up, two things to test.
- **Don't let a widget hold a cached copy of domain data** "to avoid
  rebuilding." `ItemTile`'s `didUpdateWidget` pattern (sync local edit
  buffers from the incoming `item` unless actively mid-edit) is the
  narrow, justified exception — it exists to avoid clobbering an in-flight
  edit, not to avoid a rebuild. If you're tempted to cache for performance
  reasons, profile first; Riverpod's granular rebuild scoping usually
  makes this unnecessary.
- **Don't catch-and-swallow in a notifier.** If a repository call fails,
  set `AsyncError` and let the UI show it. A silently-ignored failure
  ("well, it probably worked") is how a user loses data and blames the
  app for a bug that was actually a deliberately hidden error.
- **Don't reach for a new state-management or DI package because a
  tutorial recommended it.** This codebase has one answer for "how do I
  manage state" (Riverpod, per §4) and one answer for "how do I wire
  dependencies" (feature-scoped `Provider`s, per §1.4). Introducing a
  second answer to either question is a maintenance tax on every future
  reader, not a local optimization.
