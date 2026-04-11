# Roon Agent Connectivity Research — Notes

## Goal

Investigate what MCP servers and other agent connectivity options exist for the
Roon music streaming server. The end goal is an agent that knows about physical
and digital music collections and can interact with Roon.

## Plan

1. Search for existing Roon MCP servers on GitHub / registries
2. Review the official Roon API(s) and their capabilities
3. Identify third-party Roon wrappers / integrations in various languages
4. Think about "physical" collection support (vinyl, CDs) — Roon extension
   fields, Discogs integration, etc.
5. Sketch an architecture for building a custom agent

## Work log

### 1. Hunting for an existing Roon MCP server

- Searched GitHub (`"roon" "mcp"`, `"roon-mcp" OR "mcp-roon"`), mcpservers.org,
  the modelcontextprotocol/servers repo, and the registry at
  `registry.modelcontextprotocol.io`. **Nothing exists as of April 2026.**
- The MCP ecosystem does have music-adjacent servers — e.g. a generic
  `music-mcp-server` for local file collections, a Music MCP for Apple Music
  on macOS, an Audius MCP, etc. — but none of these touch Roon.
- The `github/topics/roon` page lists the obvious Roon repos (hifiberry-os,
  node-roon-api, RoonCommandLine, Roon-Display-tvOS, docker-roon, etc.) and
  **none of them are MCP- or LLM agent-related**.
- Bottom line: a Roon MCP server is a greenfield project. If I want one I have
  to build it.

### 2. Official Roon API surface

Roon Labs ships an **extension SDK** rather than a REST API. It's WebSocket-based
and you have to register your application as an "extension" that the user
approves in Roon Settings → Extensions.

- Main repo: `RoonLabs/node-roon-api` (JavaScript only — there is no official
  Python SDK). JSDoc hosted at `https://roonlabs.github.io/node-roon-api/`.
- Discovery: `RoonApi.start_discovery()` watches the LAN for Roon Cores and
  auto-connects — no IP address needed.
- Authorization: token-based. First run the user has to approve the extension
  in Roon's settings UI; tokens persist across restarts.
- Extensions can **use** services provided by Roon, and/or **provide** services
  to Roon.

Services Roon provides to extensions (the ones relevant for an agent):

| Package | Purpose |
|---|---|
| `node-roon-api-browse` | Browse the library hierarchically — artists, albums, genres, composers, playlists, tags, tracks — plus search. Also plays items. |
| `node-roon-api-transport` | Zones, outputs, play/pause/next/prev, seek, volume, group/ungroup zones, zone subscriptions (state changes). |
| `node-roon-api-image` | Fetch album art / artist photos from Roon's media store. |
| `node-roon-api-status`, `-settings`, `-volume-control`, `-source-control` | Mostly for *providing* services (e.g. telling Roon you are a hardware volume knob). |

Services an extension can provide back to Roon (less relevant for an agent):
Status messages, custom Settings screens, hardware volume/source control, ping.

Browse API model: every browse call returns a list of items, and each item has
an `item_key` you use to navigate deeper. You can `refresh_list` from any
level, `pop` back up, or `load` more items for pagination. Search is implemented
as a magic "Search" node at the top level where you supply an input string.
Hierarchies include `browse`, `playlists`, `settings`, `internet_radio`, `albums`,
`artists`, `genres`, `composers`, `search`.

There is **no official REST/HTTP API**. However:

- `st0g1e/roon-extension-http-api` is a community extension that exposes the
  browse, transport, image, and zone APIs over plain HTTP on port 3001
  (default). It runs inside Roon as an extension and has no auth — intended for
  LAN use. Endpoints include `listByItemKey`, `listSearch`, `goUp`, `goHome`,
  `listGoPage`, `getImage`, `getMediumImage`, `group`, `ungroup`, etc.
- `varunrandery/roon-remote` is a tiny Node/Express wrapper that accepts
  RESTful HTTP calls and forwards them over WebSocket to the Core.

These are effectively the same pattern — wrap the official node SDK in
HTTP/REST. Good reference implementations for an MCP server.

### 3. Python / other language wrappers

Roon has no official Python SDK but there is a well-established community
library:

- **`pavoni/pyroon`** (PyPI: `roonapi`, Apache-2.0, latest 0.1.6 Dec 2023).
  Originated as `marcelveldt/roon-hass` and was taken over by Greg Dowling
  (pavoni) when he rolled the Home Assistant integration upstream. This is the
  library the Home Assistant Roon integration uses under the hood.
- Provides `RoonApi` class with: `zones`, `outputs`, `register_state_callback`,
  playback control, browse (`browse_browse`, `browse_load`), search (via
  `browse_browse` with an input), image URLs, and high-level helpers like
  `list_media` and `play_media`.
- `doctorfree/RoonCommandLine` is built on top of pyroon and is essentially a
  reference example of how to script every meaningful Roon operation: play by
  album/artist/composer/genre/playlist/tag, list the same, control zones,
  get "now playing", volume, grouping, etc. Its `api/` folder has ~41
  standalone Python scripts, each one roughly a single Roon API operation —
  perfect seed material for MCP tool definitions.

Other notable integrations:

- **Home Assistant** has a first-party Roon integration that exposes zones as
  `media_player` entities (browse, play, pause, volume, source, group). It
  uses pyroon.
- **Home Assistant's own MCP server** (`mcp_server` built-in, since HA 2025.2;
  plus community ones like `voska/hass-mcp` and `homeassistant-ai/ha-mcp`)
  exposes HA entities to MCP clients. So **one shortcut to a working Roon MCP
  setup is: Roon → HA Roon integration → HA MCP server → Claude**. You lose
  fine-grained library browsing (HA only gives you a `media_player` entity
  with its built-in media browser) but you get zero-code play/pause/volume.
- **`TheAppgineer/roon-extension-manager`** — a manager extension that can
  install/update other community extensions via a Docker-backed registry. Not
  directly relevant but lists other extensions worth knowing about.

### 4. Physical collection support

Roon has no first-party concept of a physical collection. This comes up over
and over on the Roon community forums; Discogs import is one of the most
requested features and has been for years. Workarounds people use today:

- Tag albums you own on vinyl with a custom `Vinyl` tag in Roon. Roon's tag
  system lets you attach arbitrary labels to albums/artists/tracks/composers/
  playlists. Cons: the album has to already exist in your Roon library
  (streaming or local) — you can't tag something that isn't in Roon at all.
- Keep the physical collection in **Discogs** (the de facto database for vinyl
  / CDs / tapes). Their API has a Collection endpoint with folders, and the
  Python client is `joalla/discogs_client` (pkg `python3-discogs-client`),
  OAuth 1.0a, free tier.
- **MusicBrainz** is the other option for metadata (and some people use it as
  their personal catalog). Python client: `musicbrainzngs`. Rate-limited to
  1 req/s per IP.
- `Soundiiz` offers Roon→Discogs and Discogs→Roon playlist/favourite sync as a
  web service, but it's not API-driven and not agent-friendly.

So: for an agent that knows about **both** the digital Roon library and a
physical collection, you really want two data sources stitched together, with
the "bridge" being either (a) matching by artist+album text, or (b) a shared
MusicBrainz ID (Roon stores MBIDs internally for a lot of content; Discogs
releases can be linked to MusicBrainz releases too).

### 5. Architecture for a Roon-aware agent

**Option A — Direct: build a Roon MCP server (recommended).**
Wrap `pyroon` with the Python MCP SDK (FastMCP). Tools to expose:

- `search_library(query, hierarchy?)` → browse search
- `list_albums(artist?|genre?|composer?|tag?)`
- `list_artists(genre?)`
- `list_genres()`, `list_composers()`, `list_tags()`, `list_playlists()`
- `get_album(album_id | artist+title)` → metadata + track list + art URL
- `now_playing(zone?)`
- `list_zones()`
- `play(zone, item_id | artist+album | playlist | tag | radio_station)`
- `play_control(zone, action)` — play/pause/next/prev
- `set_volume(zone | output, level)`
- `group_zones([zones])`, `ungroup_zones(zone)`
- `browse(hierarchy, item_key?)` → generic tree walker for edge cases

Add a second, optional "physical collection" tool surface that queries
Discogs (or a local SQLite cache of the user's Discogs export):

- `list_physical_collection(folder?, format?)`
- `search_physical_collection(query)`
- `do_i_own(artist, album)` → checks both Roon AND Discogs
- `suggest_to_buy(album)` → adds to Discogs wantlist

Pack both surfaces in one MCP server and the agent can reason about "play
Kind of Blue" (digital) and "do I own Kind of Blue on vinyl?" (physical) in
the same conversation.

**Option B — Indirect: Home Assistant as a relay.**
Stand up HA, enable the Roon integration, enable HA's built-in MCP server,
point Claude at it. Gives you play/pause/volume for free. Doesn't give you
rich library browsing or tags. Useful as a quickstart but probably
insufficient for the agent described.

**Option C — HTTP shim reuse.**
Run `roon-extension-http-api` on the Roon host and have an MCP server that is
just a thin translator to those HTTP endpoints. Fewer moving parts than
pyroon+FastMCP, but you inherit its feature set and have to babysit another
Node extension in Roon.

I think **Option A with an optional Discogs surface** is the right call.
pyroon + FastMCP is tiny amount of code, gives you end-to-end control, and
doesn't require running a second service inside Roon.

### Deliverables for this investigation

- README.md summarizing the findings with a recommendation
- A minimal `roon_mcp_server.py` stub showing the FastMCP + pyroon skeleton so
  the reader has a concrete starting point
- This notes.md
