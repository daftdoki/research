# Discogs Access for AI Agents: Collection, Wantlist, and Catalogue Search

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

How can an AI agent get at Discogs today, and what is it allowed to do there? The focus is on three jobs: reading and editing a user's **collection**, reading and editing their **wantlist**, and **searching and retrieving** catalogue data. The marketplace is out of scope. This report builds on the earlier [Discogs MCP server survey](../discogs-mcp-servers/README.md) from April 2026. That survey compared MCP servers. This one covers the API, auth, limits, and terms underneath them, then updates the server list. ([original prompt](#original-prompt))

## Answer

**The REST API at `api.discogs.com` (v2) is the only sanctioned route for an agent, and it covers all three jobs.** Discogs has no official MCP server and no AI-specific API policy. Every MCP server is a community wrapper around the same REST API.

- **The website is closed to agents.** `www.discogs.com` sits behind a Cloudflare managed challenge, which returns 403 to curl and to fetch tools. robots.txt disallows `/users/`, `/mycollection`, and `/mywantlist`. The Terms of Service ban "data mining, robots, scraping". So browser automation and scraping are out, both technically and contractually.
- **The API is open to agents.** Without a token it allows 25 requests/min. With a personal token it allows 60/min. Pages hold at most 100 items, and a single search returns at most 10,000 results.
  - **Collection:** folders, items, add, move, remove, rate, custom fields, and value.
  - **Wantlist:** list, add, edit (notes and rating), and delete.
  - **Search:** filters for artist, title, label, catalogue number, barcode, format, year, country, genre, and style.
  - The user's own collection value and custom fields need owner auth. A public user's collection and wantlist can be read without any token.
- **Auth is a personal access token (simplest) or OAuth 1.0a.** There is no OAuth 2. MCP servers that offer a browser login (rianvdm, WOIII-me) bridge MCP OAuth 2.1 to Discogs OAuth 1.0a.
- **The terms are the real constraint, not the API itself.**
  - The ToS (Feb 2026) bans *training* AI on Discogs content.
  - The API ToU (May 2025) has no AI clause. It classes collection and wantlist as **Restricted Data**: you may not transfer it to a third party or use it commercially. You may not display any data that is more than **6 hours** older than discogs.com, and you may not cache it longer than you need to.
  - A personal agent working on your own data at your request fits this. A hosted, multi-user, or commercial agent that ships users' collections to an LLM vendor, or that builds a long-lived index from API data, is a grey area. Ask Discogs before building one.
- **For bulk catalogue search, use the monthly CC0 data dumps instead of the API.** The 2026-10-01 releases file is 10.5 GB gzipped XML. The dumps have no rate limits, no 6-hour rule, and no licence restrictions. They contain no user data and no images.
- **MCP update since April:** [rianvdm/discogs-mcp](https://github.com/rianvdm/discogs-mcp) (v3.5.0) **now has wantlist tools**, which closes the main gap the earlier survey found. [cswkim/discogs-mcp-server](https://github.com/cswkim/discogs-mcp-server) is still the broadest token-based option (128 stars). [Spiegelberg/discogs-mcp](https://github.com/Spiegelberg/discogs-mcp) and the read-only [WOIII-me/Discogs-MCP](https://github.com/WOIII-me/Discogs-MCP) are new.

**Recommended setup for a personal collection, wantlist, and search agent:**

1. Use a personal token and a unique User-Agent.
2. Pick one MCP server:
   - **cswkim** for local stdio with the widest typed tool surface.
   - **rianvdm** self-hosted on your own Cloudflare Worker, if you want browser login, mood and recommendation tools, and a 6-hourly cached collection.
3. Optionally load a monthly data dump into a local database for heavy catalogue search.
4. Show "Data provided by Discogs" with links in anything user-facing.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. **Live API probes** from a cloud VM with no token, using a custom User-Agent. They covered rate-limit headers, User-Agent enforcement, search filters and caps, image URLs, and a public user's collection, wantlist, and lists endpoints. To re-run them, use [`probe.sh`](probe.sh) (set `DISCOGS_TOKEN` to compare authenticated behaviour).
2. **Primary documents.** Discogs pages return 403 to non-browser fetchers. Wayback snapshots existed, but the environment's egress policy blocked `web.archive.org`. I read the pages through the `r.jina.ai` reader proxy instead:
   - the [API docs home](https://www.discogs.com/developers) (rate limits, pagination, versioning, client libraries)
   - the [API Terms of Use](https://support.discogs.com/hc/en-us/articles/360009334593-API-Terms-of-Use) (last updated 2025-05-27)
   - the [Terms of Service](https://support.discogs.com/hc/en-us/articles/360009334333-Terms-of-Service) (last updated 2026-02-23)
   - [robots.txt](https://www.discogs.com/robots.txt)
   - the [2014 search-auth announcement thread](https://www.discogs.com/forum/thread/399958)
   - the [collection help article](https://support.discogs.com/hc/en-us/articles/360007331534) (CSV export)

   The docs sub-pages are a single-page app, and the reader proxy only ever returned the home page. Per-endpoint detail therefore comes from the docs' table of contents, the probes, and client and server code.
3. **The data-dump index** at [data.discogs.com](https://data.discogs.com/) (reachable directly) for file sizes and the licence.
4. **MCP server READMEs on GitHub,** re-checked against the April survey, plus web searches for new servers and for any official Discogs AI or MCP statement.
5. **Third-party claims checked against probes.** [api-evangelist/discogs](https://github.com/api-evangelist/discogs) is an "API profile" repo. Several of its claims proved wrong; see Results.

## Results

### Access routes

| Route | Collection | Wantlist | Catalogue search/retrieval | Agent-usable? | Terms |
|---|---|---|---|---|---|
| REST API `api.discogs.com` v2 | ✅ read/write | ✅ read/write | ✅ | ✅ JSON, no bot wall | API ToU |
| Website `www.discogs.com` | (UI) | (UI) | (UI) | ❌ Cloudflare challenge → 403 | ToS bans scraping; robots disallows `/users/`, `/mycollection`, `/mywantlist` |
| Monthly data dumps (data.discogs.com) | ❌ | ❌ | ✅ full catalogue, offline | ✅ plain HTTPS, ~11.7 GB/month gzipped | CC0 |
| CSV export (Collection → Export) | ✅ snapshot | ✅ (dropdown option, per secondary sources) | ❌ | Manual: a human requests it, then gets notified | Personal data |
| Official Discogs MCP / AI API | — | — | — | Does not exist | — |

### API facts that matter to an agent

| Item | Value | Source |
|---|---|---|
| Rate limit | 60/min authenticated, 25/min unauthenticated, moving 60 s window, per source IP/account | Docs; `x-discogs-ratelimit: 25` observed |
| Rate headers | `X-Discogs-Ratelimit`, `-Used`, `-Remaining` | Docs; observed |
| User-Agent | Required. An empty UA gets **403**. Default curl and `python-requests` UAs got 200, contrary to api-evangelist's claim that they are blocked. | Docs; probe |
| Pagination | Default 50, max 100. `per_page=500` is silently clamped to 100. | Docs; probe |
| Search depth | Hard cap of 10,000 results per query: page 201 at 50/page returns 404 "outside of valid range" | Probe |
| Text format | `Accept: application/vnd.discogs.v2.plaintext+json` strips Discogs markup from notes, which is useful for LLM context | Docs |
| Auth | Personal token (`Authorization: Discogs token=…` or `?token=`), consumer key+secret, or OAuth 1.0a (`/oauth/request_token`, `/oauth/access_token`, `/oauth/identity`). No OAuth 2. | Docs ToC; probes (identity returns 401 unauthenticated); joalla client |
| Search without auth | Returned 200 today, but with empty `thumb` and `cover_image`. Discogs has required auth for search since Aug 2014, so don't rely on this. | Probe; forum 399958 |
| Images | `i.discogs.com` URLs are signed; don't edit them. A release-response image URL downloaded fine without auth. api-evangelist's "must be OAuth-signed" claim did not hold. | Docs FAQ; probe |
| Marketplace bleed | Even `/releases/{id}` returns `lowest_price` and `num_for_sale` | Probe |

### Endpoints for the three in-scope jobs

| Job | Endpoints (v2) | Unauthenticated, public user |
|---|---|---|
| Identity | `GET /oauth/identity`, `GET /users/{u}` | identity: 401; profile: 200 |
| Collection: read | `GET /users/{u}/collection/folders`, `…/folders/{id}/releases` (sort by `added`, `artist`, `title`, `year`, `rating`, and others), `…/collection/releases/{release_id}` (is this release in the collection?) | 200 (only the "All" folder is visible) |
| Collection: write | `POST …/folders/{id}/releases/{rid}`, `POST/DELETE …/releases/{rid}/instances/{iid}` (move, rate, remove), folder CRUD, `POST …/fields/{fid}` | Owner token required |
| Collection: private | `GET …/collection/fields`, `GET …/collection/value` | **403** "authenticate as the owner" |
| Wantlist | `GET /users/{u}/wants`, `PUT/POST/DELETE /users/{u}/wants/{release_id}` (notes, rating) | read: 200 |
| Lists | `GET /users/{u}/lists`, `GET /lists/{id}` | 200 |
| Search | `GET /database/search?q=&type=&title=&release_title=&artist=&label=&catno=&barcode=&format=&year=&country=&genre=&style=…` | 200, no images |
| Retrieve | `/releases/{id}`, `/masters/{id}`, `/masters/{id}/versions` (with `filters.applied` and `filters.available` facets), `/artists/{id}[/releases]`, `/labels/{id}[/releases]`, `/releases/{id}/rating[/{user}]` | 200 |

Every search filter in the table, the collection `sort` values (an unknown value returns 422), and the master-versions facets were checked live without a token. The write-endpoint paths follow the standard v2 layout that the MCP servers wrap. They weren't exercised, because that needs a token for a real account.

### Terms that bind an agent

| Clause | Text (abridged) | Effect on an agent |
|---|---|---|
| ToS, AI training | "We strictly prohibit … training a machine learning or artificial intelligence (AI) system using the Service content and … providing archived or cached data sets containing any Service content to another person or entity." | Don't fine-tune on API or site data, and don't hand out cached datasets. Runtime use isn't covered by this clause. |
| ToS, scraping | No "data mining, robots, scraping, harvesting, or similar data gathering and extraction tools". | Rules out browser agents and website scrapers, including Apify "Discogs scraper" MCP actors. |
| API ToU, Restricted Data | Collection and wantlist are "Discogs User Data". You get a "limited, personal, non-sublicensable … revocable license". You may not "transfer Restricted Data to any third party" or use it "for any commercial purposes". | A personal agent on your own data fits. Sending other users' collections to an LLM provider, or charging for the service, is a grey area. |
| API ToU, freshness | You may not display Content "more than six (6) hours older" than discogs.com, or "cache or store the Content longer than is necessary". | Re-sync caches at least every 6 h (rianvdm does exactly this). A permanent vector index built from API data conflicts with this; build it from the CC0 dumps instead. |
| API ToU, rate limits | No circumventing, for example by "creating additional API keys". | Throttle locally. Don't rotate keys or IPs. |
| API ToU, attribution | "Data provided by Discogs." with a followable link next to the data, plus a not-affiliated notice in the docs. | Put it in the agent UI or answer footer. |
| API ToU, charging | "We reserve the right to charge for access … in the future." | A risk to plan for, not a current cost. |
| robots.txt | Blocks `Meta-ExternalAgent` (AI trainer) entirely, with a comment that Meta's AI *answer* fetcher is not blocked. No GPTBot or ClaudeBot rules. | Moot in practice, because Cloudflare blocks non-browser fetches of www anyway. |

### MCP servers (status at 2026-10-04)

| Server | Collection | Wantlist | Search | Auth | Hosting | Change since April |
|---|---|---|---|---|---|---|
| [cswkim/discogs-mcp-server](https://github.com/cswkim/discogs-mcp-server) | ✅ full | ✅ | ✅ | Personal token (OAuth "future release") | Local stdio / HTTP stream, npx, Docker | ~92 → 128 stars. Still no OAuth. |
| [rianvdm/discogs-mcp](https://github.com/rianvdm/discogs-mcp) v3.5.0 | ✅ + stats, mood search, recs | **✅ new** | ✅ (marks owned items) | MCP OAuth 2.1 → Discogs OAuth 1.0a, 7-day session | Self-hosted Cloudflare Worker; 6-hourly KV sync; free tier ≈ 2,000 releases | Wantlist added. README now tells each user to deploy their own Worker, because shared Worker egress IPs drain the per-IP rate budget. |
| [Spiegelberg/discogs-mcp](https://github.com/Spiegelberg/discogs-mcp) (npm `discogs-mcp`, v0.1.2, Aug 2026) | ✅ incl. value | ✅ | ✅ | Personal token or OAuth 1.0a `login` (creds stored 0600 in `~/.config`) | Local npx | New. Also has live marketplace/order write tools; restrict them in your client. |
| [WOIII-me/Discogs-MCP](https://github.com/WOIII-me/Discogs-MCP) ("DIG") | read-only, mood search | — | best-pressing finder | OAuth 2.1 | Public shared Worker or self-hosted | New. Never writes. |
| [michielryvers/discogs-mcp](https://www.nuget.org/packages/discogs-mcp) | via generic request | via generic request | via generic request | Token | .NET tool | Not re-checked |

## Analysis

**Why the API is the only real door.** Discogs has shut the website to automation in two ways: technically, with a Cloudflare challenge, and contractually, with the ToS scraping ban and robots rules over user pages. The API is a different story. It has no bot wall, uses predictable JSON, and documents its limits. So a browser agent that clicks around discogs.com isn't viable for this use case. An MCP server or a direct API client is the way in.

**Rate limits shape the agent design.** At 60 requests/min, paging through a 2,000-item collection at 100 per page takes 20 calls, which is fine. Calling `GET /releases/{id}` for each item to get tracklists and credits takes 2,000 calls, about 33 minutes. Three things follow:

1. The listing endpoints' `basic_information` (title, year, formats, labels, artists, genres, styles) is enough for most agent questions. Fetch full release records only when the agent needs them.
2. Cache, but re-sync within 6 hours to stay inside the ToU.
3. For deep catalogue questions ("every UK pressing on this label"), a local copy of the CC0 dump avoids both the rate limit and the 10,000-result search cap.

The rianvdm README's warning about shared IPs matters here: Discogs throttles per source IP, so a hosted MCP instance shared by many users gives each of them a small share of the budget.

**Unauthenticated access is wider than the docs suggest, but don't rely on it.** Search worked without a token, image URLs downloaded fine, and generic User-Agents were not blocked. All three contradict either Discogs' own 2014 announcement or a third-party profile. These are observations from a single day, and Discogs can tighten enforcement without notice. A token gives 2.4× the rate limit and the image fields, and it costs nothing.

**The terms are where a "personal agent" and a "product" diverge.** For one person pointing Claude, or another assistant, at their own Discogs account, the activity is an app the user runs on their own data at their request. That fits the Restricted Data licence ("personal … to create and run websites and applications"). The ToU was written before LLM agents and doesn't address an LLM provider receiving collection data as context. Whether that counts as "transfer to any third party" is untested. The risk grows with:

- more users (other people's collections),
- commercial use (explicitly barred for Restricted Data),
- persistence (the 6-hour and no-long-term-cache rules).

The CC0 catalogue data (titles, tracklists, credits, identifiers) has none of these limits.

**Choosing an MCP server for the stated focus:**

- **Local and simple, with the widest tool surface:** cswkim. It now covers everything in scope with a personal token, and its `per_page=5` default keeps responses small for LLM context.
- **Browser login and a cached collection with analytics:** rianvdm. With wantlist tools added, its main drawback is that you must deploy and run a Cloudflare Worker yourself.
- **Read-only peace of mind:** WOIII-me. It never writes, but its public instance shares one rate budget, so self-host it if you use it seriously.
- **Spiegelberg** is new and unproven (0 stars). Its marketplace write tools are outside your focus and are live actions, so disable them in the client if you use it.

**Gaps that remain:**

- There is no official Discogs MCP server or agent programme.
- There is no OAuth 2 or scoped tokens: a personal token grants full account access, marketplace included. Read-only behaviour depends on the MCP server, not on the token.
- Search is capped at 10,000 results and has no relevance controls.
- The CSV export is manual, with no API trigger.

## Files

- `README.md`: this report
- `notes.md`: working notes, including dead ends (Cloudflare 403s, blocked Wayback access, SPA docs) and the raw probe observations
- `probe.sh`: re-runs the live API probes (UA enforcement, rate headers, search caps, public collection and wantlist access). Pass a public username, and optionally `DISCOGS_TOKEN`.
- `_summary.md`: index summary for the repo README

## Original Prompt

> Research discogs AI agent access. My focus is on collection, wishlist, and search and retrieval not on marketplace.
