# Ship checklist

Run before uploading a release build to a store.

## Config

- [ ] `.env` present for the **release** build you intend to ship
- [ ] Prefer `API_BASE_URL` pointing at the image proxy; do **not** ship a
      real `PEXELS_API_KEY` in the client once the proxy is live
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

## Branding

- [x] App label shows **Grocerio** on device home screen
- [x] Launcher icon is final (not default Flutter icon)
- [x] `STORE_LISTING.md` support email filled in

## Builds

```bash
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
- [ ] Settings: theme / accent / text scale; drag Home page order updates tabs

## Known non-blockers

- Multi-device sync / FCM / cert pinning — `BACKEND_NEXT.md` (after proxy)
- Page-order is **section tabs**, not grocery-card order