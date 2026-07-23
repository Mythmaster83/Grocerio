# Goals

Written for an agent (human or AI) picking up this repo cold. Scope
discipline is the point of this document — most MVP failures are scope
failures, not technical ones.

## 1. What "done" means for this MVP

A feature is done when it satisfies **all** of:

1. Domain entity + repository interface exist in `domain/`, with zero
   Flutter/Isar imports.
2. Data implementation exists in `data/`, throws `*Exception` internally,
   never lets one escape past the repository impl untranslated to `Result`.
3. Presentation reads via a `StreamProvider`/`FutureProvider` and writes
   via an `AsyncNotifier` — no direct Isar/Dio calls from a widget, ever.
4. User-facing errors are readable sentences, not exception `toString()`.
5. Destructive actions are behind `showConfirmDialog`.
6. It respects text-scale (no hardcoded pixel heights that clip at 1.4x).

If a PR/change can't check all six boxes, it's not done — it's in progress,
and should say so.

## 2. In-scope for this MVP (from the product brief)

- [x] Create/view/delete grocery or stock lists from Home.
- [x] Item CRUD: inline edit (quantity/unit), swipe-to-edit, delete with
      confirmation.
- [x] Voice input for adding items (editable transcript — see known
      limitation below, this is by design not a bug).
- [x] Scheduling: one-time / weekly / biweekly / monthly, with a
      scheduled date shown per list.
- [x] Preferences: theme mode, accent color, font, text size, home page
      order (data model + persistence done; drag-to-reorder UI for page
      order is a stub — the `AppPreferences.pageOrder` list exists and
      persists, wiring it into an actual reorderable home layout is the
      next increment).
- [x] Fixed-height, text-scale-respecting layouts.
- [x] Add Item / Complete Shopping / Voice Input buttons and modals.
- [x] Real-time updates: writes stream to UI with no manual refresh.
- [x] Local storage via Isar.
- [x] API images (Pexels) with fallback icons.
- [x] API keys kept out of source control via `.gitignore` + `.env`.

## 3. Explicitly out of scope for this MVP (do not build without a
      deliberate scope-change decision, not a "while I'm in here")

- **Push notifications.** Requires a scheduling/permissions story
  (`flutter_local_notifications` + platform permission prompts + a
  decision about whether reminders fire even when the app is killed).
  Non-trivial enough that bolting it on inside an unrelated feature PR is
  how scope creep happens. Build it as its own feature module when
  prioritized.
- **Item suggestion dropdown** (autocomplete while typing an item name).
  Needs a curated or learned suggestion source — trivial to build a bad
  version (static list), not trivial to build a good one. Deferred rather
  than shipped half-working.
- **Automatic list date rollover** (a "weekly" list silently advancing its
  `scheduledFor` after the date passes). This is a real feature, not a bug
  fix — `ScheduleFrequency.nextOccurrence()` already computes the *next*
  date as a pure function; wiring it to actually roll the list forward
  (and deciding whether that resets checked items) is a product decision,
  not just an engineering one. Don't silently implement a guess.
- **Backend proxy for the Pexels API key.** See `architecture.md` §5.1.
  Not needed at current scope (no user accounts, no privileged API), but
  it's the correct next step the moment either of those changes — flagged
  here so it isn't rediscovered the hard way after a key gets scraped from
  a shipped APK.
- **Multi-device / shared-list sync.** Isar is local-only by design in
  this foundation. This is the single largest architectural wall in the
  codebase — see `architecture.md` §7. If "share a list with my partner"
  becomes a requirement, that's a new project phase (remote source of
  truth + conflict resolution), not an incremental feature.
- **Certificate pinning.** Deferred until there's a stable backend host to
  pin against.

## 4. Known limitations carried over from the prior iteration (status)

| Limitation | Status in this foundation |
|---|---|
| Push notifications | Not started (see §3) |
| Item suggestion dropdown | Not started (see §3) |
| Automatic list date updates | Pure-function building block exists (`ScheduleFrequency.nextOccurrence`); rollover behavior not wired |
| Voice input minor quirks | Structurally contained, not eliminated — transcript is always editable before commit, never auto-saved |
| Redirect to image sources not working | Fixed at the widget level — `NetworkImageWithFallback` never leaves a broken/hanging state; if "view full image source" is a separate feature (not just avoiding a broken UI), that's still unbuilt |
| Checkbox bugs | Structurally addressed — single write path, no local mirrored state (see `architecture.md` §1) — but this claim should be verified with the widget tests in `test/widget/` before being trusted, not taken on faith |

## 5. Definition of MVP-complete (the whole app, beyond this foundation)

This foundation is complete when an agent can:

1. Add a genuinely new feature (e.g. "shopping budget tracking") by
   copying the `lists/` folder structure, without needing to ask what
   pattern to follow.
2. Run `flutter analyze` clean and `flutter test` green.
3. Hand the repo to another engineer with only `skills.md` and
   `architecture.md` as onboarding material.

The product itself (all checkboxes in §2, tested end-to-end on a device)
is the next phase, not this deliverable.
