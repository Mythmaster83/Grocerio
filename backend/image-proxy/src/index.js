/**
 * Grocer image search proxy — Cloudflare Worker.
 *
 * GET /images/search?q=milk
 * Secret: PEXELS_API_KEY (wrangler secret put PEXELS_API_KEY)
 *
 * Response shape matches the Flutter ProxyImageRemoteDataSource contract.
 */

const PEXELS_SEARCH = 'https://api.pexels.com/v1/search';

/** @param {string} q */
function sanitizeQuery(q) {
  return q
    .trim()
    .slice(0, 80)
    .replace(/[^\p{L}\p{N}\s\-_.]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Simple in-memory rate limit (per isolate; best-effort). */
const hits = new Map();
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 60;

function rateLimited(ip) {
  const now = Date.now();
  const bucket = hits.get(ip) ?? [];
  const recent = bucket.filter((t) => now - t < RATE_WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > RATE_MAX;
}

export default {
  /**
   * @param {Request} request
   * @param {{ PEXELS_API_KEY: string }} env
   */
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }

    if (request.method !== 'GET') {
      return json({ error: 'Method not allowed' }, 405);
    }

    if (url.pathname !== '/images/search' && url.pathname !== '/images/search/') {
      return json({ error: 'Not found' }, 404);
    }

    const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    if (rateLimited(ip)) {
      return json({ error: 'Rate limit exceeded' }, 429);
    }

    const raw = url.searchParams.get('q') ?? '';
    const q = sanitizeQuery(raw);
    if (!q) {
      return json({ photos: [] }, 200);
    }

    const key = env.PEXELS_API_KEY;
    if (!key) {
      return json({ error: 'Server misconfigured' }, 500);
    }

    const pexelsUrl = new URL(PEXELS_SEARCH);
    pexelsUrl.searchParams.set('query', q);
    pexelsUrl.searchParams.set('per_page', '5');

    const upstream = await fetch(pexelsUrl.toString(), {
      headers: { Authorization: key },
    });

    if (!upstream.ok) {
      return json(
        { error: 'Upstream image search failed', status: upstream.status },
        502,
      );
    }

    const data = await upstream.json();
    const photos = (data.photos ?? []).map((p) => ({
      photographer: p.photographer ?? 'Unknown',
      photographer_url: p.photographer_url ?? null,
      src: {
        small: p.src?.small ?? p.src?.tiny ?? '',
        medium: p.src?.medium ?? p.src?.large ?? '',
      },
    }));

    return json({ photos }, 200);
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(),
    },
  });
}
