# Architecture

This document is the contract. If a change violates something here, either
the change is wrong or this document is stale — update one of them, don't
let them silently diverge.

## 1. Layering (non-negotiable)

```
presentation  ->  domain  ->  data
   (Flutter,        (pure         (Isar,
   Riverpod)        Dart)      local notifs)
```

The app is **local-first**. Lists live in Isar and the UI never waits on the
network. When a build is given Supabase credentials, an optional account
enables list sharing and community prices. Without credentials, every
network path is skipped and the app behaves as a fully offline client.

Dependency direction is one-way. Concretely:

- `domain/entities/*` and `domain/repositories/*.dart` (the abstract
  interface) import **nothing** from `data/` or `presentation/`, and
  nothing from `package:flutter` or `package:isar_community`. If you find yourself
  importing Isar into a domain file, the abstraction has leaked — stop and
  fix the interface instead of patching around it.
- `data/` implements the domain interfaces and owns all I/O. Isar models
  (`GroceryListModel`, `GroceryItemModel`, `PreferencesModel`) are
  **persistence shapes**, not domain objects — they have `toDomain()`
  methods and nothing calls into them from outside `data/`.
- `presentation/` depends on `domain/` interfaces via Riverpod providers,
  never on `data/` implementations directly (the DI files are the only
  place that wires interface -> implementation).

**Why this matters more than it looks like it does:** the original
brief's stated limitation — "checkbox bugs" — is a direct symptom of state
living in multiple places that can drift out of sync (a StatefulWidget's
local `bool checked` plus whatever the storage layer thinks is true). This
layering makes that class of bug structurally harder to write: there is
exactly one path from "user taps checkbox" to "persisted state" to
"every subscriber re-renders" (`ItemTile` -> `ListActionsController.updateItem`
-> `ListsRepository.updateItem` -> Isar write -> `watch()` stream -> every
`ref.watch(listsStreamProvider)` consumer). No local mirror state to drift.

## 2. State management: Riverpod, two provider shapes

Two distinct provider patterns are used on purpose, mapped to two distinct
access patterns — don't blur them:

| Pattern | Used for | Why |
|---|---|---|
| `StreamProvider` (`.autoDispose`, `.family` where scoped) | Reading live data (lists, list detail) | Real-time updates are a named requirement. Isar's native `.watch()` composes directly into a Dart `Stream` — no polling, no manual "refresh" button, no cache-invalidation logic to get wrong. |
| `AsyncNotifier` | Writing / mutating (`ListActionsController`, `PreferencesController`) | Mutations need a submission-state (idle/loading/error) that a button or modal can react to — a `Future<void>` per call site can't hold that in a widget-tree-friendly way. `AsyncNotifier`'s `state` naturally models "idle / in-flight / failed". |

**Explicit non-pattern:** do not add a third state-management style (Bloc,
GetX, plain `ChangeNotifier`) to "just this one feature." Consistency here
is a force multiplier for every future agent reading this codebase; a
second pattern is a tax paid by everyone after you.

## 3. Error handling: `Result<T>`, not exceptions, above the data layer

- `data/datasources/*` throw (`StorageException`, `RemoteDataException`) —
  exceptions are fine and idiomatic *inside* the data layer, close to the
  I/O that produces them.
- `data/repositories/*_impl.dart` catch those exceptions and translate to
  `Result<T>` (`core/utils/result.dart`) — this is the one mandatory
  translation boundary in the whole app.
- Everything above (`domain/usecases`, `presentation/providers`, widgets)
  only ever sees `Result<T>`. No `try/catch` should exist in a widget or a
  Riverpod notifier for a repository call — `result.when(ok:, err:)` is the
  only vocabulary needed.

**Failure mode this prevents:** exceptions crossing layer boundaries
un-translated is how you end up with a raw `IsarError` message rendered in
a SnackBar, or a silently swallowed write that the user thinks succeeded.
`Result<T>` makes "did this succeed" a value you're forced to branch on at
the call site, not an assumption.

## 4. Storage: Isar, single instance, embedded items

- Dart API + generator + native libs: **`isar_community` 3.3.2** (all three
  packages pinned to the same version). Mixing classic `isar` 3.1.x with
  community native 3.3.x crashes at startup (`Required 3.1.0+1 found 3.3.2`).
  Community `libisar.so` is **16 KB page-size aligned** for modern Android / Play.
- One `Isar` instance for the whole app, opened once in `main()` and
  injected via `isarProvider.overrideWithValue(isar)` — every datasource
  reads it through DI, never opens its own handle. This is what makes the
  whole storage layer swappable/testable: override `isarProvider` with an
  in-memory Isar instance in tests and every repository, datasource, and
  notifier above it works unmodified.
- `GroceryItemModel` is `@embedded` inside `GroceryListModel.items`, not a
  separate `@collection` linked via `IsarLink`. Items have no independent
  lifecycle outside their parent list, and embedding makes "add an item"
  a single-document write — which is also a single point in the watch
  stream, avoiding the two-collection sync bugs that partial/linked writes
  are prone to.
- `PreferencesModel` is a deliberate single-row collection (`isarId` pinned
  to `0`). This is *not* the general pattern — it's a narrow exception for
  a genuinely singleton concept. Don't copy this pattern for anything that
  could ever have more than one instance.

## 5. Security posture (read before touching `core/security/`)

### 5.1 Backend credentials are compile-time, not bundled files

`SupabaseConfig` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from
`--dart-define`. The publishable (anon) key is not a secret — row-level
security is. An unconfigured build has empty strings and never opens a
socket. The service-role key must never appear in the client.

If a second remote call is ever added (retailer API, etc.), put *that*
credential behind a server — do not bundle it as a Flutter asset.

### 5.2 Input handling

`core/security/input_sanitizer.dart` is the single choke point for
user-typed text that gets persisted. Isar being NoSQL/typed removes classic
injection risk, but unbounded length and control characters are still real
problems (storage bloat, layout breakage, DoS-by-paste). Every repository
method that accepts free text runs it through this before it touches Isar.

### 5.3 Sessions

`supabase_flutter` stores the session. There is still no separate
Keychain wrapper in the app; treat a future custom token the same way.

## 6. UI layer conventions

- **One dark theme, tokens only.** `core/theme/tokens.dart` owns every surface
  color, border, radius, and spacing step; `core/theme/app_theme.dart` maps
  them onto a single dark `ThemeData`. Light mode and the accent-color picker
  were removed: the pricing UI depends on a fixed accent for the cheapest-price
  tint, which a user-chosen seed color cannot guarantee. Font family and text
  scale stay configurable. Do not introduce `Color(0x...)` literals in widgets
  — if a shade is missing, add it to `tokens.dart`.
- **Single page.** `HomeScreen` is the app's only destination: AppBar
  (hamburger → `AppDrawer`) → next-scheduled-date banner → All/Solo/Shared
  chips (when signed in) → sectioned list cards (Overdue / This week /
  Later). Settings, tracked stores, price lookup, notifications, and
  account live in the drawer. Each card's 3-dot menu edits name + date +
  frequency or deletes. List detail has the same menu plus **Share with
  people** (live membership) and **Copy as text**.
- **Units are an append-only enum plus one free-text escape hatch.**
  `ItemUnit` indices are persisted by Isar, so new units go on the **end**
  of both `ItemUnit` and `ItemUnitDb`. `ItemUnit.custom` carries its label in
  `GroceryItem.customUnit`; typed labels are remembered in
  `AppPreferences.customUnits` so the picker offers them again. Switching an
  item back to a built-in unit clears the stale custom label in the
  datasource — the one place that can enforce it for every write path.
- **Fixed-height, text-scale-aware widgets**: `core/widgets/fixed_height_tile.dart`
  scales its minimum height with the ambient `MediaQuery` text scale factor
  instead of hardcoding pixels — the latter is exactly what breaks (clips
  or overflows) once a user increases system text size, which is a named
  requirement, not an edge case to defer.
- **Item icons are local and derived, never fetched.**
  `features/item_icons/` maps an item name to an `ItemIconKind` (pure Dart
  keyword rules, unit-tested) and the presentation layer maps that kind to a
  bundled Fluent Emoji SVG (MIT) via `iconify_flutter`. No HTTP request, no
  API key, no attribution link, no rate limit, and identical behaviour
  offline — which also means no broken-image or infinite-spinner states to
  design around. Nothing image-related is persisted on `GroceryItem`.
  Keyword matching is substring-based, so **rule order in
  `item_icon_kind.dart` is behaviour** ("toilet" must outrank "oil").
- **Swipe-to-edit** uses `flutter_slidable`, not a hand-rolled
  `GestureDetector` + `AnimationController`. The prior generation of this
  app almost certainly hand-rolled swipe gestures — that's a common source
  of jank and platform-inconsistency bugs (iOS vs. Android swipe physics
  differ) that a maintained package already solved.
- **One confirmation dialog** (`core/widgets/confirm_dialog.dart`) backs
  every destructive action. Don't write a second `AlertDialog` for this —
  consistency here is what "deletion with confirmation" as a *product*
  requirement (not just a per-screen implementation detail) actually means.

## 7. Scalability evaluation — where this foundation bends vs. breaks

| Growth vector | Bends fine up to... | Breaks at... | Mitigation when you get there |
|---|---|---|---|
| Items per list | Low thousands (Isar embedded list is fine at this scale) | Lists with 10k+ items rendered naively | Paginate `ListView.builder` is already lazy; the actual ceiling is the embedded-document write cost on every mutation — if this becomes real, promote items to a linked collection with an index on `listId` |
| Number of lists | Thousands, trivially | N/A at any realistic personal/small-business scale | — |
| Concurrent multi-device sync | Local-first pull-then-push, last-write-wins per row, tombstones | Simultaneous edits of the same field on two devices | Logged overwrites; do not introduce a second conflict policy without replacing `list_merge.dart` |
| Voice recognition accuracy | Adequate for short, common grocery nouns | Compound/uncommon items, non-English locales | Documented as a known limitation by design (editable transcript, not auto-commit) — see `voice_input_controller.dart` |
| Flutter web | **Unsupported** — Isar schema IDs are 64-bit ints JS cannot represent exactly | `flutter run -d chrome` | Ship Android/iOS; use Windows only for desktop smoke tests |

## 8. Explicitly deferred vs shipped

**Still deferred** (see `goals.md` §3): remote FCM/APNs, certificate pinning.

**Shipped:** Complete Shopping + schedule reconciliation; autocomplete;
local notifications; single-page UI with drawer; bundled offline item
icons; catalog + user-reported prices; optional Supabase accounts, list
sync, sharing, and ZIP-scoped community prices; store draft + ship
checklist; `com.grocerio.app` + release signing + Grocerio branding/icons.

Do not re-defer shipped items without updating `goals.md` together.
