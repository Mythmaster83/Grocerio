# Grocerio Alpha

Grocery / stock list manager built as a **feature-first Clean Architecture**
Flutter app (Riverpod + Isar + Dio/Pexels + speech_to_text).

This repo is past the "foundation-only" stage: lists, preferences, images,
and voice are wired end-to-end. Learning exercises in `EXERCISES.md` are
complete. Next product work is in `ROADMAP.md`.

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

- **Internet:** `android/app/src/main/AndroidManifest.xml` (`INTERNET`).
- **Microphone (voice):** `RECORD_AUDIO` on Android; iOS
  `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`.
- **Windows:** no in-app mic prompt — see Exercise 3B / voice controller
  (`blockedByOS` + Settings guidance).

## Read these before writing code

1. `architecture.md` — layering, Riverpod shapes, storage, security.
2. `goals.md` — done definition, in/out of scope, next increment.
3. `skills.md` — how to add a feature (copy `lists/` or `preferences/`).
4. `ROADMAP.md` — Complete Shopping + schedule reconciliation plan.
5. `EXERCISES.md` — completed learning track (reference patterns).

## Repo layout

```
lib/
  core/            # config, security, network, theme, DI, shared widgets
  features/
    lists/         # reference vertical slice (CRUD + images on add)
    preferences/   # layered like lists (repo + pure-Dart domain ints)
    voice_input/   # mic + platform permission / Windows UX
    images/        # Pexels + NetworkImageWithFallback
    scheduling/    # ScheduleFrequency (+ nextOccurrence)
  app.dart
  main.dart
```

## Current product gaps (intentional)

- **Home pageOrder** persists but is not a drag-reorder UI.

Complete Shopping and overdue/missed-date reconciliation are shipped — see
`ROADMAP.md`.
