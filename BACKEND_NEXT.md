# Backend next

Accounts, list sync, sharing, and community prices now ship against
Supabase (see `supabase/README.md`). What remains is optional hardening,
not launch-blocking product.

## Why this file still exists

- Remote push (FCM / APNs) is still out of scope — local reminders cover
  shopping day and missed dates.
- Certificate pinning is only meaningful against *our* host, and only after
  that host is considered stable.

## 1. Image search proxy — retired

Item images were replaced by bundled offline icons (`lib/features/item_icons/`),
so the Pexels client code, `ApiClient`, `EnvConfig`, and `.env` are gone.

`backend/image-proxy/` (Cloudflare Worker) is kept only as reference for a
future feature that needs a credential-holding proxy. It is not deployed to
by any current workflow and nothing in the app calls it — delete it if that
future never arrives.

See [backend/image-proxy/README.md](backend/image-proxy/README.md).

## 2. Sync — shipped

Local-first, pull-then-push, last-write-wins per row, tombstones for
deletes. Isar remains what the UI reads. Do **not** start syncing by
uploading Isar files.

## 3. Certificate pinning (later)

- Pin only the Supabase host, using the official SDK's hook if/when one
  exists — do not wrap the SDK in a custom Dio client just to pin.
- There is no retailer API to pin.

## 4. Remote push (FCM / APNs)

Local notifications already cover shopping-day and missed-date reminders.
Remote push is optional later (device tokens, server fan-out) for "someone
else checked milk off".

## Suggested remaining order

1. Host `PRIVACY.md` and the account-deletion URL; refresh the closed-track AAB
2. Pin the Supabase host if abuse or MITM becomes a real concern
3. Optionally FCM for shared-list activity
