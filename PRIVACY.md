# Grocerio privacy policy

Last updated: 22 August 2026

This is the policy the Play listing and in-app account-deletion flow should
link to. A ready-to-upload Netlify site lives in [`netlify-privacy/`](netlify-privacy/).
After you deploy it:

- **Privacy policy URL:** `https://YOUR_SITE.netlify.app/`
- **Account deletion URL:** `https://YOUR_SITE.netlify.app/#account-deletion`

Contact: aliahmedaziz08@gmail.com

## What Grocerio is

Grocerio is a grocery-list app. Lists, item check-offs, schedules, and
reminders work on your phone without an account. Signing in is optional and
only needed if you want to share a list with someone else or see prices
other shoppers nearby have reported.

## Data the app stores on your device

| Data | Why |
| --- | --- |
| Lists, items, check-offs, schedules | Core app |
| Font and text-size preferences, tracked store locations | Settings you chose |
| Approximate device location (when you allow it) | Only used on-device to sort stores nearest first; not uploaded as a continuous track |
| Prices you typed | So they reappear on your lists |
| A random device id | Stamped on local price reports before you sign in, so a bad report can be ignored later without knowing who you are |

This on-device copy is the source of truth. The app keeps working with the
network off.

## Data that leaves the device (only if you sign in)

Signing in uses an email magic link (no password). We store:

| Data | Why | Who sees it |
| --- | --- | --- |
| Email and account id | Sign-in, invites, account deletion | You, and anyone you invite to a list (they see your email on that list) |
| Lists and items you own or were invited to | Sync and sharing | You and the members of that list |
| Prices you report, with store location, unit, time, and ZIP of that store | So other shoppers in your area can compare | Any signed-in user whose ZIP prefix matches yours |
| ZIP derived from stores you track | Scopes which community prices you send and receive | Stored with each report you submit |

We do not sell this data. We do not run ads. We do not use a retailer API:
every price in Grocerio was typed by a shopper and **may be wrong**. Treat
prices as hints, not as the store's official amount.

## Permissions

- **Internet** — sign-in, list sync, sharing, and community prices. Lists
  still work if the network is down.
- **Location (optional)** — used only on this device to sort grocery
  locations nearest first when you pick stores to track. Not used for
  continuous tracking or ads. GPS is not uploaded as a live track; community
  price area uses the ZIP of stores you track.
- **Microphone** — optional voice input when adding an item. Audio is handled
  by the device's speech service and is not stored by Grocerio.
- **Notifications** — local reminders on a shopping day, and a notice if a
  planned date was missed. These are scheduled on the device, not pushed
  from a server.

## Sharing lists

You can copy a list as plain text without an account (that paste never
reaches our servers). Live sharing — where someone else can check items off
the same list — requires both of you to have accounts. Only the list owner
can invite. Invites look up the other person's email inside the server; the
app cannot browse other people's addresses.

## Community prices

A price you report while signed in is stored with your account id, the
product, the store location, the amount, and that store's ZIP. Other signed-in shoppers
whose ZIP starts with the same three digits can see it. If you have not tracked
any stores, we do not pull other people's prices onto your phone.

You can still report prices while signed out. Those stay on the device until
you sign in, then they upload under your account.

## Account deletion

Google requires a way to delete an account both **in the app** and at a
**public URL**.

- In the app: Menu → Account → Delete account. This removes the account,
  lists you own in the cloud, memberships, and prices you reported. Lists
  already stored on this phone stay on this phone.
- Public request: email aliahmedaziz08@gmail.com from the address on the
  account with the subject "Delete my Grocerio account". We complete
  deletion within 30 days.

The public URL for this section is the hosted policy page plus
`#account-deletion` (see `netlify-privacy/` after deploy). Set that as the
Play Console account-deletion URL.

## Data retention

Cloud lists and prices exist until you delete the list, delete the price's
underlying account, or delete the account itself. Local data remains until
you clear app storage or uninstall.

## Children

Grocerio is not directed at children under 13.

## Changes

If this policy changes in a way that affects how we use your data, we will
update the date above and the hosted page. Continued use after that date is
acceptance of the new policy.
