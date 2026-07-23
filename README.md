# Grocer — Foundation

Production-grade **foundation** for a grocery/stock list manager. This is not
a finished app — it's a fully wired architectural skeleton with one complete
vertical slice (Lists) so any engineer or agent can extend it without
guessing at conventions.

## Setup

```bash
flutter pub get
cp key.env.example .env      # then fill in your real PEXELS_API_KEY
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

`build_runner` generates `*.g.dart` for Isar models — required before first
run, and again after editing any `@collection`/`@embedded` class.

### Platform setup this repo does NOT include

This repo ships `lib/`, not a full `flutter create` scaffold. Before running
on-device you still need to run `flutter create .` in this directory once
(non-destructive — it only adds `android/`, `ios/`, etc. that are missing),
then add:

- **Microphone permission** (voice input): `NSMicrophoneUsageDescription` +
  `NSSpeechRecognitionUsageDescription` in `ios/Runner/Info.plist`;
  `RECORD_AUDIO` in `android/app/src/main/AndroidManifest.xml`.
- **Internet permission** on Android (usually default, verify it's present).

## Read these before writing code

1. `architecture.md` — layering rules, why each decision was made, known
   limitations, and the client-API-key risk you must not ignore.
2. `goals.md` — what "done" means for the MVP, explicit non-goals.
3. `skills.md` — conventions: naming, error handling, state management
   patterns, testing expectations. Read this before adding a feature.

## Repo layout

```
lib/
  core/            # cross-feature: config, security, network, theme, DI, shared widgets
  features/
    lists/         # COMPLETE reference vertical slice — copy this pattern
    voice_input/   # working, minimal
    images/        # working, minimal (Pexels)
    scheduling/    # shared domain value object only (ScheduleFrequency)
    preferences/   # complete (theme/font/text-scale/page-order)
  app.dart         # MaterialApp + theme wiring
  main.dart        # startup: env load, Isar open, ProviderScope
```
