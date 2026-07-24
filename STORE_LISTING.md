# Store listing draft (Play Store / App Store)

Working copy for shipment — not a full submission (accounts/signing are yours).

## Title

Grocerio

## Subtitle / short description

Grocery and stock lists with schedules, voice add, and local reminders.

## Full description (draft)

Grocerio helps you keep grocery and stock lists organized on your phone.

- Create one-time or recurring lists (weekly, biweekly, monthly)
- Check off items as you shop; complete a trip to reset and roll the date
- Add items by typing or voice
- Optional product images from Pexels (with photographer attribution)
- Local reminders on shopping day, and a notice if a planned date was missed
- Themes, accent color, text size, and tab order in Settings

All list data stays on your device in this version. There is no account and
no multi-device sync yet.

## Privacy notes (for store questionnaires)


| Data                        | Purpose                                                                    |
| --------------------------- | -------------------------------------------------------------------------- |
| Lists and items (on device) | Core app functionality                                                     |
| Microphone                  | Optional voice input for item names                                        |
| Internet                    | Optional image search (via your configured API / proxy); no account upload |
| Notifications               | Local reminders for scheduled shopping days                                |


We do not operate a user account system in this build. Prefer routing image
search through a backend proxy before public release (`BACKEND_NEXT.md`,
`backend/image-proxy/`).

## Support / contact

`aliahmedaziz08@gmail.com`

## Keywords (optional)

grocery, shopping list, stock, pantry, reminders

## Graphics notes

- Launcher icon: custom Grocerio bag/home mark (generated via `flutter_launcher_icons`).
- Feature graphic / screenshots: capture Lists, Settings, Complete Shopping, and a miss badge.

