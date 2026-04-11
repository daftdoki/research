# Research Notes: Discogs MCP Servers

## Goal

Find MCP servers that expose a user's Discogs **collection** and **wantlist**
(not store/marketplace) so they can be plugged into an interactive agent that
reasons about both physical (Discogs) and digital music holdings.

## Search strategy

1. Web search for "Discogs MCP server", "discogs mcp github collection wishlist",
   "discogs mcp python wantlist 2026".
2. Fetched READMEs / tool catalogs for each concrete project found.
3. Also searched for adjacent music-library MCP servers (beets/local files,
   Rekordbox, Jellyfin) since the user explicitly mentioned wanting the agent to
   also know about digital music.

## Candidates discovered

Three Discogs-focused MCP servers. One broad local-music MCP server. One
Rekordbox MCP server. One Jellyfin MCP server.

### 1. cswkim/discogs-mcp-server  (TypeScript / FastMCP)

- Repo: https://github.com/cswkim/discogs-mcp-server
- Author: Christopher Kim
- Language: TypeScript (99%), framework: FastMCP
- Auth: Discogs **personal access token** (env var). OAuth "planned".
- Distribution: `npx`, local Node, Docker. Node 18+.
- Activity: ~92 stars, 524 commits, 14 releases, latest v0.5.6 (Mar 2026).
  Actively maintained.
- Notable: Default page size reduced from Discogs' 50 → 5 to avoid overwhelming
  clients; large amounts of typed tools.
- **Tool coverage** (from TOOLS.md — the most complete of any server found):
  - User identity: `get_user_identity`, `get_user_profile`, `edit_user_profile`,
    `get_user_submissions`, `get_user_contributions`
  - **Collection** (13 tools): `get_user_collection_folders`,
    `create_user_collection_folder`, `get_user_collection_folder`,
    `edit_user_collection_folder`, `delete_user_collection_folder`,
    `get_user_collection_items`, `add_release_to_user_collection_folder`,
    `delete_release_from_user_collection_folder`,
    `find_release_in_user_collection`, `rate_release_in_user_collection`,
    `move_release_in_user_collection`, `get_user_collection_custom_fields`,
    `edit_user_collection_custom_field_value`, `get_user_collection_value`
  - **Wantlist** (4 tools): `get_user_wantlist`, `add_to_wantlist`,
    `edit_item_in_wantlist`, `delete_item_in_wantlist`
  - Database: `get_release`, `get_master_release`, `get_master_release_versions`,
    `get_artist`, `get_artist_releases`, `get_label`, `get_label_releases`,
    `search`, rating tools
  - Lists: `get_user_lists`, `get_list`
  - Media: `fetch_image`
  - Marketplace + inventory export (not relevant to the user's ask but present)
- **Verdict**: The most feature-complete option. The only server we found with
  both full collection AND full wantlist support as first-class typed tools.

### 2. rianvdm/discogs-mcp  (TypeScript / Cloudflare Workers)

- Repo: https://github.com/rianvdm/discogs-mcp
- Author: Rian van der Merwe
- Language: TypeScript, Cloudflare Workers + Cloudflare Agents SDK +
  `@modelcontextprotocol/sdk`
- Auth: **MCP OAuth 2.1** with Discogs as the identity provider. Browser-based
  authorization flow, 7-day session. Easiest auth UX of any option here.
- Distribution: Self-host on Cloudflare Workers (free tier eligible). Author
  also runs a hosted single-user instance at `discogs-mcp.com`.
- Activity: ~10 stars, 228 commits, 12 releases, latest v3.1.0 (Apr 2026).
  Actively maintained.
- **Tools exposed**:
  - Public: `ping`, `server_info`, `auth_status`
  - Search/DB: `search_collection`, `search_discogs`, `get_release`,
    `get_collection_stats`, `get_recommendations`
  - Collection: `add_to_collection`, `remove_from_collection`, `move_release`,
    `rate_release`
  - Folders: `list_folders`, `create_folder`, `edit_folder`, `delete_folder`
  - Custom fields: `list_custom_fields`, `edit_custom_field`
  - Diagnostics: `get_cache_stats`
- **Wantlist support: NO.** Documentation lists no wantlist tools.
- Unique value: "intelligent mood mapping", collection analytics (genre
  breakdown, decade analysis, format distribution, ratings-aware recs),
  context-aware recommendations. Will Chatham has a blog post (Jan 2026) where
  it analyzed his 753-record collection and gave a "thoughtful, genre-fluid
  collector" personality summary — the post is a decent demo of what this
  server is tuned for.
- **Verdict**: Best "conversational collection critic" out of the box. Cleanest
  auth. But not suitable on its own for the user's ask because it cannot read
  or mutate the wantlist.

### 3. michielryvers/discogs-mcp  (C# / .NET 10, NuGet)

- NuGet: `discogs-mcp` (v0.3.0, released 2026-02-15)
- Author: Michiel Ryvers
- Language: C# / .NET 10
- Auth: `DISCOGS_TOKEN` env var (personal access token). Optional
  `DISCOGS_USER_AGENT`.
- Distribution: `dotnet tool install --global discogs-mcp`, launched via `dnx`.
- Activity: Very small (0 stars, 5 commits, 2 releases, 104 downloads at v0.3.0)
- Design: Deliberately minimal — exposes 4 generic tools that are effectively
  a typed wrapper around the Discogs REST API:
  - `discogs_help` — usage guide
  - `discogs_endpoints` — discover endpoints by category/keyword
  - `discogs_request` — execute any GET/POST/PUT/DELETE against Discogs
  - `discogs_paginate` — fetch multiple pages and concatenate
- Covers all seven Discogs API categories: database, collection, wantlist,
  marketplace, user, lists, inventory — but as raw requests, not as typed
  per-operation tools.
- **Verdict**: Most flexible. Best for an agent that already knows the Discogs
  API well and wants the freedom to call anything. Worst for an LLM that
  benefits from strong per-tool schemas to avoid hallucinating endpoints or
  request bodies.

## Adjacent servers (for the "digital collection" half of the ask)

The user wants an agent that understands both physical **and** digital music.
None of the Discogs MCP servers touch local files, so a companion MCP server is
needed. Options I came across while searching:

### gorums/music-mcp-server  (Python)

- Repo: https://github.com/gorums/music-mcp-server
- Scans local music folders. 10 tools including `scan_music_folders`,
  `get_band_list`, `save_band_metadata`, `advanced_search_albums`,
  `migrate_band_structure`.
- Stores band metadata in `.band_metadata.json` files next to the music.
- 8-type album classification (Album/EP/Live/Demo/Compilation/Single/
  Instrumental/Split), collection analytics.
- Python 3.8+ or Docker.
- This is probably the cleanest pairing with a Discogs MCP server if the user's
  digital music lives as files on disk.

### Rekordbox MCP Server (Dave Henke)

- Python. Reads the Rekordbox DJ database directly and exposes its contents
  over MCP. Relevant only if the user DJs or uses Rekordbox as their digital
  library index.

### zhenyapav/jellyfin_mcp

- TypeScript. Configured via Jellyfin host + API key env vars. Relevant only if
  digital library is served from Jellyfin.

### Not MCP but worth knowing

- **beets** (beetbox/beets) — not MCP itself, but the de-facto Python music
  library manager + MusicBrainz tagger. Could be wrapped in a small MCP server,
  or queried from a custom tool. beets integrates nicely with Discogs via its
  `discogs` plugin, which can also be relevant.

## Aggregator / directory entries seen

- FlowHunt listing for "Discogs MCP Server"
- Apify "canadesk/discogs" actor (paid, $12/mo; page body was truncated so
  couldn't confirm collection/wantlist scope — appears to be a general Discogs
  scraper exposed as MCP)
- Glama MCP directory
- LobeHub, mcp.so listings (mirror cswkim + rianvdm)
- Discogs forum thread 1118574 exists but fetch returned 403 (likely requires
  Discogs login). Worth checking manually if the user wants to see community
  discussion / any official Discogs stance.
- Not present in the official MCP Registry or in `mcpservers.org` featured
  list as of April 2026.

## Key things learned about Discogs API that affect agent design

- Discogs API is rate-limited and historically a bit quirky. cswkim explicitly
  calls out "potential inconsistencies in the Discogs API documentation and
  type-safety limitations across all possible response variations."
- Personal access tokens are the simplest auth path and grant full read/write
  on YOUR account. OAuth is the production-grade path; rianvdm is the only
  server that has implemented it.
- The Discogs API default page size of 50 can overwhelm LLM clients;
  cswkim lowers it to 5. Something to watch for when writing an agent.
- Collection is organized as folders, with custom fields and per-release
  ratings; Wantlist is a flat list of releases (no folders). An agent that
  mirrors this structure will feel natural; one that flattens it will lose
  information.

## Recommendation for the user's "interactive collection agent" goal

1. **Start with cswkim/discogs-mcp-server** as the Discogs side — it's the only
   server that gives the agent first-class access to both the collection AND
   the wantlist, which are the two things the user asked about.
2. If you want the "music critic" / recommendation experience from the start,
   consider running rianvdm/discogs-mcp **alongside** it — both can be
   registered with the same client, and rianvdm's analytics/mood tooling
   complements cswkim's write-oriented tools. (Watch out: both will make API
   calls under their own tokens, so watch rate limits.)
3. Pair with **gorums/music-mcp-server** (or similar) to cover local digital
   files. The agent can then answer "do I already own this on vinyl?" or "move
   everything from my wantlist that I already have as FLAC into a 'digital-
   owned' folder."
4. Long-term: if any of these servers don't quite fit, michielryvers'
   `discogs_request` / `discogs_paginate` shape is a good fallback / escape
   hatch.

## Open questions / things not yet confirmed

- Does the Apify `canadesk/discogs` actor do collection write operations?
  (Page fetch was truncated.)
- Is there an official Discogs-sanctioned MCP server coming? The forum thread
  hinted at community discussion but I couldn't read it.
- None of the servers found offer a combined "collection + wantlist + digital
  files" all-in-one surface. That would likely need to be user-built.
