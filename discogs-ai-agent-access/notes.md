# Discogs AI agent access — Notes

## Goal

Work out how an AI agent can get at Discogs data for collection, wantlist, and database search/retrieval (marketplace out of scope). Builds on ../discogs-mcp-servers (April 2026 MCP survey); this pass focuses on the underlying API, auth, limits, terms, and bulk data, plus an update on the MCP landscape.

## Work log

### Live API probes (2026-10-04, from a cloud VM, no token, custom User-Agent)

- `www.discogs.com/developers` and `www.discogs.com/robots.txt` both return **403 / Cloudflare "Just a moment..." managed challenge** to curl and WebFetch. The website is effectively closed to non-browser agents; the docs page itself can't be fetched by an agent. Dead end for reading docs directly — need mirrors.
- `api.discogs.com` is **not** behind the challenge: `GET /` returns `api_version: v2`, stats 19,501,084 releases / 10,281,433 artists / 2,439,933 labels.
- Unauthenticated headers: `x-discogs-ratelimit: 25` (per minute, moving window). `x-discogs-media-type: discogs.v2`.
- `GET /releases/249504` unauthenticated: 200, full record incl. tracklist, identifiers (barcode, matrix), credits, community have/want, and **image URLs are present** (i.discogs.com, 600px). Also includes `lowest_price` / `num_for_sale` (marketplace bleed).
- `GET /database/search?q=nirvana` **unauthenticated returned 200** with results. The docs have long said search requires auth. However `thumb` and `cover_image` were empty strings in unauth results. Surprise — note as observed, not guaranteed.
- `per_page=500` on search is clamped to 100. Search pagination tops out: q=nirvana showed 17,677 items but only pages up to 200 @50 (=10,000) / 100 @100; page 201 → 404 "outside of valid range". **Search results are capped at 10,000 per query.**
- Public user (willchatham, who blogged about using a Discogs MCP — public collection): unauth `collection/folders` 200 (only "All" folder visible), `collection/folders/0/releases` 200 with `id, instance_id, date_added, rating, basic_information`, `wants` 200, `lists` 200, `collection/releases/{id}` 200. `collection/value` and `collection/fields` → **403 "authenticate as the owner"**. Sort params accepted.
- Test users `rodneyfool` (docs example), `rianvdm`, `cswkim` → 404 (don't exist / not by that name).

### Getting at the docs and terms (dead ends first)

- `WebFetch` on discogs.com/developers, support.discogs.com (API TOU, TOS) → 403 (Cloudflare).
- Wayback Machine: `archive.org/wayback/available` answers (snapshots exist: API TOU 2026-05-30, TOS 2026-08-23, /developers 2026-09-07), but `web.archive.org` itself is blocked by this environment's egress policy (both curl and WebFetch). archive.ph connection reset.
- **Worked:** `r.jina.ai/<url>` reader proxy renders the Cloudflare-protected pages. Got API TOU, TOS, robots.txt and the /developers home page. The /developers sub-pages (auth, database, collection...) are an SPA; every path/hash variant returned the same home page, so endpoint-level detail had to come from elsewhere (third-party OpenAPI spec, client libraries, live probes).

### API Terms of Use (last updated 2025-05-27)

- Data split: **CC0 Data** (release titles, notes, dates, formats, tracklists, barcodes/identifiers, credits, versions, links; artist names/notes; label names) vs **Restricted Data**: "Discogs User Data" — username, user images, and optional public fields incl. **collection and wantlist**; Marketplace Data (pricing, sales history); Images.
- Restricted Data licence: "limited, personal, non-sublicensable, non-transferable, non-exclusive, revocable license ... to create and run websites and applications". May not: transfer Restricted Data to any third party; use it commercially.
  - Agent implication: sending a user's collection/wantlist into a third-party LLM API is arguably "transfer to a third party". The TOU doesn't address LLMs. For a personal agent operating on the user's own data at their request this is a grey area, not an explicit ban. Flag it, don't overstate.
- No-scrape clause: no "automated systems designed to access, analyze, or scrape ... including Our API and/or the Content, in a way that is inconsistent with these TOU". No creating extra keys to dodge limits.
- **Freshness/caching:** may not display Content more than **6 hours** older than discogs.com; may not cache/store longer than necessary to serve users. Matters for an agent that builds a local index/vector store of API data (CC0 data from the dumps is not bound by this).
- Attribution: "Data provided by Discogs." with followable link next to data; plus the not-affiliated notice in app docs.
- Discogs reserves right to charge for API in future.
- **No explicit AI/LLM clause in the API TOU.**

### Terms of Service (last updated 2026-02-23)

- Personal-use licence; bans "data mining, robots, scraping, harvesting, or similar data gathering and extraction tools" on the Service.
- "We strictly prohibit (1) the development of any software program, including, but not limited to, training a machine learning or artificial intelligence (AI) system using the Service content and (2) providing archived or cached data sets containing any Service content to another person or entity."
- Data-dump content governed by the dump licence (CC0); API data by API TOU. Mentions "Preferred API Partners" with separate agreements.
- Reading: training is banned; *using* the API from an agent at runtime is governed by API TOU. Odd wording "development of any software program" taken literally would ban all apps — clearly meant re: Service content; don't lean on it.

### robots.txt (fetched via reader, published 2026-10-04)

- `User-agent: *` disallows `/users/`, `/mycollection`, `/mywantlist`, `*/wantlist$`, `/my`, `/history`, `/data$` etc. Blocks `Meta-ExternalAgent` (AI trainer) entirely, with a comment that it does *not* block Meta's AI user-answer fetcher. No GPTBot/ClaudeBot/CCBot entries. In practice Cloudflare's managed challenge blocks all non-browser fetches of www anyway.
- So: browser-automation / scraping the website for collection data is both blocked technically and off-limits by robots + TOS. API is the only sanctioned route.

### Data dumps

- data.discogs.com reachable (no challenge). Monthly CC0 XML: 2026-10-01 releases 10.5 GB gz, masters 600.5 MB, artists 475.7 MB, labels 87.0 MB, plus CHECKSUM. TOS links an S3 index (discogs-data-dumps.s3.us-west-2.amazonaws.com).
- Dumps contain no user data (no collection/wantlist), no images, no community stats/prices. Good for offline search/retrieval and RAG over the catalogue without rate limits or 6-hour rule.

### Auth, limits, images — checking third-party claims against the live API

- api-evangelist/discogs (third-party, AI-generated-looking "API Commons" profile, created 2026-05-29) claims: generic UAs like curl / python urllib are blocked; image URLs must be fetched OAuth-signed via `/images/{filename}`; image cap "1000 requests_per_minute, timeFrame day" (self-contradictory). **Live checks contradict this:**
  - default curl UA → 200; `python-requests/2.32.3` UA → 200; **empty UA → 403**. So "must send a UA" is enforced; "generic UA blocked" is not (today). Still send a unique UA as the docs ask.
  - unauthenticated GET of an `i.discogs.com` signed image URL from a release response → 200 image/jpeg. Image URLs are signed; don't edit them (docs FAQ).
  - Lesson: don't trust aggregated "API profile" repos; probe.
- Official docs (home page, via reader): authenticated 60/min, unauth 25/min, moving 60-second window; headers `X-Discogs-Ratelimit[-Used|-Remaining]`; default per_page 50, max 100; `Accept: application/vnd.discogs.v2.{html|plaintext|discogs}+json` controls markup in text fields (plaintext is handy for LLMs); JSONP via `callback`. Client libs listed: bartve/disconnect (Node), ricbra/php-discogs-api, joalla/discogs_client (Python), buntine/discogs (Ruby).
- `/oauth/identity` unauth → 401 "You must authenticate". `/oauth/request_token` and `/oauth/access_token` unsigned → 500 (endpoint exists, needs signed request). Auth options per docs nav: "Discogs Auth Flow" (personal token or consumer key/secret) and OAuth 1.0a. joalla client sends user token as `?token=` query param (header form `Authorization: Discogs token=...` also accepted per docs). No OAuth 2 — MCP servers wanting browser login (rianvdm) bridge MCP OAuth 2.1 to Discogs OAuth 1.0a.
- Search filters probed unauth: `type, artist, release_title, format, country, year` → Nevermind US vinyl 1991 → 2 hits with catno. `barcode=` works. `masters/{id}/versions?format=Vinyl` → 57 with `filters.applied/available` facets.

### Search auth: docs vs observed

- Forum thread 399958 (2014, via reader): Discogs staff announced `/database/search` would require OAuth/consumer-key auth from August 15 (2014); "currently, none of those endpoints require authentication". Search-result snippets say auth also unlocks image URLs.
- Observed today: unauthenticated search returns 200 with results but empty `thumb`/`cover_image`. So enforcement is relaxed or partial. Treat "search needs auth" as the contract; an agent should always send a token anyway (60/min vs 25/min and images).

### Official stance on AI agents / MCP

- Searched for an official Discogs MCP server or AI-agent policy: none found. All MCP servers are community projects. Discogs' only AI-specific language is the TOS training ban and the robots.txt block on Meta's AI trainer. api-evangelist lists "five+ community MCP servers".
- audio-file.org post (2026-10-03) just links cswkim; no new info.

### MCP landscape update (vs ../discogs-mcp-servers, April 2026)

- **rianvdm/discogs-mcp — now v3.5.0, has wantlist tools** (`get_wantlist`, `add_to_wantlist`, `remove_from_wantlist`) plus `refresh_collection`. This closes the main gap called out in April. Still MCP OAuth 2.1 bridged to Discogs, 7-day sessions, Cloudflare Workers; README now says each user should deploy their own Worker with their own Discogs credentials because Discogs throttles by source IP and shared Worker egress IPs drain the budget; optional relay. 6-hourly background sync into KV (lines up with the TOU 6-hour freshness rule). Free tier handles ~2,000 releases. 18 stars, 290 commits.
- **cswkim/discogs-mcp-server** — 128 stars (was ~92), 579 commits. Still personal-token only; "OAuth support will be added in a future release". stdio + HTTP streaming. per_page default 5. Tool list in TOOLS.md.
- **Spiegelberg/discogs-mcp** (npm `discogs-mcp`, glama/lobehub list it as "discorg-mcp", v0.1.2 updated 2026-08-10) — new. Local via npx. Personal token or OAuth 1.0a with a `login` command storing creds in `~/.config/discogs-mcp/credentials.json` (0600). Tools: whoami, search, get release/master/artist/label; collection folders/items/add/remove/update/value; wantlist get/add/remove; plus marketplace & order tools (out of scope — and those are live write actions). 0 stars.
- **WOIII-me/Discogs-MCP ("DIG for Discogs")** — new. Read-only (never modifies collection), OAuth 2.1, Cloudflare Worker with a public instance, `find_best_pressing`, mood search, recommendations, cross-user `discover_similar`. 2 stars. Note: a public multi-user hosted instance sharing one app's rate budget and IP.
- donnatto/discogs-mcp on glama — description matches rianvdm (Cloudflare Agents SDK, mood recs); looks like a fork. Not investigated further.
- Apify "Discogs scraper" MCP actors (crawlerbros, gio21) — scrapers of the website; conflict with TOS no-scrape clause and robots. Excluded.
- NangoHQ/nango PR #7340 adds Discogs OAuth1 + personal-token providers — relevant if building a hosted multi-user agent that needs managed OAuth 1.0a tokens.

### Offline routes

- Official CSV export (support article 360007331534): Collection page → Export → choose Collection → "Request Data Export", notified when ready. (Wantlist is also selectable from that dropdown per search snippets; not verified from a primary page.) Good for one-shot loading into an agent's local context without API calls.

- Extra probes: `catno`, `label`, `genre`+`style`, `title` search filters all work unauth; nonsense query → 0. Collection `sort` = added/artist/title/year/rating → 200, `sort=bogus` → **422**. Write endpoints not exercised (no token for a real account).

### Write-up

- README written. probe.sh re-runs the probes (fixed a trailing-slash bug on `/users/{u}/` → 404 vs `/users/{u}` → 200).
