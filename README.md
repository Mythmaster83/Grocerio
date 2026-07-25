# Grocerio

Grocery / stock list manager — **feature-first Clean Architecture** Flutter
app (Riverpod + Isar + Dio + speech_to_text + local notifications).

Display name: **Grocerio** · Android / iOS id: `com.grocerio.app`

| Doc | Purpose |
|---|---|
| `LAUNCH_TIMELINE.md` | Play closed-test → production dates (~Aug 22) |
| `architecture.md` | Layering, Riverpod, Isar, security contract |
| `goals.md` | MVP scope and definition of done |
| `skills.md` | Coding conventions |
| `ROADMAP.md` | Product history |
| `BACKEND_NEXT.md` | Proxy (done) / sync / pinning / FCM |
| `SHIP_CHECKLIST.md` | Pre-store QA |
| `STORE_LISTING.md` | Play / App Store copy draft |
| `EXERCISES.md` | Learning exercises (complete) |

## Architecture at a glance

```
presentation  →  domain  →  data
 (Flutter,        (pure       (Isar, Dio,
  Riverpod)        Dart)       Pexels or proxy)
```

**Shell:** `AppShell` bottom nav — **Lists** + **Settings** (reorderable via
`pageOrder`). List cards on Home are already sorted by `scheduledFor`; there
is no separate Schedule tab.

**Images:** Prefer `API_BASE_URL` → Cloudflare Worker
(`backend/image-proxy/`) so the Pexels key never ships in the client.
Unset proxy → direct Pexels (dev only).

## Setup

```bash
flutter pub get
cp key.env.example .env
# Production-shaped .env:
#   API_BASE_URL=https://grocer-image-proxy.<account>.workers.dev
#   PEXELS_API_KEY=REPLACE_ME
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run          # Android / iOS — not Chrome (Isar uses 64-bit IDs)
```

`build_runner` generates `*.g.dart` for Isar models — required before first
run, and again after editing any `@collection` / `@embedded` class.

### Platform permissions

- **Internet:** `INTERNET`
- **Microphone (voice):** `RECORD_AUDIO` / iOS mic + speech usage strings
- **Notifications:** `POST_NOTIFICATIONS` (Android 13+), boot receivers for schedules
- **Windows / web:** Isar does not support Flutter web; Windows is OK for UI
  smoke tests but phone is the ship target

### Release signing (Android)

- `applicationId`: `com.grocerio.app`
- Release builds use `android/upload-keystore.jks` + `android/key.properties`
  (both gitignored). See `android/key.properties.example`.
- **Back up** those two files — losing them blocks Play Store updates.

### Launcher icons

Source art: `assets/branding/`. Regenerate all platforms:

```bash
dart run flutter_launcher_icons
```

## Repo layout

```
lib/
  core/                 # theme, config, Result, DI, shared widgets
  features/
    lists/              # CRUD, Complete Shopping, schedule reconcile
    preferences/        # theme / accent / AppShell tabs
    voice_input/
    images/             # Pexels datasource OR proxy datasource
    scheduling/         # ScheduleFrequency domain enum
    notifications/      # local shopping-day + miss reminders
backend/
  image-proxy/          # Cloudflare Worker (wrangler.jsonc)
```

## Current product gaps (intentional)

- Multi-device sync / FCM / cert pinning — `BACKEND_NEXT.md`
- Store upload: screenshots, Play Console, real-device QA — `SHIP_CHECKLIST.md`
