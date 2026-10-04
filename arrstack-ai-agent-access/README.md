# AI agent access to Sonarr, Radarr, SABnzbd and the rest of the *arr stack

## Question / Goal

How can an AI agent such as Claude Code read and drive the popular self-hosted
media apps (Sonarr, Radarr, SABnzbd and their kin: Lidarr, Readarr, Prowlarr,
Bazarr, NZBGet, qBittorrent, Seerr/Overseerr, Plex, Jellyfin, Tautulli)? What
APIs do they expose, which MCP servers already exist, and how do you keep an
agent from deleting a library? Part of the brief was to ask a Neckbeard agent
what the arrstack on the host `frame` contains. See the
[Original Prompt](#original-prompt).

## Answer / Summary

- **Every app already has an HTTP API that an agent can call with one key.**
  - Sonarr, Radarr, Lidarr, Readarr and Prowlarr each commit an OpenAPI spec to
    their repo. Seerr/Overseerr, Plex and Jellyfin publish specs too.
  - SABnzbd, NZBGet, qBittorrent, Tautulli and Bazarr have documented APIs, but
    none of them commits a spec. Bazarr builds a Swagger page when it runs.
- **There are dozens of community MCP servers and no official one.** For a
  stack like this, the best fit is **[bardesss/arr-mcp](https://github.com/bardesss/arr-mcp)**.
  - It covers Sonarr, Radarr, Prowlarr, Bazarr, SABnzbd, qBittorrent, Seerr,
    Plex and Jellyfin.
  - Reads are on by default. Writes are off until you turn them on for each
    service, and each write shows a preview and goes into an audit log.
  - Clients authenticate with a bearer token or OAuth 2.1.
  - **[aplaceforallmystuff/mcp-arr](https://github.com/aplaceforallmystuff/mcp-arr)**
    is the most popular (222★, in the official MCP registry). It has no
    read-only switch, and its HTTP mode has no authentication.
- **The real constraint is that the keys are not scoped.**
  - The Servarr apps, Bazarr, Jellyfin, Tautulli and Seerr each have one API
    key with full admin rights. Sonarr's spec alone has 31 DELETE operations.
  - Only the download clients offer limited credentials. SABnzbd has an NZB key
    that can only add jobs and an "API (no config)" access level. NZBGet has
    Restricted and Add-only users.
  - Any limit on what an agent can do therefore has to live in the MCP server's
    tool set, in a reverse proxy, or in the client's approval prompts.
- **What runs on `frame` is still unknown.** I asked a Neckbeard session twice.
  The message reached its queue, but that session reads its queue only when
  its own user starts a turn, so no answer came back.
  [What's on frame](#whats-on-frame-pending) lists what to ask.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. **Web research.** A research subagent read each app's docs and source.
   - It parsed the committed `openapi.json` and `*-api.yml` files locally to
     count operations and confirm the auth schemes. WebFetch truncates these
     large files.
   - It searched GitHub, npm, PyPI, the official MCP registry, Glama, mcp.so,
     Smithery and awesome-mcp-servers for MCP servers.
   - It read the docs for the generic bridge tools, Home Assistant, n8n and the
     client libraries.
   - Nothing was installed.
2. **Asking Neckbeard.** `ListAgents` found no peer sessions on this machine.
   - The claude-code-remote `list_sessions` call showed the Neckbeard sessions
     run in a bridge environment.
   - `neckbeard-dhi` (repo `daftdoki/agent-neckbeard`) was connected and idle,
     so I sent the question there with `send_message`. I sent it at 22:49 UTC
     and again at 22:57 UTC.
   - I read its transcript with `list_events` at 22:54 and 23:09 UTC.

## Results

### Native APIs

| App | API / base path | Auth | Spec | Limited credential? |
|---|---|---|---|---|
| Sonarr v4 | REST `/api/v3` (234 ops, 31 DELETE) | `X-Api-Key` header or `apikey` query | [openapi.json](https://raw.githubusercontent.com/Sonarr/Sonarr/v5-develop/src/Sonarr.Api.V3/openapi.json) | No |
| Radarr | REST `/api/v3` (237 ops, 30 DELETE) | same | [openapi.json](https://raw.githubusercontent.com/Radarr/Radarr/develop/src/Radarr.Api.V3/openapi.json) | No |
| Lidarr | REST `/api/v1` (235 ops) | same | [openapi.json](https://raw.githubusercontent.com/Lidarr/Lidarr/develop/src/Lidarr.Api.V1/openapi.json) | No |
| Readarr (retired) | REST `/api/v1` | same | [openapi.json](https://raw.githubusercontent.com/Readarr/Readarr/develop/src/Readarr.Api.V1/openapi.json) | No |
| Prowlarr | REST `/api/v1` (128 ops), plus Newznab/Torznab feeds | same | [openapi.json](https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/src/Prowlarr.Api.V1/openapi.json) | No. The key also guards indexer credentials. |
| Bazarr | Flask-RESTX `/api` | `X-API-KEY` header or `apikey` | Swagger page built at runtime ([source](https://raw.githubusercontent.com/morpheus65535/bazarr/master/bazarr/api/utils.py)) | No |
| SABnzbd | `/api?mode=…&output=json` | `apikey` | [wiki](https://sabnzbd.org/wiki/configuration/5.1/api) | **Yes.** NZB key adds jobs only. Access levels include "API (no config)", and `config_lock` blocks config changes. |
| NZBGet | JSON-RPC / XML-RPC | HTTP Basic | [docs](https://nzbget.com/documentation/api/) | **Yes.** Restricted user and Add user. |
| qBittorrent | `/api/v2/...` | `SID` cookie from login. 5.2 adds bearer API keys. | [wiki](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0)) | No scoping found |
| Seerr / Overseerr | REST `/api/v1` | `X-Api-Key` or session cookie | [seerr-api.yml](https://raw.githubusercontent.com/seerr-team/seerr/develop/seerr-api.yml) | No. The key acts as the admin user. |
| Plex | REST/XML on :32400 | `X-Plex-Token`, an account token | [developer.plex.tv](https://developer.plex.tv/pms/) | No |
| Jellyfin | REST | `Authorization: MediaBrowser Token=…` and others | [OpenAPI](https://api.jellyfin.org/openapi/) | No. The source says "Api keys are unrestricted". |
| Tautulli | `/api/v2?cmd=…` | `apikey`, or the `X-Api-Key` header from 2.18 | [wiki](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference) | No. Exposes `delete_*` commands. |

The Servarr key is `ApiKey` in `config.xml` in each app's data folder. It can be
overridden by an environment variable such as `SONARR__AUTH__APIKEY`
([wiki](https://wiki.servarr.com/sonarr/environment-variables)).

### MCP servers worth considering

| Server | Apps | Writes | Transport / auth | Notes |
|---|---|---|---|---|
| [bardesss/arr-mcp](https://github.com/bardesss/arr-mcp) | Sonarr, Radarr, Whisparr, Prowlarr, Bazarr, Jellyfin, Plex, Seerr, SABnzbd, Transmission, qBittorrent, Profilarr | Off by default, turned on per service, with preview, confirmation and audit log | HTTP :6060, bearer or OAuth 2.1 with scopes | 72★, MIT, Docker image, in registry, v1.10.0 |
| [aplaceforallmystuff/mcp-arr](https://github.com/aplaceforallmystuff/mcp-arr) | Sonarr, Radarr, Lidarr, Prowlarr | Add, update, delete queue items, search. No read-only mode. | stdio, or HTTP on 127.0.0.1 with **no auth** | 222★, MIT, npm `mcp-arr-server` |
| [dinglebear-ai/yarr](https://github.com/dinglebear-ai/yarr) | Servarr, Tautulli, Seerr, Bazarr, SABnzbd, qBittorrent, Plex, Jellyfin | `yarr:read` and `yarr:write` scopes. The write scope includes a raw API passthrough. | stdio or HTTP, bearer or OAuth | AGPL-3.0, Rust, also a CLI |
| [jaredtrent/jellyfin-mcp](https://github.com/jaredtrent/jellyfin-mcp) | Jellyfin | `--read-only` and `--disable-destructive` flags | stdio, or HTTP with a token | MIT, Go |
| [vladimir-tutin/plex-mcp-server](https://github.com/vladimir-tutin/plex-mcp-server) | Plex | Includes deletes and metadata edits | stdio or SSE, optional OAuth | 149★, MIT, PyPI |
| [jhomen368/overseerr-mcp](https://github.com/jhomen368/overseerr-mcp) | Seerr / Overseerr | Request, approve, decline, delete | stdio or HTTP | MIT, in awesome-mcp-servers |
| [lodordev/mcp-tautulli](https://github.com/lodordev/mcp-tautulli) | Tautulli | None. All 19 tools are read-only. | stdio | MIT, PyPI |

The [notes](notes.md) list about 30 more single-app servers. Some are generated
from the whole spec (rollecode/sonarr-mcp exposes all 234 operations), and most
have little activity.

### Other routes

- **Generic bridges from an OpenAPI spec to MCP.** You can point a bridge at a
  Servarr spec and allow only GET routes:
  - [FastMCP `from_openapi`](https://gofastmcp.com/integrations/openapi) with
    `RouteMap(... MCPType.EXCLUDE)`.
  - [mcp-openapi-proxy](https://pypi.org/project/mcp-openapi-proxy/) with
    `TOOL_WHITELIST`.
  - [awslabs openapi-mcp-server](https://github.com/awslabs/mcp/tree/main/src/openapi-mcp-server)
    with `INCLUDE_TAGS`.

  FastMCP's own docs warn that hand-curated servers work better with models.
- **Home Assistant.** The [MCP Server integration](https://www.home-assistant.io/integrations/mcp_server/)
  exposes only the entities you have exposed to Assist. The
  [Sonarr](https://www.home-assistant.io/integrations/sonarr/),
  [Radarr](https://www.home-assistant.io/integrations/radarr/),
  [SABnzbd](https://www.home-assistant.io/integrations/sabnzbd/),
  [qBittorrent](https://www.home-assistant.io/integrations/qbittorrent/) and
  [Seerr](https://www.home-assistant.io/integrations/overseerr/) integrations
  mostly provide sensors and read actions. This is the narrowest ready-made
  route.
- **Libraries, CLIs and skills.** An agent can also work from a shell:
  - [pyarr](https://github.com/totaldebug/pyarr) (PyPI says MIT, GitHub says
    CC BY-NC-SA).
  - [ArrAPI](https://github.com/Kometa-Team/ArrAPI) and qbittorrent-api.
  - The yarr CLI.
  - Claude Code skills such as
    [jmagar/claude-homelab](https://www.claudepluginhub.com/marketplaces/jmagar-claude-homelab).
- **n8n.** The [MCP Server Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger/)
  turns workflows into tools. Only community nodes exist for these apps.

### What's on frame (pending)

No answer yet. The question sits in the `neckbeard-dhi` session's notification
queue (queued 2026-10-04 22:57 UTC). That session reads its queue only when its
own user starts a turn. To finish this section, tell that session to read its
notifications, or ask any Neckbeard session:

1. Every service in the arrstack, with its image and tag.
2. How the stack is deployed (compose path, Container Station or
   homelab_stacks) and the network layout (ports, reverse proxy, Tailscale,
   VPN).
3. Any existing MCP or agent integrations, and where the API keys live
   (location only).
4. Anything unusual.

## Analysis

- **What to pick.** For a typical homelab stack with SABnzbd and Seerr on the
  tailnet, run bardesss/arr-mcp in a container next to the apps.
  - Leave it read-only at first, then turn on writes per service as needed,
    starting with "add series/movie" and Seerr requests.
  - It is the only multi-app server that has opt-in writes, its own
    authentication and an audit trail.
  - It is young (created 2026-08, 72★), so pin a version.
- **Limits must live outside the apps.** None of the apps can issue a read-only
  key, and I found no feature request for one. The limits have to come from
  other layers:
  - **The MCP server.** Use a server whose tool list has no delete tools, or
    turn those tools off.
  - **A reverse proxy.** Allow GET plus a few named POSTs, and block DELETE,
    PUT and `/api/v3/command`. No project documents this; it is my own
    suggestion.
  - **The client.** Keep approval prompts on for write tools.
  - **The download clients.** Use the SABnzbd NZB key or the "API (no config)"
    level, and NZBGet's Restricted user.
- **Network exposure matters more than the agent.** Two Sonarr CVEs from 2026
  each had a fix (sources in the notes):
  - CVE-2026-30975: a spoofed `X-Forwarded-For` header bypassed auth for local
    addresses. Fixed in 4.0.16.2944.
  - CVE-2026-30976: an unauthenticated file read on Windows. Fixed in
    4.0.17.2952.

  Keep the apps on the tailnet, set authentication to Required, and send keys
  in the header rather than as a query parameter, which ends up in logs.
- **Caveats.**
  - Star counts and versions are a snapshot from 2026-10-04.
  - Readarr's retirement comes from a community repost, not an official page.
  - Nothing was tested against real instances.

## Files

| File | Purpose |
|---|---|
| `README.md` | This report |
| `notes.md` | Work log: searches, dead ends, the Neckbeard messaging attempts |
| `_summary.md` | One-paragraph summary for the repo index, written by the summarizer subagent |

## Original Prompt

> Research AI agent access for the popular apps sonarr, radarr, sabnzbd and their ilk. Messsage a Neckbeard agent to learn what the arrstack on frame contains.
