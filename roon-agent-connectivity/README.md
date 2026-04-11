# Roon Agent Connectivity: MCP and Other Options

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What MCP servers or other agent-connectivity options exist for the Roon music
streaming server, and what's the best path to building an agent that knows
about both digital (Roon) and physical (vinyl / CD) music collections?
([original prompt](#original-prompt))

## Answer

**As of April 2026 there is no Roon MCP server — you have to build one.** The
MCP ecosystem has music-adjacent servers (Apple Music, Audius, a generic local
file "Music Collection MCP") but nothing that talks to Roon.

The good news: Roon has a well-documented extension SDK and a mature community
Python wrapper, so building your own MCP server is a small project. Three
viable paths exist:

| Path | Effort | Library coverage | Notes |
|---|---|---|---|
| **A. Direct MCP server over `pyroon`** (recommended) | small | full | FastMCP + [`roonapi`](https://pypi.org/project/roonapi/) — full browse, search, transport, tags, zones. See `roon_mcp_server.py` in this folder for a skeleton. |
| **B. Home Assistant → Roon integration → HA MCP server** | none (config only) | playback only | HA already has an official Roon integration and an official `mcp_server` integration. You inherit HA's media-player abstraction, which is limited to transport/volume and a basic media browser — no tags, composers, custom hierarchies. |
| **C. Wrap `roon-extension-http-api` in a thin MCP adapter** | small | near-full | Community Node extension that already exposes browse/search/transport/image over HTTP. Fewer SDK dependencies in your MCP server but adds a second service running inside Roon. |

For **physical** collections, Roon has no built-in support. Two realistic
approaches, both of which can live alongside the Roon tools in the same MCP
server:

1. **Convention over Roon tags** — add a `Vinyl` / `CD` tag to albums you own
   physically that already exist in your Roon library (local or streaming).
   Free, dead-simple, but you can't catalog anything that isn't already in
   Roon.
2. **Bridge to Discogs** (or MusicBrainz) — use `python3-discogs-client` with
   an OAuth token to query the user's Discogs collection folders and expose
   them as MCP tools alongside the Roon ones. Lets the agent answer
   "do I own this on vinyl?" and "add this to my wantlist" questions.

**Recommendation:** Build a single FastMCP server that wraps `pyroon` for the
Roon side and `python3-discogs-client` for the physical side, and link the two
worlds by artist+album text (and optionally by MusicBrainz ID where both
systems have one). A working skeleton for the Roon half is in
`roon_mcp_server.py`.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

- Searched GitHub (`roon mcp`, `roon-mcp`, `mcp-roon`), the official
  modelcontextprotocol/servers repo, mcpservers.org, and
  `registry.modelcontextprotocol.io` for any existing Roon MCP server.
- Walked the Roon Labs GitHub org (`RoonLabs/node-roon-api` and its sibling
  service modules) to understand the official extension SDK surface.
- Reviewed community Python work: `pavoni/pyroon` (PyPI `roonapi`) and
  `doctorfree/RoonCommandLine` (41 Python scripts built on pyroon — a great
  feature-coverage map for building MCP tool stubs).
- Looked at HTTP-wrapper extensions (`st0g1e/roon-extension-http-api`,
  `varunrandery/roon-remote`) that turn the SDK into a REST surface.
- Investigated Roon's relationship with Discogs and vinyl collections via
  the Roon community forums.
- Surveyed Home Assistant's built-in Roon integration and HA's MCP server
  options (the official `mcp_server` in HA 2025.2+, plus `voska/hass-mcp`
  and `homeassistant-ai/ha-mcp`).
- Wrote a minimal working FastMCP skeleton in `roon_mcp_server.py` that
  exercises the key pyroon primitives: discovery, token persistence, zones,
  browse, search, playback, volume.

## Results

### What exists today

**Official from Roon Labs:**

- **`RoonLabs/node-roon-api`** — JavaScript/Node SDK. WebSocket-based. This
  is the *only* first-party SDK; there is no Python, Go, or Rust SDK and
  no REST API.
- Modular service packages: `node-roon-api-browse`, `-transport`, `-image`,
  `-status`, `-settings`, `-volume-control`, `-source-control`,
  `-audioinput`.
- Discovery is automatic (`RoonApi.start_discovery()` finds any Core on the
  LAN). Auth is a one-time user approval in Roon's Settings UI; tokens
  persist.

**Community Python:**

- **`pavoni/pyroon`** / PyPI `roonapi` — the de facto Python client.
  Originated as `marcelveldt/roon-hass`, adopted by Greg Dowling (pavoni)
  when he upstreamed the Home Assistant Roon integration. Apache-2.0,
  latest 0.1.6 (Dec 2023). Covers zones, outputs, state subscriptions,
  browse (`browse_browse` / `browse_load`), search, playback, volume,
  grouping, and image URLs.
- **`doctorfree/RoonCommandLine`** — Bash + Python wrapping pyroon. ~41
  single-purpose Python scripts under `api/` (list albums, list artists,
  list genres, list composers, list tags, list playlists, list radio,
  play by album/artist/composer/genre/playlist/tag, now_playing, volume,
  zone grouping/transfer, etc.). Best real-world inventory of what pyroon
  can do.

**Community HTTP wrappers (run as Roon extensions):**

- **`st0g1e/roon-extension-http-api`** — Node extension, exposes browse,
  search, transport, image, and zone ops on `http://host:3001`. No auth;
  LAN-only.
- **`varunrandery/roon-remote`** — small Express app that proxies HTTP →
  the Node Roon SDK's WebSocket.

**Home Assistant:**

- First-party Roon integration — surfaces zones as `media_player` entities
  with transport/volume/media browser. Built on pyroon.
- `mcp_server` built-in integration (since HA 2025.2) and community ones
  (`voska/hass-mcp`, `homeassistant-ai/ha-mcp`) can expose those media
  players to Claude Desktop, Claude Code, Cursor, etc.

**Music MCP servers that exist but are NOT Roon:**

- `gorums/music-mcp-server` — local files only
- `pedrocid/music-mcp` — Apple Music via AppleScript
- Audius MCP — Audius streaming service
- None of these talk to Roon.

### Roon API feature coverage (via `pyroon` / `node-roon-api`)

| Capability | Available? | Notes |
|---|---|---|
| Discover Core on LAN | yes | Auto via `RoonDiscovery` |
| Token-based auth, persisted | yes | One-time user approval in Roon UI |
| List zones / outputs | yes | Including state + now playing |
| Play / pause / next / previous / seek | yes | Per zone |
| Volume, mute, group/ungroup zones | yes | Per zone & per output |
| Browse library hierarchically | yes | Artists, Albums, Genres, Composers, Playlists, Tags, Tracks, Radio |
| Text search across library + streaming | yes | Single unified search |
| Play an album / playlist / tag / radio station by name | yes | via `play_media` |
| Fetch album art, artist photo | yes | Image API returns URLs |
| Read/write custom tags | read yes, write limited | Can list tag contents; tag *editing* is more restricted via the API |
| "Not in library" / wishlist | no | Known Roon limitation |
| Native physical-media catalog (vinyl, CD) | no | Requires tag convention or external source |

### Physical collection landscape

- **Roon tags** are the cheapest path — add a `Vinyl` tag to albums you
  own physically. Caveat: the album must already exist in your Roon
  library. You can't catalog an LP that has no digital equivalent in Roon.
- **Discogs** is the canonical vinyl/CD catalog. API has a Collection
  endpoint with folders (folder 0 = all, folder 1 = Uncategorized,
  2..n = user-created). Python client: `joalla/discogs_client`, package
  `python3-discogs-client`. OAuth 1.0a. Free.
- **MusicBrainz** is the cleanest metadata option and is the most likely
  bridge between Roon and Discogs (shared MBIDs). Python client:
  `musicbrainzngs`. Rate limited to 1 req/s per IP.
- **Soundiiz** offers Roon↔Discogs syncing for playlists/favorites, but
  it's a web UI, not a clean API, so it's not useful for agents.

## Analysis

**Why build instead of reuse?** The MCP server directories confirm no Roon
implementation exists. Roon's own SDK is Node-only and assumes a long-lived
WebSocket client; it doesn't lend itself to "one-shot MCP tool call" usage
without a wrapper. `pyroon` is the practical language choice — it's the same
library Home Assistant's production Roon integration uses, and Python pairs
well with FastMCP.

**Why not just use Home Assistant as a bridge?** HA's MCP server is the
fastest way to get *something* working — if you already run HA, turn on the
Roon integration and the mcp_server integration and you have voice-style
Roon control in Claude within an hour. But HA's media_player abstraction
flattens Roon's rich hierarchy (composers, tags, parallel albums, Roon
Radio seeds) into transport verbs. Good for "pause the kitchen," bad for
"play every Arvo Pärt album I've tagged as 'Sunday morning'."

**Why a combined Roon+Discogs tool surface?** The question you want to ask
the agent is not "play something" — it's "do I own this, where, and can you
play whichever copy is most convenient." That requires the agent to see both
catalogs in one conversation and match them. Putting both behind one MCP
server means:

- A single tool vocabulary for the model.
- A matching helper (`do_i_own(artist, album)`) can check both sources and
  return a unified answer — "yes, you have the CD in Discogs (folder: CDs),
  but not in Roon" or "yes, it's in Roon as a Qobuz stream and you also own
  the vinyl."
- Shared caching / rate-limiting logic (Discogs and MusicBrainz both
  rate-limit; Roon's WebSocket is long-lived and doesn't).

**Matching strategy.** Start with case-insensitive artist+album text
matching; escalate to MusicBrainz ID matching for albums where both Roon and
Discogs have an MBID. For the common case — popular recordings — text is
good enough. For reissues and editions you'll want MBID or Discogs master
release ID.

**What the starter code does and doesn't cover.** `roon_mcp_server.py`
implements the Roon half only: discovery, auth persistence, `list_zones`,
`now_playing`, `search_library`, `list_albums_by_artist`, `list_genres`,
`list_tags`, `play_album`, `control`, `set_volume`. It deliberately omits
Discogs, image fetching, pagination, and error surfacing — add those once
you know which pieces your agent actually uses.

## Files

- `README.md` — this report
- `notes.md` — research work log with more detail
- `roon_mcp_server.py` — minimal FastMCP + pyroon skeleton for a Roon MCP
  server; drop-in starting point for building out a full agent backend

## Original Prompt

> What MCP or other agent connnectivity options exist for the Roon music
> streaming server? I'd like to create an agent that knows about my physical
> and digital music collections.
