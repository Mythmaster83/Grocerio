# Grocerio Alpha

Grocery / stock list manager built as a **feature-first Clean Architecture**
Flutter app (Riverpod + Isar + Dio/Pexels + speech_to_text + local notifications).

Learning exercises in `EXERCISES.md` are complete. Product history:
`ROADMAP.md`. Backend plans (not built): `BACKEND_NEXT.md`. Store draft:
`STORE_LISTING.md`.

## Setup

```bash
flutter pub get
cp key.env.example .env      # then fill in your real PEXELS_API_KEY
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

`build_runner` generates `*.g.dart` for Isar models — required before first
run, and again after editing any `@collection`/`@embedded` class.

### Platform permissions

- **Internet:** `INTERNET`
- **Microphone (voice):** `RECORD_AUDIO` / iOS mic + speech usage strings
- **Notifications:** `POST_NOTIFICATIONS` (Android 13+)
- **Windows:** mic and notifications degrade gracefully when unsupported

## Read these before writing code

1. `architecture.md`
2. `goals.md`
3. `skills.md`
4. `ROADMAP.md`
5. `BACKEND_NEXT.md` (proxy / sync / pinning — stubs only)
6. `EXERCISES.md`

## Repo layout

```
lib/
  core/
  features/
    lists/
    preferences/
    voice_input/
    images/          # Pexels or proxy when API_BASE_URL set
    scheduling/
    notifications/   # local shopping-day + miss reminders
```

## Current product gaps (intentional)

- **Live backend** cutover (deploy proxy + set `API_BASE_URL`) — see
  `BACKEND_NEXT.md` and `backend/image-proxy/`.
- Sync / cert pinning / FCM — after the proxy is live.
