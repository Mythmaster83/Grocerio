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
      scheduled date shown per list (Home list order = `scheduledFor`).
- [x] Preferences: theme mode, accent color, font, text size, home page
      order (**AppShell**: Lists + Settings; Settings drag-reorder).
- [x] Fixed-height, text-scale-respecting layouts.
- [x] Add Item / Voice Input buttons and modals.
- [x] **Complete Shopping** — uncheck all, pop Home, advance recurring or
      delete one-time (`ROADMAP.md` Feature A).
- [x] Real-time updates: writes stream to UI with no manual refresh.
- [x] Local storage via Isar (community native libs for 16 KB page size).
- [x] API images (Pexels via proxy or direct) with fallback icons.
- [x] Secrets kept out of source control (`.gitignore` + `.env` + Wrangler
      secret for the proxy).

## 3. Explicitly out of scope for this MVP (do not build without a
      deliberate scope-change decision — see `BACKEND_NEXT.md`)

- **Remote push (FCM/APNs).** Local reminders are in scope; server push is not.
- **Multi-device / shared-list sync.** Isar is local-only — see
  `architecture.md` §7 and `BACKEND_NEXT.md`.
- **Certificate pinning.** Defer until pinning the stable proxy host.

## 3b. Shipped increments

- [x] **Complete Shopping** + **startup schedule reconciliation**.
- [x] **Local polish**: photographer attribution, local autocomplete,
      local notifications. `STORE_LISTING.md` / `SHIP_CHECKLIST.md`.
- [x] **AppShell**: Lists + Settings (Schedule tab removed — duplicate of
      Home sort order).
- [x] **Image proxy**: `backend/image-proxy/` deployed; client uses
      `API_BASE_URL` so release builds need no real client Pexels key.
- [x] **Ship branding**: `com.grocerio.app`, Grocerio label, custom icons,
      release keystore wiring, support email in listing draft.

## 4. Known limitations (status)

| Limitation | Status |
|---|---|
| Local shopping-day / miss notifications | **Done** (local; not FCM) |
| Item suggestion dropdown | **Done** (local history only) |
| Automatic list date updates | **Done** — startup reconcile + `lastMissedOn` |
| Complete Shopping real behavior | **Done** |
| Voice input minor quirks | Contained — transcript editable before commit |
| Photographer attribution deep link | **Done** |
| Image proxy (no client Pexels key) | **Done** when `API_BASE_URL` set |
| Sync / FCM / cert pinning | Deferred — `BACKEND_NEXT.md` |
| Flutter web | Unsupported (Isar 64-bit schema IDs) |
| Checkbox drift | Structurally addressed |
| Monthly date edge cases beyond Jan | **Hardened** |

## 5. Definition of foundation-complete

This foundation is complete when an agent can:

1. Add a genuinely new feature by copying the `lists/` (or `preferences/`)
   folder structure, without needing to ask what pattern to follow.
2. Run `flutter analyze` clean and `flutter test` green.
3. Hand the repo to another engineer with `skills.md`, `architecture.md`,
   `ROADMAP.md`, and `BACKEND_NEXT.md` as onboarding material.

Learning exercises in `EXERCISES.md` are complete. Product roadmap items in
`ROADMAP.md` and the local polish pass are shipped; remaining remote work is
documented in `BACKEND_NEXT.md` only.
