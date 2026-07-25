# Grocerio launch timeline (Play Store)

Source of truth for the personal/closed-test → production path.
**Target earliest production: ~Aug 22, 2026** (not “early August”).

| Dates | What happens |
|---|---|
| **Jul 25–28** | Device QA, final bug pass, confirm v2 architecture resolved v1 known issues (checkbox drift, voice input, image redirect) |
| **Jul 28–30** | Signed app bundle, Play Console listing (screenshots, description, **privacy policy** — expect this even with no accounts: Pexels network calls + local storage) |
| **Jul 30–31** | Internal testing track live (instant, no review wait) — sanity-check with yourself first |
| **Jul 28 onward (parallel)** | Recruit **12 testers now** — do not wait for the build; this is the critical path |
| **~Aug 1** | Closed testing track live, 12 testers opted in → **14-day clock** starts at the earliest |
| **~Aug 15** | 14 consecutive days complete → apply for production access |
| **~Aug 15–22** | Google review window |
| **~Aug 22** | Realistic earliest production launch — a day or two before classes, not “early August” |

## Parallel tracks (don’t serialize)

```
Track A (build/listing):  QA → AAB → listing → internal → closed
Track B (people):         recruit 12 testers starting Jul 28 (or sooner)
```

Closed testing cannot start the 14-day clock until **both** the build is on the closed track **and** 12 opted-in testers exist.

## v1 → v2 verification (Jul 25–28)

| v1 pain | v2 expectation | QA check |
|---|---|---|
| Checkbox drift | Single write path: tile → controller → Isar → stream | Toggle checked, leave screen, return — state sticks; no local mirror |
| Voice input | Editable transcript before commit | Speak → edit text → add; cancel without adding |
| Image redirect / broken images | Proxy + `NetworkImageWithFallback` | Add item with image; open photographer link; airplane mode shows fallback |
| 16 KB page size (Play / Android 15+) | `isar_community_flutter_libs` for aligned `libisar.so` | Dialog gone after clean reinstall of new build |

## Privacy policy note

Play often requires a privacy policy URL when the app uses network and/or sensitive permissions (mic, notifications) even without accounts. Host a short page (GitHub Pages, Notion public page, or simple site) covering: local list data, mic for voice, notifications, image search via proxy/Pexels, no account, contact email.

## Status log (update as you go)

- [x] Keystore backed up
- [x] Tests green / release `.env` / proxy deployed
- [ ] Device QA + v1-issue verification (Jul 25–28)
- [ ] Privacy policy URL live
- [ ] AAB + Play listing (Jul 28–30)
- [ ] Internal testing self-check (Jul 30–31)
- [ ] 12 testers recruited (start Jul 28)
- [ ] Closed testing + 14-day clock (~Aug 1)
- [ ] Production access application (~Aug 15)
- [ ] Production launch (~Aug 22)
