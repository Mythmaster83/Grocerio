# Learning Worksheet — Fix This App Yourself

You fix the code; this file tells you *where*, *why*, and *how to know you're done*.
Work top to bottom — they're ordered easiest → hardest, and later ones assume
concepts from earlier ones.

**Golden rule while doing these:** never put "how to get/save data" logic
inside a widget. A widget's job is *render state + report user intent*. If you
catch yourself writing `Isar`, `Dio`, or a `try/catch` for a save inside a
widget file, stop — that logic belongs in a controller or repository. This is
the single habit that separates "intern mockup" from "shippable app."

---

## How to run the checks

```bash
flutter pub get        # fetch packages / validate assets
flutter analyze        # static errors + lint warnings (aim: "No issues found!")
flutter test           # run the test suite (aim: all green)
flutter run            # launch on a device/emulator
```

Run `flutter analyze` and `flutter test` after EVERY exercise. Green-to-green is the loop.

---

## ✅ Already fixed for you (read the diffs to learn the pattern)

- **`.env` + `assets/fonts/.gitkeep` created** — the app declared assets that
  didn't exist, so it wouldn't build. Lesson: every path under `flutter: assets:`
  in `pubspec.yaml` must actually exist on disk.
- **`INTERNET` permission added to `android/app/src/main/AndroidManifest.xml`** —
  it was only in the *debug* manifest, so networking worked in `flutter run` but
  would die in a release build.

---

## Exercise 1 — Beginner — Replace the fake test (Error B)

**File:** `test/widget_test.dart`

**What's wrong:** it's the default Flutter template test. It looks for a counter
(`find.text('0')`, taps `Icons.add`) that this app doesn't have, and it builds
`GrocerApp` with no `ProviderScope`, so it crashes on `isarProvider`'s
`throw UnimplementedError`.

**Concept to learn:** in Riverpod, tests replace real dependencies with fakes
using `ProviderScope(overrides: [...])`. You never touch a real database in a
widget test.

**Your task:** delete the counter test and write one that:
1. Overrides `listsStreamProvider` to return a stream of an empty list.
2. Pumps `HomeScreen` inside a `ProviderScope`.
3. Asserts the empty-state text `'No lists yet'` is visible.

**Hints:**
- `StreamProvider` is overridden with `.overrideWith((ref) => Stream.value(<GroceryList>[]))`.
- Wrap in `ProviderScope(overrides: [...], child: const MaterialApp(home: HomeScreen()))`.
- Use `await tester.pumpAndSettle();` then `expect(find.text('No lists yet'), findsOneWidget);`

**Done when:** `flutter test` is green and the test actually exercises `HomeScreen`.

---

## Exercise 2 — Beginner — Stop swallowing errors on the detail screen (Error, weakness #2)

**Files:** `lib/features/lists/presentation/screens/list_detail_screen.dart`
(and read `lib/features/lists/presentation/widgets/item_tile.dart`)

**What's wrong:** when you tick a checkbox, edit an item, or delete one, the code
calls `ListActionsController` but ignores whether it failed. `ListActionsController`
sets an error state (`AsyncError`), but nobody is *listening*, so a failed save is
completely invisible to the user.

**Concept to learn:** `ref.watch` rebuilds a widget when state changes;
`ref.listen` runs a side-effect (like showing a SnackBar) when state changes —
without rebuilding. Errors should be *shown*, never hidden.

**Your task:** in `ListDetailScreen.build`, add a `ref.listen` on
`listActionsControllerProvider` that, when the state becomes an error, shows a
`SnackBar` with the failure's user-facing message.

**Hints:**
- The controller's type is `AsyncValue<void>`; check `next.hasError`.
- The error object is your `AppFailure` — read its `.message` (already a
  user-safe sentence by design — see `result.dart`).
- Pattern:
  ```dart
  ref.listen(listActionsControllerProvider, (prev, next) {
    if (next.hasError) {
      final failure = next.error;
      // show a SnackBar with the message
    }
  });
  ```

**Done when:** forcing an error (temporarily `throw` inside the datasource's
`updateItem`) makes a SnackBar appear instead of nothing.

---

## Exercise 3 — Intermediate — Make voice input actually work (Error D)

**Files:** `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`,
`lib/features/voice_input/presentation/providers/voice_input_controller.dart`

**What's wrong:** the mic button exists, but Android has no `RECORD_AUDIO`
permission and iOS has no usage-description strings, so `speech_to_text` can't
start. Also `VoiceInputStatus.denied` is defined but never actually set.

**Concept to learn:** native features (mic, camera, location) require *platform*
permission declarations in addition to Dart code. The OS blocks the API otherwise.

**Your task:**
1. Add to the Android main manifest: `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`.
2. Add to `ios/Runner/Info.plist`: `NSMicrophoneUsageDescription` and
   `NSSpeechRecognitionUsageDescription` keys with a short human explanation.
3. In `startListening`, detect the permission-denied case and set
   `state = state.copyWith(status: VoiceInputStatus.denied);` so the existing
   SnackBar in `voice_input_button.dart` fires.

**Hints:**
- `speech_to_text`'s `initialize` has `onError`/`onStatus`; a denied permission
  typically surfaces as an error status. Inspect what `errorMsg` you get and branch on it.

**Done when (Android/iOS):** first launch prompts for mic permission; denying it shows the
"Microphone permission was denied." SnackBar.

**Done when (Windows):** see Exercise 3B below — mobile-style permission prompts do not
appear on Windows.

---

## Exercise 3B — Intermediate — Windows microphone UX (no in-app permission prompt)

**Files:** `lib/features/voice_input/presentation/providers/voice_input_controller.dart`,
`lib/features/voice_input/presentation/widgets/voice_input_button.dart`

**What's wrong:** on Windows there is **no** OS popup like Android/iOS when you tap the
mic. The `speech_to_text_windows` plugin's `hasPermission` always returns `true` without
checking anything — mic access is controlled globally in **Windows Settings → Privacy &
security → Microphone**. If the user (or Windows) has blocked desktop apps from the mic,
your app silently fails or shows a generic error with no guidance.

**Concept to learn:** the same feature can behave differently per platform. "Permission
handling" on desktop often means **detecting failure + telling the user where to fix it
in OS settings**, not waiting for a dialog your app can trigger.

**Your task:**
1. Import `dart:io` and use `Platform.isWindows` (guard with `kIsWeb` check if needed).
2. In `startListening`, when `initialize` returns `false` **or** `listen` fails on
   Windows, set a distinct outcome the UI can react to — either reuse
   `VoiceInputStatus.unavailable` or add a new status like `blockedByOS` if you want to
   be precise.
3. In `voice_input_button.dart`, when that status fires on Windows, show a SnackBar that
   tells the user exactly what to do, e.g. *"Microphone blocked. Open Windows Settings →
   Privacy & security → Microphone, and allow desktop apps to access your microphone."*

**Hints:**
- You will **not** get a permission prompt to test "deny" on Windows — test by going to
  Windows Settings and turning off microphone access for desktop apps, then tapping mic.
- `initialize` returning `false` on Windows often means SAPI couldn't open the audio
  device (blocked mic, no mic hardware, etc.) — check the debug console for HRESULT logs.
- Do **not** expect `hasPermission` to save you on Windows; the plugin hardcodes it to
  `true`. Your detection has to rely on `initialize` / `listen` failing instead.

**Done when:** with Windows mic access disabled in Settings, tapping the mic shows a
clear, actionable SnackBar (not silence, not a raw error string).

---

## Exercise 4 — Intermediate — Fix a real date bug + write its first unit test (Error H)

**File:** `lib/features/scheduling/domain/entities/schedule_frequency.dart`
**New file:** `test/unit/schedule_frequency_test.dart`

**What's wrong:** the monthly case is `DateTime(from.year, from.month + 1, from.day)`.
For **Jan 31**, that asks for "Feb 31," which Dart rolls forward to **Mar 2/3**.
`skills.md` §5 literally lists this as a top test priority — and it's still broken.

**Concept to learn:** pure functions (no I/O, same input → same output) are the
cheapest things to test and the easiest place to hide edge-case bugs. Month/day
math is a classic trap.

**Your task:**
1. First, write a *failing* test: `weekly` adds 7 days; `monthly` from `2024-01-31`
   should land on a valid last-day-of-February, not spill into March.
2. Then fix `nextOccurrence` so it clamps the day to the target month's last day.

**Hints:**
- Last day of a month `m`/`y` in Dart: `DateTime(y, m + 1, 0).day` (day 0 of next
  month = last day of this month).
- `oneTime` should still return `null`.

**Done when:** your test is green and covers the Jan-31 case explicitly.

---

## Exercise 5 — ADVANCED (the big one) — Make `preferences` obey the architecture (Error F, weakness #1)

**Files:** everything under `lib/features/preferences/`  
**Reference:** copy the *shape* of `lib/features/lists/` — not the CRUD methods.

**What's wrong:** controller talks to Isar directly; domain imports Flutter; save
failures are silent.

**Concept:** layering — presentation → domain → data. Preferences only needs
`load` + `save` (one row), not lists' create/delete/watch API.

**Do not copy `ListsLocalDataSource` as-is** — no UUID, no streams, no multi-row CRUD.

---

### Phase A — Datasource ✅ (pattern)

**File:** `data/datasources/preferences_local_datasource.dart`

- Constructor: `PreferencesLocalDataSource(this._isar)` — no `Uuid`
- `Future<PreferencesModel> load()` — `get(0)`, if null put `defaults()`, return model
- `Future<void> save(PreferencesModel model)` — set `isarId = 0`, `writeTxn` → `put`
- try/catch → `throw StorageException(...)`
- Return **models**, not `AppPreferences` / `Result`

---

### Phase B — Repository impl

**File:** `data/repositories/preferences_repository_impl.dart`  
**Implements:** `PreferencesRepository` (`load` / `save` returning `Result`)

**Job:** sit between domain and datasource.

| Datasource gives/takes | Repository gives/takes |
|---|---|
| `PreferencesModel` | `AppPreferences` |
| throws `StorageException` | returns `Result.ok` / `Result.err` |

**Skeleton (fill it — mirror `ListsRepositoryImpl`):**

```dart
class PreferencesRepositoryImpl implements PreferencesRepository {
  final PreferencesLocalDataSource _local;
  PreferencesRepositoryImpl(this._local);

  @override
  Future<Result<AppPreferences>> load() async {
    try {
      final model = await _local.load();
      return Result.ok(_toDomain(model));
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load preferences.', cause: e));
    }
  }

  @override
  Future<Result<void>> save(AppPreferences prefs) async {
    try {
      await _local.save(_fromDomain(prefs));
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not save preferences.', cause: e));
    }
  }

  AppPreferences _toDomain(PreferencesModel m) { /* move from controller */ }
  PreferencesModel _fromDomain(AppPreferences p) { /* build model, isarId = 0 */ }
}
```

**Mapping helpers (temporary until Phase E):** move `_toDomain` out of the
controller into the repo. Add `_fromDomain` that builds `PreferencesModel` from
`AppPreferences` (theme index, `accentColor.toARGB32()`, etc.) — same fields the
controller currently writes by hand.

**Imports you'll need:** exceptions, result, logger, datasource, model, domain
entity, `PreferencesRepository`, and (for now) `flutter/material.dart` for
`ThemeMode`/`Color` conversion.

**Done when:** class `implements PreferencesRepository`, both methods return
`Result`, analyze clean on that file.

---

### Phase C — DI

**File:** `presentation/providers/preferences_di.dart`

Copy *shape* of `lists_di.dart` / `images_di.dart`:

```dart
// imports: flutter_riverpod, isar_provider, datasource, repository interface + impl

final preferencesLocalDataSourceProvider = Provider<PreferencesLocalDataSource>((ref) {
  return PreferencesLocalDataSource(ref.watch(isarProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepositoryImpl(ref.watch(preferencesLocalDataSourceProvider));
});
```

**Done when:** analyze clean; no missing imports (`Provider`, datasource, etc.).

---

### Phase D — Rewrite controller

**File:** `presentation/providers/preferences_controller.dart`

- Remove `Isar`, `isarProvider`, `PreferencesModel` imports
- `build()`: `final result = await ref.read(preferencesRepositoryProvider).load();`
  then `result.when(ok: (p) => p, err: (f) => throw f)` (or equivalent)
- `updatePrefs`: keep optimistic `AsyncData(updated)`, then
  `await repo.save(updated)`; on `err` set `state = AsyncError(...)`
- Delete `_toDomain` from controller (lives in repo now)

**Done when:** controller has zero Isar imports; settings still load/save via repo.

---

### Phase E — Clean domain (hardest)

**File:** `domain/entities/app_preferences.dart`

Replace Flutter types with primitives:

- `int themeModeIndex` instead of `ThemeMode`
- `int accentColorValue` instead of `Color`
- keep `fontFamily`, `textScale`, `pageOrder` (or `List<int>` for page order)

Then convert **only in presentation**:

- `app.dart` — `ThemeMode.values[prefs.themeModeIndex]`, `Color(prefs.accentColorValue)`
- `settings_screen.dart` — same when reading/writing UI controls
- Update `_toDomain` / `_fromDomain` in the repo (no Flutter in domain; mapping
  may stay in repo *or* move helpers next to UI — either way domain stays pure)

**Done when:** nothing under `preferences/domain/` imports `package:flutter` or
`package:isar`.

---

### Phase F — Surface save errors

**File:** `settings_screen.dart`

Same idea as Exercise 2:

```dart
ref.listen(preferencesControllerProvider, (prev, next) {
  if (next.hasError) { /* SnackBar with message */ }
});
```

**Done when:** a forced save failure shows a SnackBar (not silence).

---

### Exercise 5 checklist

| Phase | Deliverable |
|---|---|
| A | Datasource `load`/`save` + `StorageException` |
| B | `PreferencesRepositoryImpl` + mapping + `Result` |
| C | `preferences_di.dart` |
| D | Controller uses repo only |
| E | Domain has no Flutter types |
| F | Settings shows save errors |

**Verify:** `flutter analyze` clean; change theme/slider in Settings; restart app —
prefs persist.

---

## Exercise 6 — ADVANCED — Wire the images feature end-to-end (Error E)

**Files:** create `lib/features/images/presentation/providers/images_di.dart`;
edit `add_item_modal.dart`, the domain/data `addItem` path, and `item_tile.dart`.

**What's wrong:** `ImageRepository`, `PexelsRemoteDataSource`, `ApiClient`, and
`NetworkImageWithFallback` all exist but are **never connected**. Items have an
`imageUrl` field that's never filled in and never displayed. `goals.md` marks
this "done" — it isn't.

**Concept to learn:** a feature isn't "done" because the pieces exist — it's done
when data flows end-to-end: UI → controller → repository → API → back to UI.

**Your task (in stages, test after each):**
1. `images_di.dart`: providers for `ApiClient` → `PexelsRemoteDataSource` →
   `ImageRepositoryImpl` (copy `lists_di.dart`'s style).
2. In the add-item flow, after the user types a name, call
   `imageRepository.search(name)` and take the first result's `thumbnailUrl`.
3. Thread `imageUrl` through: `addItem` (controller → repository → datasource →
   `GroceryItemModel`). You'll add an `imageUrl` parameter along that chain.
4. In `item_tile.dart`'s display row, render
   `NetworkImageWithFallback(imageUrl: item.imageUrl)` at the start of the row.

**Done when:** adding "banana" shows a banana thumbnail; adding "" or with no
network shows the fallback icon, never a broken image or infinite spinner.

---

## Exercise 7 — Chore — Clear the deprecation warnings (Error G)

**Files:** `preferences_controller.dart`, `settings_screen.dart` (search for `.value`)

**What's wrong:** `Color.value` is deprecated in current Flutter.

**Concept to learn:** `flutter analyze` clean is a shipping bar (`goals.md` says so).
Deprecations are tomorrow's breakages; clear them early.

**Your task:** replace deprecated `Color.value` usage per the analyzer's suggested
fix (e.g. `.toARGB32()` for storing an int, and compare colors by identity/value
using the non-deprecated API). Run `flutter analyze` and resolve every warning it
prints for these files.

**Done when:** `flutter analyze` reports no deprecation warnings in these files.

---

## Suggested order & difficulty

| # | Exercise | Difficulty | Teaches |
|---|----------|-----------|---------|
| 1 | Real widget test | ⭐ | Testing + provider overrides |
| 2 | Surface errors | ⭐ | `ref.listen`, AsyncValue, UX honesty |
| 7 | Deprecations | ⭐ | Reading the analyzer |
| 3 | Voice permissions (Android/iOS) | ⭐⭐ | Native platform config |
| 3B | Windows mic UX (no prompt) | ⭐⭐ | Platform differences, failure messaging |
| 4 | Date bug + unit test | ⭐⭐ | Pure functions, edge cases |
| 6 | Wire images | ⭐⭐⭐ | End-to-end data flow, DI |
| 5 | Preferences refactor | ⭐⭐⭐ | **Layering / separation of concerns** |

Do #5 last — once it clicks, you'll understand why the whole app is shaped the way it is.
