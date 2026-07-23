# Roadmap — Complete Shopping + schedule reconciliation

**Status (2026-07-23): implemented.** Learning exercises remain in
`EXERCISES.md`. This document is the product record for trip completion and
overdue / missed-date handling.

---

## Current app functionality (honest snapshot)

| Feature | Status |
|---|---|
| Create / view / delete lists | Works |
| Item CRUD, checkbox, swipe edit | Works |
| Voice add (mobile permissions + Windows blocked UX) | Works |
| Pexels images on add + tile fallback | Works (needs real `.env` key) |
| Preferences (theme, accent, font, text scale) layered | Works |
| **Complete Shopping** | **Works** — uncheck all, pop Home, advance recurring / delete one-time |
| **Overdue / missed date handling** | **Works** — startup reconcile + `lastMissedOn` + shared miss icon |
| Page-order reorder UI | Still stub (data persists; Home does not reorder) |
| Monthly `nextOccurrence` | **Hardened** — clamps to month-end for all months (not Jan-only) |

---

## Feature A — Complete Shopping (user-initiated) ✅

### Behavior (shipped)

1. User confirms "Complete shopping?"
2. **Uncheck** every item on the list.
3. **Pop** back to Home.
4. Schedule outcome:
   - **Recurring:** `scheduledFor` → `frequency.nextOccurrence(scheduledFor)`
   - **One-time:** **delete** the list.
5. Clears `lastMissedOn`.

### Architecture

```
ListDetailScreen → ListActionsController.completeShopping(listId)
  → CompleteShopping usecase
    → planCompleteShopping (pure) → deleteList | finalizeShoppingTrip (one writeTxn)
```

### Acceptance

- [x] Recurring: items unchecked, date advanced, navigated to Home
- [x] One-time: list deleted, navigated to Home
- [x] Failure shows SnackBar (existing `ref.listen` path)
- [x] Unit test: `planCompleteShopping` recurring vs one-time (`test/unit/schedule_rules_test.dart`)

---

## Feature B — Startup schedule reconciliation ✅

### Behavior (shipped)

On Home open, `reconcileSchedulesProvider` runs once:

1. Compare **today (date-only)** to each list's `scheduledFor`.
2. If today is **after** `scheduledFor`:
   - **Recurring:** advance (loop if multiple periods skipped) + set `lastMissedOn`
   - **One-time:** keep date + set `lastMissedOn` (never auto-delete)
3. UI: `MissedDateIndicator` on Home tile and detail AppBar; tap → "Last date missed."
4. Dismiss (or Complete Shopping) clears `lastMissedOn` (may reappear next open if still overdue).

### Entry point

Option B: `HomeScreen` watches `reconcileSchedulesProvider` (widget-testable;
overridden in `test/widget_test.dart`).

### Acceptance

- [x] Recurring overdue → date advanced + miss icon (pure plan + wiring)
- [x] One-time overdue → date unchanged + miss icon on tile
- [x] Tap icon → "Last date missed" dialog
- [x] Dismiss (or complete) clears miss state and icon
- [x] Date comparisons use calendar dates (`calendarDate` in `schedule_rules.dart`)

---

## Structural rules (locked)

| Rule | Implementation |
|---|---|
| Persist miss across rollover | `GroceryList.lastMissedOn` / Isar `DateTime?` |
| One miss UI | `MissedDateIndicator` + `showMissedDateDialog` |
| Shared planning | `planCompleteShopping` / `planReconciliation` in `schedule_rules.dart` |
| Monthly clamp | `_addCalendarMonths` in `schedule_frequency.dart` |
| Layering | Usecases + repo; widgets call controller only |
| No auto-delete on open | Delete only via Complete Shopping |

---

## Key files

| Piece | Path |
|---|---|
| Date math | `lib/features/scheduling/domain/entities/schedule_frequency.dart` |
| Pure plans | `lib/features/lists/domain/schedule_rules.dart` |
| Usecases | `.../usecases/complete_shopping.dart`, `reconcile_schedules.dart` |
| Persistence | `lists_local_datasource.dart` (`finalizeShoppingTrip`, reconcile/flag/clear) |
| UI | `list_detail_screen.dart`, `list_card.dart`, `missed_date_indicator.dart` |
| Startup | `lists_di.dart` → `reconcileSchedulesProvider` |

---

## Out of scope (still)

- Push notifications when a date is missed
- Auto-complete shopping without user action
- Changing frequency mid-cycle
- Page-order drag UI
