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
- Colorful icons for your items, matched automatically and stored in the app
- Compare shopper-reported prices near the stores you track
- Share a live list with someone else (optional account — email link, no password)
- Local reminders on shopping day, and a notice if a planned date was missed
- A single dark theme built for low-light aisles, with text size and font choice in Settings

Lists always work on this device. Signing in is optional and only needed for
sharing and community prices.

## Privacy notes (for store questionnaires)

Host [`PRIVACY.md`](PRIVACY.md) publicly — easiest path: drag
[`netlify-privacy/`](netlify-privacy/) onto Netlify Drop — and use:

- Play Console → App content → **Privacy policy** → `https://YOUR_SITE.netlify.app/`
- Play Console → App content → **Account deletion** →
  `https://YOUR_SITE.netlify.app/#account-deletion`

### Play Data Safety answers

Declare that the app **collects** and **shares** data, because signed-in
use does both. Approximate mapping:

| Data type | Collected? | Shared with other users? | Required? | Purpose |
| --- | --- | --- | --- | --- |
| Email address | Yes, if they sign in | Only with people they invite to a list | Optional | Account management |
| User IDs | Yes, if they sign in | Yes (list membership, `reportedBy` on prices) | Optional | Account / app functionality |
| In-app text (list names, items) | Yes, if they sign in and sync | Yes, with list members | Optional | App functionality |
| Approximate location | Yes, if the user allows location and/or tracks stores (ZIP of those stores attaches to price reports) | Yes — ZIP on submitted prices is visible to other shoppers in the same ZIP prefix | Optional | App functionality (sort nearby stores on-device; scope community prices) |
| Submitted prices | Yes | Yes — other shoppers in the same ZIP prefix | Optional | App functionality |

Other rows: no financial info, no photos, no contacts, no health data.

Encryption in transit: yes (HTTPS to Supabase). Users can request deletion:
yes (in-app + the public URL). Data is not sold, not used for advertising.

Microphone is used only for on-device voice input and is not collected by
us. Notifications are local.

Answer **no** to "is this app a system service / MDM" etc. as usual.

Prices a user submits are **shared with other users**. The policy states
they are shopper-submitted and may be wrong.

## Support / contact

`aliahmedaziz08@gmail.com`

## Keywords (optional)

grocery, shopping list, stock, pantry, reminders, price comparison

## Graphics notes

- Launcher icon: custom Grocerio bag/home mark (generated via `flutter_launcher_icons`).
- Feature graphic / screenshots: **retake in the dark theme**. Capture Home
  (section headers + a list card), list detail with the price block,
  Price lookup, Share with people, and Settings. Any leftover light-mode
  screenshot must be replaced before rollout.
- Closed-track refresh: upload a new AAB after this work so the 12 testers
  are on the sharing/pricing build, not the local-only one.

