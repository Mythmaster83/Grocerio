# Architecture

This document is the contract. If a change violates something here, either
the change is wrong or this document is stale — update one of them, don't
let them silently diverge.

## 1. Layering (non-negotiable)

```
presentation  ->  domain  ->  data
   (Flutter,        (pure       (Isar, Dio,
   Riverpod)        Dart)       Pexels API)
```

Dependency direction is one-way. Concretely:

- `domain/entities/*` and `domain/repositories/*.dart` (the abstract
  interface) import **nothing** from `data/` or `presentation/`, and
  nothing from `package:flutter` or `package:isar`. If you find yourself
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

## 5. Security posture (read before touching `core/security/` or `core/config/`)

### 5.1 Known, accepted risk: client-embedded Pexels API key

`EnvConfig` loads `PEXELS_API_KEY` from a bundled `.env` asset.
`.gitignore` keeps the real key out of source control, but **it does not
protect the compiled binary** — anyone can unzip a release APK/IPA and
read bundled assets, extracting the key. This is a deliberate, documented
MVP-level tradeoff for a low-privilege, rate-limited, read-only image
search key. It is explicitly **not** an acceptable pattern to extend to:

- authentication tokens
- payment/billing credentials
- any key with write access or a cost basis you don't control

**Leverage point:** the moment this app adds anything in that second
category, the fix is a thin backend proxy (even a single serverless
function) that holds the real secret and the client calls *that* instead —
not "encrypt the key harder" or "obfuscate it," both of which are
theater against a determined attacker with a decompiler. Track this as a
pre-launch blocker if user accounts, payments, or any privileged API is
ever added; it is not a blocker for the current MVP scope.

### 5.2 Fail-fast configuration

`EnvConfig.load()` throws if `PEXELS_API_KEY` is missing or still the
placeholder value. `main.dart` currently catches that and boots anyway
(logged, not fatal) so a missing dev key doesn't block work on unrelated
features — **flip this to let it propagate before any release build.**
A silently-half-configured production build is worse than a build that
refuses to start.

### 5.3 Input handling

`core/security/input_sanitizer.dart` is the single choke point for
user-typed text that crosses a trust boundary (persisted, or used to build
a URL query param). Isar being NoSQL/typed removes classic injection risk,
but unbounded length and control characters are still real problems
(storage bloat, layout breakage, DoS-by-paste). Every repository method
that accepts free text runs it through this before it touches Isar.

### 5.4 Secure storage vs. env config — don't conflate them

`SecureStorageService` (Keychain/EncryptedSharedPreferences) is for
**runtime secrets created during app use** — auth tokens, refresh tokens —
none of which exist yet in this MVP. It is scaffolded now because adding
user accounts later should not require inventing a secure-storage strategy
under deadline pressure. It is not where the Pexels key belongs (that's a
compile-time app secret, not a per-user runtime one).

### 5.5 Network layer

`ApiClient` centralizes timeouts (8s connect/receive/send — chosen to fail
visibly rather than hang the "Add Item" modal indefinitely) and maps every
`DioException` to a typed `AppFailure` so raw HTTP/parsing errors never
reach the UI. Certificate pinning is **not** implemented — flagged as a
pre-launch item once a stable backend host exists; pinning against
Pexels' own infrastructure directly is not something you control and not
worth doing.

## 6. UI layer conventions

- **Fixed-height, text-scale-aware widgets**: `core/widgets/fixed_height_tile.dart`
  scales its minimum height with the ambient `MediaQuery` text scale factor
  instead of hardcoding pixels — the latter is exactly what breaks (clips
  or overflows) once a user increases system text size, which is a named
  requirement, not an edge case to defer.
- **Every remote image goes through `NetworkImageWithFallback`** — no bare
  `Image.network` anywhere in the codebase. This is both the "fallback
  icons" requirement and the fix for the prior app's broken image-source
  redirects: a failed load renders an icon, not a broken-image glyph or an
  indefinite spinner.
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
| Concurrent multi-device sync | **Not supported at all** — Isar is local-only | Immediately, if "shared household list" is ever a requirement | This is the single biggest scope wall in the current architecture. Adding sync means introducing a remote source of truth and conflict resolution — not a small add-on. Decide explicitly, don't back into it. |
| Voice recognition accuracy | Adequate for short, common grocery nouns | Compound/uncommon items, non-English locales | Documented as a known limitation by design (editable transcript, not auto-commit) — see `voice_input_controller.dart` |

## 8. Explicitly deferred vs next increment

**Still deferred** (see `goals.md` §3): push notifications, item suggestion
dropdown, full offline-first sync, certificate pinning, backend API-key proxy.

**Shipped this increment** (record: `ROADMAP.md`): Complete Shopping and
startup schedule reconciliation (`lastMissedOn`, shared miss UI, pure plans
in `schedule_rules.dart`). Monthly `nextOccurrence` clamps to month-end.

Do not re-defer those as "out of scope" without updating `goals.md` and
`ROADMAP.md` together.
