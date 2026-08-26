# Roadmap

**Schedule:** Fixed dates from `LAUNCH_TIMELINE.md` are discarded. Soft ceiling:
**production on Google Play by late September 2026 at the latest.** Pace is
feedback-driven (fix what real users hit) plus Play’s closed-testing gate.

**Hard rule:** If production access is mid-review, do **not** withdraw. Bank
approval; hold rollout at 0% / staged until the AAB you want is on the track.

---

## Path to production (tracker)

| Step | Status | Notes |
| --- | --- | --- |
| Device QA from real feedback (lists, stores/location, custom items, auth, share) | [ ] | Use `SHIP_CHECKLIST.md` |
| Host privacy + account deletion (`netlify-privacy/` → Netlify) | [ ] | URLs: `/` and `/#account-deletion` |
| Play Data Safety (incl. approximate location + shared prices) | [ ] | See `STORE_LISTING.md` |
| Dark screenshots + feature graphic | [ ] | |
| Recruit / verify 12 closed testers | [ ] | Parallel with everything else |
| **Generate Play upload package (signed AAB)** | [ ] | See commands below |
| Upload AAB → Internal track → self-check | [ ] | Same binary you will promote |
| Promote to Closed testing; start 14-day clock | [ ] | Needs 12 opted-in testers |
| Apply for production access | [ ] | After 14 consecutive days |
| Staged production rollout (0% → ~20% → 100%) | [ ] | Target: late Sep 2026 |

### Generate the Play Store package (AAB)

Prerequisites: release keystore at `android/key.properties` + upload keystore
file (gitignored); Android SDK Platform **37** installed; Supabase dart-defines
for any build that should support sign-in / sharing / community prices.

```bash
# from repo root
flutter clean
flutter pub get
flutter analyze
flutter test

# Signed App Bundle for Play Console (upload this file)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY

# Output:
#   build/app/outputs/bundle/release/app-release.aab
```

Sideload sanity check (optional APK):

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY
```

Back-plan: have closed testing + 12 testers live by **early–mid September**
so the 14-day gate and Google review still fit before end of month.

**Out of scope for this launch:** FCM, cert pinning, every US grocery location,
retailer APIs (`BACKEND_NEXT.md`).

---

## Feature record — Complete Shopping + schedule reconciliation

**Status (2026-07-23): implemented.** Learning exercises remain in
`EXERCISES.md`. Below is the product record for trip completion and
overdue / missed-date handling.

### Current app functionality (honest snapshot)

| Feature | Status |
|---|---|
| Create / view / delete lists | Works |
| Item CRUD, checkbox, swipe edit | Works |
| Voice add (mobile permissions + Windows blocked UX) | Works |
| Catalog icons / resolution + custom products | Works |
| Preferences (font, text scale); single dark theme | Works |
| **Complete Shopping** | **Works** |
| **Overdue / missed date handling** | **Works** |
| Your stores (US directory + nearest-first via location) | Works |
| Shopper price report / lookup | Works |
| Optional Supabase auth, share, price sync | Works when dart-defines set |
| Backend proxy / cert pinning | Docs + stub — `BACKEND_NEXT.md` |

### Complete Shopping (shipped)

1. Confirm "Complete shopping?"
2. Uncheck every item; pop Home.
3. Recurring → advance date; one-time → delete list.

### Startup schedule reconciliation (shipped)

On Home open, overdue recurring lists advance; one-time lists get a miss
marker without auto-delete.

---

## After production (not blockers)

- Grow US store seed
- Custom-product / catalog moderation as volume grows
- Optional sync/FCM — `BACKEND_NEXT.md`
- iOS when Android is stable
