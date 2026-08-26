# Ship checklist

Run before uploading a release build to a store.

**Launch schedule:** fixed calendar in `LAUNCH_TIMELINE.md` is discarded.
Soft ceiling: **production by late September 2026**. Track progress in
[`ROADMAP.md`](ROADMAP.md) (includes **signed AAB** generation steps).
Recruit 12 closed testers in parallel — that track is still the critical path.

## Config

- [ ] Build with `--dart-define=SUPABASE_URL=...` and
      `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` (see `supabase/README.md`)
- [x] Keystore backed up off-machine
- [ ] `flutter analyze` clean (from **repo root**)
- [ ] `flutter test` green (same)

## Branding / identity

- [x] App label **Grocerio**
- [x] Launcher icons (Android / iOS / Windows) from `assets/branding/`
- [x] `applicationId` / bundle id `com.grocerio.app`
- [x] Release signing via `android/key.properties` + `upload-keystore.jks`
      (gitignored — **backed up off-machine**)
- [x] Support email in `STORE_LISTING.md`

## Builds

```bash
# from repo root
flutter build appbundle   # Android Play
flutter build apk         # sideload / testing
# iOS: archive from Xcode with release signing
```

## Manual QA (real device, cold start)

Also confirm v1 issues are gone (see `LAUNCH_TIMELINE.md` verification table).

- [ ] Create list (one-time + weekly)
- [ ] Add item (type + voice if available)
- [ ] Autocomplete suggests prior item names
- [ ] Item icon matches the name (milk / bread / apple / toilet paper)
- [ ] Home shows the next scheduled date above the lists (Today / Tomorrow /
      Overdue label correct)
- [ ] Card 3-dot menu: rename + reschedule + change repeat saves; delete asks first
- [ ] Units include gallon / carton / can; "Add custom unit…" saves and reappears
- [ ] In-list 3-dot → Share as text: pasted text matches title, date, items
- [ ] Complete Shopping: recurring advances date; one-time deletes; returns Home
- [ ] Overdue list: miss icon + dialog; reconcile rolls recurring date
- [ ] Notification permission accepted; shopping-day / miss notices behave
- [ ] Settings opens from the drawer: text scale / font / Your stores
- [ ] Sign in via email link; sign out; Delete account (in-app)
- [ ] Share with people: invite by email; invitee sees the list
- [ ] Your stores: allow location → nearest-first → track 2–3 places
- [ ] Report a price; Price lookup shows On/Off store chips; custom product works for unmatched names
- [ ] **v1 checkbox:** toggle, leave screen, return — state sticks
- [ ] **v1 voice:** edit transcript before add; cancel without adding
- [ ] **v1 images:** icons render in airplane mode (lists still work offline)

## Store upload

- [ ] Privacy policy URL live (host via `netlify-privacy/` → Netlify)
- [ ] Account deletion URL live (`…/#account-deletion`)
- [ ] Play Data Safety updated (see `STORE_LISTING.md` — location + shared prices)
- [ ] Dark-mode screenshots + feature graphic
- [ ] **Signed AAB generated** (`flutter build appbundle --release` + Supabase defines; see `ROADMAP.md`)
- [ ] Signed AAB uploaded; refresh closed track so testers are on this build
- [ ] Re-verify 16 KB page-size alignment on the new AAB
- [ ] Play Console app for `com.grocerio.app` + privacy questionnaire

## Testing tracks

- [ ] Internal testing self-check
- [ ] Recruit 12 closed testers (parallel — critical path)
- [ ] Closed testing live + 14-day clock
- [ ] Production access apply → review → staged rollout (**by late Sep 2026**)

## Known non-blockers

- FCM / cert pinning — `BACKEND_NEXT.md`
- Do **not** withdraw the production-access application if it is mid-review.
  Bank the approval and hold rollout (or staged 0%) rather than redoing the
  14-day closed-testing gate.
