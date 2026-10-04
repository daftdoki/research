# AI agent access to the *arr stack — Notes

## Goal

Find out how an AI agent (Claude Code etc.) can talk to Sonarr, Radarr, SABnzbd
and the rest of the *arr family, and ask a Neckbeard agent what the arrstack on
the host `frame` actually contains.

## Work log

- Branch: `claude/arrstack-ai-agent-access` (session started detached from main).
- `ListAgents` showed no peer sessions on this machine, so the SendMessage
  transport could not reach Neckbeard.
- `list_sessions` (claude-code-remote MCP) showed the Neckbeard sessions run in
  bridge environment `env_01AXySBjPTU1F6AUReA7LNmo`. Most `neckbeard@neckbeard`
  sessions were archived. `neckbeard-dhi` (session_01Ku3YAMLLyxjJcsdWgvzBfR,
  repo daftdoki/agent-neckbeard, branch neckbeard-9301) was idle and connected,
  so I sent it the question with `send_message`. Asked for: services and
  images, deployment/compose path, network layout, existing MCP/agent
  integrations, where API keys live (location only, no values).
- Started a background web-research subagent on native APIs, existing MCP
  servers, other agent routes, and security.
- First message to neckbeard-dhi (22:49 UTC) was not picked up. That session
  was mid-`/sync` with its own user (merge conflict in `.memory/index.md`,
  pushed origin/main 783a0b5) and no event shows it reading my message.
  Resent at ~22:56 with `priority: next` and asked for a send_message reply.

## Web research (background subagent, read and cited)

- Every Servarr app commits an `openapi.json` (Sonarr v3: 162 paths/234 ops,
  31 DELETE; Radarr v3 164/237/30; Lidarr v1; Readarr v1 (retired); Prowlarr
  v1 93/128/13). Auth `X-Api-Key` header or `apikey` query param.
- SABnzbd: `/api?mode=...` with full API key vs NZB key (add only); external
  access levels incl. "API (no config)"; `config_lock`.
- NZBGet has Restricted and Add users. qBittorrent 5.2 adds bearer API keys
  (no evidence they are scoped). Everything else = one unscoped admin key.
- Jellyfin source: "Api keys are unrestricted." Plex token is an account token.
- MCP servers: dozens, none official. Most credible: aplaceforallmystuff/mcp-arr
  (222 stars, no read-only switch, HTTP mode no auth), bardesss/arr-mcp
  (read by default, writes opt-in per service w/ preview+audit, OAuth 2.1,
  covers SABnzbd/qBit/Seerr/Plex/Jellyfin too), vladimir-tutin/plex-mcp-server,
  jaredtrent/jellyfin-mcp (--read-only), jhomen368/overseerr-mcp,
  lodordev/mcp-tautulli (all read-only). yarr (AGPL, read/write scopes, has
  a passthrough that makes write scope = full API).
- OpenAPI→MCP bridges (FastMCP from_openapi + RouteMap EXCLUDE,
  awslabs openapi-mcp-server, mcp-openapi-proxy TOOL_WHITELIST) work with the
  Servarr specs; FastMCP docs warn curated servers beat auto-converted ones.
- Home Assistant MCP Server only exposes Assist entities; Sonarr/Radarr/
  SABnzbd/qBit/Seerr HA integrations are mostly read-only → narrow route.
- Dead ends: wiki.servarr.com/sonarr/api 404; sonarr.tv/docs/api JS-only;
  WebFetch truncated the big openapi.json files and wrongly said there were
  no securitySchemes (local parse showed both); official MCP registry search
  only matches names so "sonarr" returns nothing; no read-only-key feature
  request found for any *arr app; Readarr retirement only via community repost.
- CVEs: CVE-2026-30975 (Sonarr XFF auth bypass, fixed 4.0.16.2944),
  CVE-2026-30976 (Sonarr Windows unauth file read, fixed 4.0.17.2952).
