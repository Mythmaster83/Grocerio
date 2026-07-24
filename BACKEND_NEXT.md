# Backend next

Local-first app with an optional image proxy. Sync / pinning / FCM remain
future phases.

## Why

- Bundled `PEXELS_API_KEY` can be extracted from an APK/IPA.
- Multi-device sync needs a remote source of truth (`architecture.md` §7).
- Certificate pinning only against **our** host.

## 1. Image search proxy — implemented (deploy required)

**Code:** [`backend/image-proxy/`](backend/image-proxy/) (Cloudflare Worker).

**Client (already wired):**

- Set `API_BASE_URL` in `.env` → [ProxyImageRemoteDataSource](lib/features/images/data/datasources/proxy_image_remote_datasource.dart).
- Unset / `REPLACE_ME` → direct Pexels (dev convenience).
- [EnvConfig.load](lib/core/config/env_config.dart): if proxy URL is set, client
  Pexels key is **not** required; release without proxy logs a warning.

**Deploy:** see [backend/image-proxy/README.md](backend/image-proxy/README.md).

```
npx wrangler secret put PEXELS_API_KEY
npx wrangler deploy
# .env → API_BASE_URL=https://….workers.dev
```

## 2. Multi-device / shared-list sync (later)

1. Auth (anonymous → email/Apple/Google).
2. Remote documents for lists + items (or event log).
3. Isar becomes a **local cache**; offline queue for writes.
4. Conflict policy: last-write-wins on item fields for v1.

Do **not** start sync by uploading Isar files.

## 3. Certificate pinning (after proxy is stable)

- Pin only the **proxy / sync** host in Dio.
- Do not pin `api.pexels.com` — the client should not call Pexels once proxied.

## 4. Remote push (FCM / APNs)

Local notifications already cover shopping-day and missed-date reminders.
Remote push is optional later (device tokens, server fan-out).

## Suggested order

1. Deploy `backend/image-proxy` → set `API_BASE_URL` → ship without client Pexels key.
2. Auth + sync.
3. Pin the proxy host.
4. Optionally FCM.
