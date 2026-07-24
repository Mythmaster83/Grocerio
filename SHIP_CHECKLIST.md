# Ship checklist

Run before uploading a release build to a store.

## Config

- [x] `.env` for release: `API_BASE_URL` → image proxy; client
      `PEXELS_API_KEY=REPLACE_ME`
- [x] Image proxy redeployed (`backend/image-proxy/`)
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

## Manual QA (real device, cold start)

- [ ] Create list (one-time + weekly)
- [ ] Add item (type + voice if available)
- [ ] Autocomplete suggests prior item names
- [ ] Image appears; tap opens photographer link when available
- [ ] Complete Shopping: recurring advances date; one-time deletes; returns Home
- [ ] Overdue list: miss icon + dialog; reconcile rolls recurring date
- [ ] Notification permission accepted; shopping-day / miss notices behave
- [ ] Settings: theme / accent / text scale; drag tab order (Lists ↔ Settings)

## Store upload

- [ ] Screenshots + feature graphic
- [ ] Play Console app for `com.grocerio.app` + privacy questionnaire
- [ ] Internal testing → production

## Known non-blockers

- Multi-device sync / FCM / cert pinning — `BACKEND_NEXT.md`
- Flutter web unsupported (Isar)
