# Ship checklist

Run before uploading a release build to a store.

**Launch schedule:** see [`LAUNCH_TIMELINE.md`](LAUNCH_TIMELINE.md)
(earliest production ~**Aug 22, 2026**). Recruit 12 closed testers in
parallel from **Jul 28** — that track is the critical path.

## Config

- [x] `.env` for release: `API_BASE_URL` → image proxy; client
      `PEXELS_API_KEY=REPLACE_ME`
- [x] Image proxy redeployed (`backend/image-proxy/`)
- [x] Keystore backed up off-machine
- [ ] `flutter analyze` clean (from **repo root**, not `backend/image-proxy`)
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

## Manual QA (real device, cold start) — Jul 25–28

Also confirm v1 issues are gone (see `LAUNCH_TIMELINE.md` verification table).

- [ ] Create list (one-time + weekly)
- [ ] Add item (type + voice if available)
- [ ] Autocomplete suggests prior item names
- [ ] Image appears; tap opens photographer link when available
- [ ] Complete Shopping: recurring advances date; one-time deletes; returns Home
- [ ] Overdue list: miss icon + dialog; reconcile rolls recurring date
- [ ] Notification permission accepted; shopping-day / miss notices behave
- [ ] Settings: theme / accent / text scale; drag tab order (Lists ↔ Settings)
- [ ] **v1 checkbox:** toggle, leave screen, return — state sticks
- [ ] **v1 voice:** edit transcript before add; cancel without adding
- [ ] **v1 images:** load via proxy; fallback offline; photographer link works

## Store upload — Jul 28–30

- [ ] Privacy policy URL (network + mic + notifications + local data)
- [ ] Screenshots + feature graphic
- [ ] Play Console app for `com.grocerio.app` + privacy questionnaire
- [ ] Signed AAB uploaded

## Testing tracks

- [ ] Internal testing self-check (Jul 30–31)
- [ ] Recruit 12 closed testers (start Jul 28, parallel)
- [ ] Closed testing live + 14-day clock (~Aug 1)
- [ ] Production access apply (~Aug 15) → review → launch (~Aug 22)

## Known non-blockers

- Multi-device sync / FCM / cert pinning — `BACKEND_NEXT.md`
- Flutter web unsupported (Isar)
