# Image search proxy (Cloudflare Worker)

Holds `PEXELS_API_KEY` on the server so release APKs/IPAs do not embed it.

## Endpoint

`GET /images/search?q=<term>`

Returns:

```json
{
  "photos": [
    {
      "photographer": "Name",
      "photographer_url": "https://www.pexels.com/@...",
      "src": { "small": "https://...", "medium": "https://..." }
    }
  ]
}
```

## Deploy

```bash
cd backend/image-proxy
npm install
npx wrangler login
npx wrangler secret put PEXELS_API_KEY
npx wrangler deploy
```

Config lives in `wrangler.jsonc` (Workers observability / logs included).

**Do not commit** `node_modules/` — run `npm install` locally after clone.

Copy the worker URL (no trailing slash) into the Flutter `.env`:

```
API_BASE_URL=https://grocer-image-proxy.<account>.workers.dev
PEXELS_API_KEY=REPLACE_ME
```

With `API_BASE_URL` set, the app uses `ProxyImageRemoteDataSource` and does
**not** require a real client `PEXELS_API_KEY` (see `EnvConfig.load`).

## Local smoke test

```bash
npx wrangler dev
curl "http://127.0.0.1:8787/images/search?q=milk"
```

## Notes

- Best-effort per-isolate rate limit (60 req/min/IP).
- CORS is open for GET — tighten if you only ship native apps.
- Next steps after this works: sync, then cert pinning against **this** host
  (`BACKEND_NEXT.md`).
