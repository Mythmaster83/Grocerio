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
      order (data model + persistence done; **layered** like `lists/` —
      repository + DI + pure-Dart domain ints; drag-to-reorder UI for page
      order is still a stub — `pageOrder` persists but Home does not reorder).
- [x] Fixed-height, text-scale-respecting layouts.
- [x] Add Item / Voice Input buttons and modals.
- [x] **Complete Shopping** — uncheck all, pop Home, advance recurring or
      delete one-time (`ROADMAP.md` Feature A).
- [x] Real-time updates: writes stream to UI with no manual refresh.
- [x] Local storage via Isar.
- [x] API images (Pexels) with fallback icons — wired end-to-end on add item.
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

## 3b. Now in scope — next increment (`ROADMAP.md`)

These were deferred; product decisions are now locked in `ROADMAP.md`:

- [x] **Complete Shopping** — uncheck all, pop Home, advance recurring date
      or delete one-time list.
- [x] **Startup schedule reconciliation** — on app open, roll overdue
      recurring dates forward, flag missed one-time lists without deleting,
      show a uniform "Last date missed" indicator.

See `ROADMAP.md` for locked rules and file map.

## 4. Known limitations (status)

| Limitation | Status |
|---|---|
| Push notifications | Not started (see §3) |
| Item suggestion dropdown | Not started (see §3) |
| Automatic list date updates | **Done** — startup reconcile + `lastMissedOn` (`ROADMAP.md`) |
| Complete Shopping real behavior | **Done** — usecase + one-txn finalize / delete |
| Voice input minor quirks | Contained — transcript editable before commit |
| Image source "view photographer" deep link | Unbuilt; fallback widget is fine |
| Checkbox drift | Structurally addressed; covered by list stream + controller path |
| Monthly date edge cases beyond Jan | **Hardened** — clamp + tests (Mar/May/Aug/Dec, leap) |

## 5. Definition of foundation-complete

This foundation is complete when an agent can:

1. Add a genuinely new feature by copying the `lists/` (or `preferences/`)
   folder structure, without needing to ask what pattern to follow.
2. Run `flutter analyze` clean and `flutter test` green.
3. Hand the repo to another engineer with `skills.md`, `architecture.md`,
   and `ROADMAP.md` as onboarding material.

Learning exercises in `EXERCISES.md` are complete. Complete Shopping and
schedule reconciliation are shipped per `ROADMAP.md`.
