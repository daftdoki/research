# Discogs MCP Servers for a Collection + Wantlist Agent

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What MCP servers exist for working with a Discogs **collection** and
**wantlist** (ignoring store / marketplace functionality), and which is the
best foundation for an interactive agent that also knows about a user's
digital music library? ([original prompt](#original-prompt))

## Answer

Three Discogs MCP servers are worth knowing about, and only **one** of them
(`cswkim/discogs-mcp-server`) gives an agent first-class access to *both* the
collection and the wantlist. The others are still useful but have gaps.

| Server | Lang / Runtime | Auth | Collection | Wantlist | Notes |
|---|---|---|---|---|---|
| [cswkim/discogs-mcp-server](https://github.com/cswkim/discogs-mcp-server) | TypeScript / FastMCP (Node, Docker, npx) | Personal access token | Full (13 tools incl. folders, custom fields, ratings, value) | **Full (4 tools)** | Most complete. ~92 stars, actively released. OAuth "planned". |
| [rianvdm/discogs-mcp](https://github.com/rianvdm/discogs-mcp) | TypeScript / Cloudflare Workers | **MCP OAuth 2.1** (browser flow, 7-day session) | Yes (add/remove/move/rate, folders, custom fields) + analytics + mood-based recommendations | **None** | Cleanest auth UX. Best "music critic" tone out of the box. Self-host on Cloudflare Workers free tier, or use the author's single-user `discogs-mcp.com`. |
| [michielryvers/discogs-mcp](https://www.nuget.org/packages/discogs-mcp) (NuGet) | C# / .NET 10 | Personal access token | Yes, via generic `discogs_request` | Yes, via generic `discogs_request` | Exposes only 4 generic tools (`help`, `endpoints`, `request`, `paginate`) — thin wrapper over the whole REST API. Maximum flexibility, minimum LLM ergonomics. Very low adoption. |

**Recommendation for the "interactive collection agent" goal:**

1. Base the agent on **cswkim/discogs-mcp-server** — it is the only server with
   strongly-typed collection *and* wantlist tools, which is what the prompt
   actually asks for.
2. Optionally also register **rianvdm/discogs-mcp** with the same client for
   its mood-mapping and recommendation tools (they complement cswkim's more
   CRUD-oriented surface).
3. Pair either one with a local-music MCP server such as
   [`gorums/music-mcp-server`](https://github.com/gorums/music-mcp-server)
   (Python, scans local folders, 8-type album classification, analytics) to
   cover the "digital" half of the collection. None of the Discogs-specific
   servers touch local files.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Web searches for "Discogs MCP server", "discogs mcp github collection
   wishlist", and related queries.
2. Fetched each candidate repo's README and (where available) `TOOLS.md` /
   tool listing to verify collection and wantlist coverage.
3. Checked activity signals: stars, commits, latest release, issue count.
4. Sanity-checked against the official MCP registry, `mcpservers.org`, Glama,
   LobeHub, FlowHunt, and a Discogs forum thread (the forum thread returned
   403 without login).
5. Broadened to adjacent music-library MCP servers because the user
   explicitly wanted the agent to also know about digital music.

No code was run — this was a pure survey of existing projects.

## Results

### cswkim/discogs-mcp-server — most complete

- **Runtime:** Node 18+, TypeScript, built on [FastMCP](https://github.com/punkpeye/fastmcp).
- **Install:** `npx`, local Node clone, or Docker.
- **Auth:** `DISCOGS_TOKEN` env var (personal access token). OAuth is on the
  roadmap but not shipped.
- **Collection tools (14):** `get_user_collection_folders`,
  `create_user_collection_folder`, `get_user_collection_folder`,
  `edit_user_collection_folder`, `delete_user_collection_folder`,
  `get_user_collection_items`, `add_release_to_user_collection_folder`,
  `delete_release_from_user_collection_folder`, `find_release_in_user_collection`,
  `rate_release_in_user_collection`, `move_release_in_user_collection`,
  `get_user_collection_custom_fields`, `edit_user_collection_custom_field_value`,
  `get_user_collection_value`.
- **Wantlist tools (4):** `get_user_wantlist`, `add_to_wantlist`,
  `edit_item_in_wantlist`, `delete_item_in_wantlist`.
- **Database:** `search`, `get_release`, `get_master_release`,
  `get_master_release_versions`, `get_artist`, `get_artist_releases`,
  `get_label`, `get_label_releases`, plus per-user rating tools.
- **Lists / media / marketplace / inventory export:** also present; marketplace
  and inventory are out of scope for the user's ask but can be ignored by the
  agent.
- **Gotcha:** default `per_page` is lowered from Discogs' 50 → 5 so that large
  responses don't blow up an LLM context window. The agent can request more
  when it needs to.
- **Activity:** ~92 stars, 524 commits, 14 releases, latest v0.5.6 (Mar 2026),
  MIT licensed.

### rianvdm/discogs-mcp — best auth + vibe/recommendation UX

- **Runtime:** TypeScript on **Cloudflare Workers**, using the Cloudflare
  Agents SDK and `@modelcontextprotocol/sdk`.
- **Install:** Self-host on Cloudflare Workers (free tier works), or use the
  author's public single-user `discogs-mcp.com`.
- **Auth:** MCP OAuth 2.1 with Discogs as IdP — the only one of these servers
  with a real browser authorization flow. Sessions last 7 days.
- **Tools:** `ping`, `server_info`, `auth_status`, `search_collection`,
  `search_discogs`, `get_release`, `get_collection_stats`, `get_recommendations`,
  `add_to_collection`, `remove_from_collection`, `move_release`, `rate_release`,
  `list_folders` / `create_folder` / `edit_folder` / `delete_folder`,
  `list_custom_fields`, `edit_custom_field`, `get_cache_stats`.
- **No wantlist tools at all** — if the user wants the agent to add things to
  their wantlist, this server can't do it.
- **Unique value:** "intelligent mood mapping", genre/decade/format analytics,
  rating-aware recommendations, 7-day auth session. Will Chatham's
  [blog post](https://blog.willchatham.com/2026/01/04/discogs-mcp-server/)
  walks through having it describe his 753-record collection and is a fair
  demo of what it's tuned for.
- **Activity:** ~10 stars, 228 commits, 12 releases, latest v3.1.0 (Apr 2026).

### michielryvers/discogs-mcp — thin REST wrapper

- **Runtime:** C# / .NET 10, distributed as a `dotnet tool` on NuGet.
- **Install:** `dotnet tool install --global discogs-mcp`, launched through
  `dnx`.
- **Auth:** `DISCOGS_TOKEN` env var, optional `DISCOGS_USER_AGENT`.
- **Tools (only 4):**
  - `discogs_help` — usage guide
  - `discogs_endpoints` — discover endpoints by category/keyword
  - `discogs_request` — execute any GET/POST/PUT/DELETE against Discogs
  - `discogs_paginate` — fetch multiple pages and concatenate
- Covers all seven Discogs API categories (database, collection, wantlist,
  marketplace, user, lists, inventory) but only as raw HTTP — the LLM has to
  construct the right endpoint URLs and bodies.
- **Activity:** very new and small (0 stars, 5 commits, 2 releases, ~100 NuGet
  downloads), v0.3.0 Feb 2026.

### Adjacent servers for the "digital music" half

- **[gorums/music-mcp-server](https://github.com/gorums/music-mcp-server)** —
  Python, scans local music directories, 10 tools including
  `scan_music_folders`, `get_band_list`, `advanced_search_albums`,
  `save_band_metadata`, `migrate_band_structure`. 8-type album classification,
  stores metadata in `.band_metadata.json` sidecars. Docker or Python 3.8+.
  This is the most natural pairing if the digital library lives on disk.
- **Rekordbox MCP Server** (Dave Henke) — Python, reads the Rekordbox DJ
  database directly. Only relevant if the user is a DJ.
- **zhenyapav/jellyfin_mcp** — TypeScript, env-configured with Jellyfin host
  and API key. Only relevant if the digital library is on Jellyfin.
- **[beets](https://github.com/beetbox/beets)** — not MCP itself but the
  de-facto music library manager + MusicBrainz tagger in the Python world.
  Has a built-in Discogs plugin. Would need a thin MCP wrapper to plug in.

### Directories / listings inspected but not individually useful

- FlowHunt, Glama, LobeHub, mcp.so, dxt.so — all mirror the two GitHub projects
  above.
- Apify `canadesk/discogs` actor (paid, $12/mo) — page body was truncated so I
  couldn't verify whether it supports collection writes; looks more like a
  general Discogs scraper than a collection agent backend.
- Official MCP registry (`registry.modelcontextprotocol.io`) and
  `mcpservers.org` featured list — no Discogs entry as of April 2026.
- Discogs forum thread 1118574 — fetch blocked (403). Worth checking manually
  for any official Discogs stance.

## Analysis

**Why cswkim wins on surface area.** Discogs splits a user's "stuff" into two
separate API trees: the collection (with folders, ratings, and custom fields)
and the wantlist (a flat list). A prompt like "move everything on my wantlist
that I already own on vinyl into a 'wanted→owned' folder" touches both trees
plus folder management. cswkim is the only server that exposes all three
cleanly as typed tools, so the agent doesn't have to invent endpoint paths.

**Why rianvdm still matters.** The OAuth 2.1 flow is materially nicer than
pasting a token into an env var, especially if the agent will be shared or
run in a hosted context. And `get_recommendations` + the mood-mapping work is
the closest any of these projects get to the "interactive collection critic"
experience the prompt hints at. Its missing wantlist support is the main
thing holding it back — if the author adds those tools, it likely becomes the
default choice.

**Why michielryvers is the escape hatch, not the default.** Four generic
tools is great for a human who knows the Discogs API but rough for an LLM —
the model has to remember endpoint shapes and quirks, and the Discogs API
docs are known to be a little inconsistent (cswkim's own README calls this
out). Keep it in mind if one of the typed servers is missing something the
agent needs.

**Gaps that any real agent will hit.**

- **Rate limits.** Discogs rate-limits aggressively and the typed servers do
  not all implement robust backoff. Watch out when the agent starts looping
  over a large collection.
- **Pagination.** The Discogs default of 50 items per page is too large for
  LLM contexts; cswkim already lowers this. An agent that wants to "look at
  the whole collection" needs to page thoughtfully or ask for summaries.
- **Typing quirks.** Discogs API responses are not perfectly consistent; both
  servers concede type-safety gaps.
- **No combined digital + physical surface.** None of these servers integrate
  local files. A combined agent will need to register at least two MCP
  servers (one Discogs, one local-music) or a custom aggregator.

**What I'd actually build.** Start with cswkim/discogs-mcp-server + a local
music MCP server (gorums or a thin beets wrapper). Point a Claude Desktop
(or similar MCP client) at both. Add rianvdm alongside if/when you want the
recommendation/mood layer — both can coexist in the same client.

## Files

- `README.md` — this report
- `notes.md` — raw research notes, per-server details, open questions

## Original Prompt

> What MCP servers exist for working with a Discogs music collection? I don't
> care about store or merchant functionality, just mostly collections and wish
> lists. I'd like to ultimately create an interactive collection agent that
> knows about my digital and physical music collection
