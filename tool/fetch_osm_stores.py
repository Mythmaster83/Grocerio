#!/usr/bin/env python3
"""Fetch real supermarket POIs from OpenStreetMap (Overpass) for Grocerio.

Writes assets/catalog/us_stores_seed.json (version 4).
Rate-limits between metros; never invents street addresses.
"""

from __future__ import annotations

import json
import math
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# ~35 miles in meters — suburbs like Lilburn fall inside Atlanta's radius.
RADIUS_M = 56_327
OVERPASS_URLS = (
    "https://overpass-api.de/api/interpreter",
    "https://lz4.overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
)
SLEEP_BETWEEN_METROS_S = 3
MAX_RETRIES = 5
REQUEST_TIMEOUT_S = 150

ROOT = Path(__file__).resolve().parents[1]
OUT_PATH = ROOT / "assets" / "catalog" / "us_stores_seed.json"

# Display name + OSM match needles (brand/name, case-insensitive).
CHAINS: list[tuple[str, str, tuple[str, ...]]] = [
    ("walmart", "Walmart", ("walmart", "wal-mart")),
    ("kroger", "Kroger", ("kroger",)),
    ("publix", "Publix", ("publix",)),
    ("target", "Target", ("target",)),
    ("aldi", "Aldi", ("aldi",)),
    ("costco", "Costco", ("costco",)),
    ("trader-joes", "Trader Joe's", ("trader joe", "trader joe's")),
    ("safeway", "Safeway", ("safeway",)),
    ("whole-foods", "Whole Foods", ("whole foods", "wholefoods")),
    ("food-lion", "Food Lion", ("food lion",)),
    ("heb", "H-E-B", ("h-e-b", "heb", "h-e-b.")),
    ("king-soopers", "King Soopers", ("king soopers", "king sooper")),
]

# (city, state, lat, lon) — same metros as the old synthetic generator.
CITIES: list[tuple[str, str, float, float]] = [
    ("Atlanta", "GA", 33.7490, -84.3880),
    ("Marietta", "GA", 33.9526, -84.5499),
    ("Savannah", "GA", 32.0809, -81.0912),
    ("Miami", "FL", 25.7617, -80.1918),
    ("Orlando", "FL", 28.5383, -81.3792),
    ("Tampa", "FL", 27.9506, -82.4572),
    ("Jacksonville", "FL", 30.3322, -81.6557),
    ("Nashville", "TN", 36.1627, -86.7816),
    ("Charlotte", "NC", 35.2271, -80.8431),
    ("Raleigh", "NC", 35.7796, -78.6382),
    ("Chicago", "IL", 41.8781, -87.6298),
    ("Naperville", "IL", 41.7508, -88.1535),
    ("New York", "NY", 40.7128, -74.0060),
    ("Brooklyn", "NY", 40.6782, -73.9442),
    ("Boston", "MA", 42.3601, -71.0589),
    ("Philadelphia", "PA", 39.9526, -75.1652),
    ("Pittsburgh", "PA", 40.4406, -79.9959),
    ("Washington", "DC", 38.9072, -77.0369),
    ("Baltimore", "MD", 39.2904, -76.6122),
    ("Richmond", "VA", 37.5407, -77.4360),
    ("Dallas", "TX", 32.7767, -96.7970),
    ("Houston", "TX", 29.7604, -95.3698),
    ("Austin", "TX", 30.2672, -97.7431),
    ("San Antonio", "TX", 29.4241, -98.4936),
    ("Phoenix", "AZ", 33.4484, -112.0740),
    ("Tucson", "AZ", 32.2226, -110.9747),
    ("Denver", "CO", 39.7392, -104.9903),
    ("Seattle", "WA", 47.6062, -122.3321),
    ("Portland", "OR", 45.5152, -122.6784),
    ("San Francisco", "CA", 37.7749, -122.4194),
    ("Los Angeles", "CA", 34.0522, -118.2437),
    ("San Diego", "CA", 32.7157, -117.1611),
    ("Sacramento", "CA", 38.5816, -121.4944),
    ("Minneapolis", "MN", 44.9778, -93.2650),
    ("Detroit", "MI", 42.3314, -83.0458),
    ("Columbus", "OH", 39.9612, -82.9988),
    ("Cincinnati", "OH", 39.1031, -84.5120),
    ("Cleveland", "OH", 41.4993, -81.6944),
    ("Indianapolis", "IN", 39.7684, -86.1581),
    ("Louisville", "KY", 38.2527, -85.7585),
    ("New Orleans", "LA", 29.9511, -90.0715),
    ("Kansas City", "MO", 39.0997, -94.5786),
    ("St Louis", "MO", 38.6270, -90.1994),
    ("Oklahoma City", "OK", 35.4676, -97.5164),
    ("Salt Lake City", "UT", 40.7608, -111.8910),
    ("Las Vegas", "NV", 36.1699, -115.1398),
    ("Albuquerque", "NM", 35.0844, -106.6504),
    ("Birmingham", "AL", 33.5207, -86.8025),
    ("Charleston", "SC", 32.7765, -79.9311),
    ("Greenville", "SC", 34.8526, -82.3940),
]


def _slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "x"


def _match_chain(tags: dict[str, str]) -> tuple[str, str] | None:
    hay = " ".join(
        filter(
            None,
            [
                tags.get("brand", ""),
                tags.get("name", ""),
                tags.get("operator", ""),
            ],
        )
    ).lower()
    if not hay:
        return None
    for chain_slug, display, needles in CHAINS:
        for needle in needles:
            if needle in hay:
                return chain_slug, display
    return None


def _overpass_query(lat: float, lon: float) -> str:
    # Keep the query minimal — public Overpass instances time out on heavy
    # regex / multi-shop filters. Client-side brand matching does the rest.
    return f"""
[out:json][timeout:120];
(
  node(around:{RADIUS_M},{lat},{lon})["shop"="supermarket"];
  way(around:{RADIUS_M},{lat},{lon})["shop"="supermarket"];
);
out center tags;
"""


def _post_overpass(query: str) -> dict:
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    last_err: Exception | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        url = OVERPASS_URLS[(attempt - 1) % len(OVERPASS_URLS)]
        req = urllib.request.Request(
            url,
            data=data,
            headers={"User-Agent": "GrocerioStoreSeed/1.0 (local build tool)"},
            method="POST",
        )
        try:
            print(f"  POST {url} (attempt {attempt})", flush=True)
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_S) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            last_err = e
            wait = SLEEP_BETWEEN_METROS_S * attempt
            print(
                f"  Overpass error ({e}); retry in {wait}s "
                f"[{attempt}/{MAX_RETRIES}]",
                flush=True,
            )
            time.sleep(wait)
    raise RuntimeError(f"Overpass failed after retries: {last_err}")


def _element_coords(el: dict) -> tuple[float, float] | None:
    if "lat" in el and "lon" in el:
        return float(el["lat"]), float(el["lon"])
    center = el.get("center") or {}
    if "lat" in center and "lon" in center:
        return float(center["lat"]), float(center["lon"])
    return None


def _address_line(tags: dict[str, str], city: str) -> str:
    house = (tags.get("addr:housenumber") or "").strip()
    street = (tags.get("addr:street") or "").strip()
    if house and street:
        return f"{house} {street}"
    if street:
        return street
    # Honest fallback — never invent a street number.
    place_city = (tags.get("addr:city") or city).strip() or city
    return f"Store in {place_city}"


def _miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 3958.8
    p = math.pi / 180.0
    a = (
        math.sin((lat2 - lat1) * p / 2) ** 2
        + math.cos(lat1 * p)
        * math.cos(lat2 * p)
        * math.sin((lon2 - lon1) * p / 2) ** 2
    )
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def fetch_metro(city: str, state: str, lat: float, lon: float) -> list[dict]:
    print(f"Fetching {city}, {state}...", flush=True)
    payload = _post_overpass(_overpass_query(lat, lon))
    rows: list[dict] = []
    for el in payload.get("elements", []):
        tags = {k: str(v) for k, v in (el.get("tags") or {}).items()}
        matched = _match_chain(tags)
        if matched is None:
            continue
        coords = _element_coords(el)
        if coords is None:
            continue
        el_lat, el_lon = coords
        chain_slug, display = matched
        osm_type = el.get("type", "node")
        osm_id = el.get("id")
        if osm_id is None:
            continue
        zipc = (tags.get("addr:postcode") or "").strip()
        place_city = (tags.get("addr:city") or city).strip() or city
        place_state = (tags.get("addr:state") or state).strip() or state
        if len(place_state) == 2:
            place_state = place_state.upper()
        key_part = _slugify(zipc or place_city)
        slug = f"{chain_slug}-{_slugify(place_state)}-{key_part}-{osm_type}{osm_id}"
        rows.append(
            {
                "slug": slug,
                "name": display,
                "chainSlug": chain_slug,
                "addressLine": _address_line(tags, place_city),
                "city": place_city,
                "state": place_state,
                "zip": zipc or None,
                "lat": round(el_lat, 6),
                "lng": round(el_lon, 6),
                "_miles_from_metro": _miles(lat, lon, el_lat, el_lon),
            }
        )
    print(f"  matched {len(rows)} chain stores", flush=True)
    return rows


CHECKPOINT_PATH = ROOT / "tool" / ".osm_stores_checkpoint.json"


def _load_checkpoint() -> tuple[set[str], dict[str, dict]]:
    if not CHECKPOINT_PATH.exists():
        return set(), {}
    try:
        raw = json.loads(CHECKPOINT_PATH.read_text(encoding="utf-8"))
        done = set(raw.get("done_metros", []))
        by_slug = raw.get("by_slug", {})
        if isinstance(by_slug, dict):
            return done, by_slug
    except (OSError, json.JSONDecodeError) as e:
        print(f"Ignoring bad checkpoint: {e}", flush=True)
    return set(), {}


def _save_checkpoint(done: set[str], by_slug: dict[str, dict]) -> None:
    CHECKPOINT_PATH.write_text(
        json.dumps(
            {"done_metros": sorted(done), "by_slug": by_slug},
            indent=2,
        ),
        encoding="utf-8",
    )


def _write_seed(by_slug: dict[str, dict]) -> int:
    stores = []
    for row in by_slug.values():
        cleaned = {k: v for k, v in row.items() if k != "_miles_from_metro"}
        stores.append(cleaned)

    stores.sort(key=lambda s: (s["state"], s["city"], s["name"], s["slug"]))

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump({"version": 4, "stores": stores}, f, indent=2)
        f.write("\n")
    return len(stores)


def main() -> None:
    done, by_slug = _load_checkpoint()
    if done:
        print(f"Resuming; {len(done)} metros already done, {len(by_slug)} stores", flush=True)

    for i, (city, state, lat, lon) in enumerate(CITIES):
        metro_key = f"{city}|{state}"
        if metro_key in done:
            print(f"Skip {city}, {state} (checkpoint)", flush=True)
            continue
        try:
            for row in fetch_metro(city, state, lat, lon):
                existing = by_slug.get(row["slug"])
                if (
                    existing is None
                    or row["_miles_from_metro"] < existing.get("_miles_from_metro", 1e9)
                ):
                    by_slug[row["slug"]] = row
            done.add(metro_key)
            _save_checkpoint(done, by_slug)
            count = _write_seed(by_slug)
            print(f"  checkpoint: {count} stores so far", flush=True)
        except Exception as e:
            print(f"  FAILED {city}: {e}", flush=True)
            _save_checkpoint(done, by_slug)
        if i < len(CITIES) - 1:
            time.sleep(SLEEP_BETWEEN_METROS_S)

    count = _write_seed(by_slug)
    if CHECKPOINT_PATH.exists():
        CHECKPOINT_PATH.unlink()
    print(f"Wrote {count} stores to {OUT_PATH}", flush=True)


if __name__ == "__main__":
    main()
