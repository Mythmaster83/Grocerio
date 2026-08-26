# Grocerio

Grocery / stock list manager — **feature-first Clean Architecture** Flutter
app (Riverpod + Isar + optional Supabase + speech_to_text + local
notifications).

Display name: **Grocerio** · Android / iOS id: `com.grocerio.app`

| Doc | Purpose |
|---|---|
| `LAUNCH_TIMELINE.md` | Play closed-test → production dates (~Aug 22) |
| `architecture.md` | Layering, Riverpod, Isar, security contract |
| `goals.md` | MVP scope and definition of done |
| `skills.md` | Coding conventions |
| `ROADMAP.md` | Product history |
| `BACKEND_NEXT.md` | Post-launch options: FCM / pinning |
| `SHIP_CHECKLIST.md` | Pre-store QA |
| `STORE_LISTING.md` | Play / App Store copy draft |
| `PRIVACY.md` | Privacy policy + public account-deletion copy |
| `supabase/README.md` | Backend project, RLS, dart-defines |
| `EXERCISES.md` | Learning exercises (complete) |

## Architecture at a glance

```
presentation  →  domain  →  data
 (Flutter,        (pure         (Isar,
  Riverpod)        Dart)     local notifs)
```

**Shell:** single page. `HomeScreen` = AppBar (drawer) → next-scheduled-date
banner → list cards, grouped Overdue / This week / Later. Settings, stores,
price lookup, and account are in the drawer. Each card's 3-dot menu edits
the list's name, date, and repeat, or deletes it.

**Item icons:** bundled Fluent Emoji SVGs (MIT) chosen by keyword from the
item name — see `lib/features/item_icons/`. Fully offline.

**Accounts:** optional. Without `--dart-define` credentials the app never
opens a socket. With them: email magic-link, list sync, sharing, ZIP-scoped
community prices. See `supabase/README.md`.

## Setup

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run          # Android / iOS — not Chrome (Isar uses 64-bit IDs)
```

`build_runner` generates `*.g.dart` for Isar models — required before first
run, and again after editing any `@collection` / `@embedded` class.

### Platform permissions

- **Internet:** `INTERNET` (sign-in, sync, sharing, prices). Lists work offline.
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
    catalog/            # canonical items, resolution, seed
    pricing/            # user-reported prices, lookup
    stores/             # Kroger / Walmart / Publix labels
    account/            # magic-link auth
    sharing/            # invite by email, members
    sync/               # local-first push/pull
    navigation/         # AppDrawer
    preferences/        # font / text scale / ZIP / custom units
    voice_input/
    item_icons/         # name → icon keyword rules + bundled SVG icons
    scheduling/         # ScheduleFrequency domain enum
    notifications/      # local shopping-day + miss reminders
```

## Current product gaps (intentional)

- FCM / cert pinning — `BACKEND_NEXT.md`
- Flutter web unsupported (Isar)
- Store upload: screenshots, Play Console, real-device QA — `SHIP_CHECKLIST.md`
