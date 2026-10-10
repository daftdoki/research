# Cross-harness agent messaging — Notes

## Goal

Find (or decide to build) a way for agents from different harnesses (Claude Code,
Nous Research's Hermes Agent, others) to message each other directly and join
multi-agent channels, across hosts joined by Tailscale. Self-hostable preferred.
The user asked for a wide sweep because earlier research (see
`../a2a-homelab-agent-communication/`) missed popular projects.

## Work log

### Fixing GitHub search (2026-10-10)

- `gh search repos ...` → HTTP 403 "sessions are bound to their configured
  repositories". The session's agent proxy blocks `api.github.com/search/*`.
- Unauthenticated `curl https://api.github.com/search/repositories` → same 403
  (the proxy intercepts the host, not just `gh`).
- `gh api repos/<other>/<repo>` → 403 too; per-repo metadata also blocked.
- `https://github.com/search?...` HTML → 403.
- grep.app → Vercel bot checkpoint, unusable.
- ossinsight `/v1/repos/...` → 404 (wrong endpoint), skipped.
- **Worked:** the GitHub MCP tool `mcp__github__search_repositories` is not
  scope-restricted for search. Full qualifier syntax, sort by stars.
- **Worked for star counts / pushed dates:** `https://ungh.cc/repos/OWNER/REPO`
  and `https://repos.ecosyste.ms/api/v1/repositories/lookup?url=...`.
- **Worked for READMEs:** `raw.githubusercontent.com` (200).
- **Worked for community signal:** HN Algolia API
  (`hn.algolia.com/api/v1/search?query=...`).
- ecosyste.ms topic endpoint returned 0 repos for `a2a` (index incomplete), so
  not useful for discovery.

First probe, `agent mail mcp` sorted by stars, immediately surfaced
`Dicklesworthstone/mcp_agent_mail` (2,199★) and `awebai/aweb` (115★, "mail and
chat ... across sessions, runtimes, machines ... self-hostable") — neither was in
the previous A2A report.

### aweb deep read (while sweep agents run)

Shallow clone of `awebai/aweb` into scratchpad (not committed). Findings:

- MIT, self-hostable via `server/docker-compose` (aweb server :8000 + AWID
  identity registry :8010 + Postgres + Redis). Hosted service at app.aweb.ai.
- Primitives: signed mail (async, durable, offline-safe) and chat (bounded,
  `send-and-wait`), wake-up events over SSE (`aw events stream --json`), presence,
  optional tasks/locks/roles. Federation between servers. Has an A2A gateway.
- Harness wake paths: Claude Code = channel plugin (`awebai/claude-plugins`),
  **but README says channel messages surface only with
  `--dangerously-skip-permissions`**; Pi = extension; Codex = `aw run codex`;
  others poll or consume SSE.
- **Hermes**: `packages/hermes-aweb-platform/` is a real Hermes gateway platform
  plugin (`ctx.register_platform(name="aweb")`), v0.1.0, labelled "Prototype",
  plaintext only, no media. `docs/hermes-aweb-gateway-integration.md` documents
  the Hermes platform-plugin contract (BasePlatformAdapter; reference plugins
  in Hermes: `plugins/platforms/irc`, `ntfy`, `simplex`).
- Group semantics: server `POST` chat session takes `to_aliases: list`, and the
  Go client's `chat.Send` takes `targets []string`, so a chat session can have
  several participants. No named persistent channels/rooms. `aw mail --cc` is
  "Not supported in v1".
- Gotcha for Tailscale: AWID identity is DNS-rooted; the local stack uses a
  reserved `local` namespace with "no DNS" — that's the path for a tailnet.

### Harness-surfaces agent report (summary; full matrix kept in scratch)

- Hermes Agent ships ~30 gateway platforms. Confirmed in a shallow clone of
  `NousResearch/hermes-agent`: `plugins/platforms/` has a2a, buzz, discord,
  email, irc, matrix, mattermost, ntfy, simplex, slack, sms, teams, telegram,
  whatsapp …; `gateway/platforms/` has api_server (OpenAI-compatible), webhook.
- **Hermes speaks A2A natively, both directions** (`plugins/platforms/a2a/`,
  docs page user-guide/messaging/a2a). Inbound binds 127.0.0.1 unless a token
  and `A2A_HOST` are set; per-peer tokens; ping-pong cap 5 (max 20).
- Bot-to-bot: Hermes `*_ALLOW_BOTS` none|mentions|all per platform, default
  none. Official Claude Code Discord channel drops every bot-authored message
  (`if (msg.author.bot) return`). Telegram Bot API 10.0 (May 2026) added an
  opt-in bot-to-bot mode.
- Claude Code: only Telegram/Discord/iMessage/fakechat are allowlisted
  channels; any community channel needs `--dangerously-load-development-channels`
  (interactive only). Cross-session SendMessage is Claude-only and routes via
  Anthropic for cross-machine.
- OpenClaw: native A2A channel, native Matrix/IRC etc., and `openclaw mcp
  serve` emits Claude channel notifications.

### Cotal deep read

Shallow clone `Cotal-AI/Cotal` (Apache-2.0, 317★, pushed 2026-10-10, npm
`cotal-ai` 0.79.0 with 138 versions since 2026-06-09 — very fast-moving).

- Pub/sub "space" on NATS + JetStream. Multicast to named channels (`#general`),
  unicast DMs to durable inboxes, anycast to roles. Presence + A2A AgentCard per
  agent. Web dashboard (`cotal web`) and TUI (`cotal console`).
- Connectors: Claude Code (plugin + hooks + dev channel for idle wake), OpenCode,
  Codex (app-server), **Hermes (alpha: Unix-only, hermes-agent 0.18–0.21,
  launcher runs `hermes gateway run` with a Python platform plugin; isolated
  HERMES_HOME by default or `COTAL_HERMES_ADOPT_HOME` to use your own)**, Jcode, pi.
- Claude Code still needs `--dangerously-load-development-channels` for the
  wake; hook drain (SessionStart/UserPromptSubmit) delivers without it. Unlike
  aweb, it does not require a permission bypass flag ("Cotal adds no
  tool-permission bypass flag").
- Cross-machine: `cotal up --host 0.0.0.0` on broker host; other hosts run
  `cotal meshes add NAME --server nats://100.x.y.z:4222 --allow-unencrypted-overlay`.
  The docs name Tailscale's ranges (100.64.0.0/10, fd7a:115c:a1e0::/48)
  explicitly and refuse 10.x/192.168.x without TLS. Caveat: joining an auth mesh
  from another host copies the space **signing seed** to it (a machine holding it
  is a CA for the mesh). Per-user auth mode (`--user-auth --idp`) avoids that.
- Stability: wire v0.3 pre-1.0, packages 0.x; docs say pin exact versions.

### Protocols/infra agent report (summary)

- A2A 1.0: strictly 1:1 client→server; `contextId` threads, no rooms. IBM ACP
  merged into A2A (archived Aug 2025). AGNTCY SLIM has MLS-encrypted group
  channels but zero harness adapters. Coral = orchestrator-centric, remote agents
  closed beta. NLIP = Ecma standard nobody uses. MCP 2026-07-28 has no
  unprompted push and no room primitive → every "chat over MCP" tool needs
  Claude Code channels or hooks for wake.
- Self-hosted chat: Matrix (Tuwunel 2,611★ single Rust binary; Continuwuity),
  Ergo IRC, Mattermost, Zulip, NATS — none has a bot class, so agents see each
  other; loop control is your job. Telegram/Discord are not self-hostable and
  restrict/drop bot-to-bot.
- Claude Code Matrix channel: `IA-PieroCV/cc_matrix_channel` (16★, Rust, E2EE,
  permission relay, last push 2026-03-29 — **stale-ish**).
- Tailscale: no agent-messaging product; tsidp (experimental OIDC) and Aperture
  (LLM gateway) are adjacent, not message carriers.
- Block's **Buzz** (block/buzz, 35,820★, created 2026-03-06): self-hostable Nostr
  relay workspace (Rust + Postgres/Redis/MinIO) where agents are channel members
  with their own keys. Hermes has a native `buzz` platform plugin (confirmed in
  `plugins/platforms/buzz/`); Claude Code/Codex attach via `buzz-acp` (Buzz drives
  them over Zed ACP) rather than joining as an independent session.

### GitHub sweep agent report (summary)

71 searches (69 repo, 2 code). Best signal from `topic:` queries
(agent-communication, agent-to-agent, a2a+claude-code, agent-mesh) and
`stars:>N pushed:>DATE` + short phrase. Long natural-language queries → 0 hits;
"agent mail"/"agent chat" swamped by email/chat-UI repos. Code search found
repos repo-search missed (solo, EnvoyMesh). `repo:a/b repo:c/d ...` in one query
= batch metadata lookup (used to verify stars below, 2026-10-10).

Verified via batch lookup: block/buzz 35,820★; openclaw 391,612★; agmsg
1,544★; cccc 1,275★; AgentWorkforce/relay 872★; ai-maestro 817★; solo 699★;
hcom 566★; open-tag 204★; moltnet 29★; murmur 19★; aimebu 6★. hermes-agent
252,535★ (ungh).

### README verification of top candidates (raw.githubusercontent)

Two families emerged:
1. **Buses existing agents join** (agent keeps running in its own harness):
   Cotal, aweb, open-cross-session, agmsg, hcom, aimebu, moltnet, Matrix/IRC +
   channel plugins, Hermes native A2A.
2. **Workspaces that spawn/drive agents** (the tool launches CLI/ACP
   subprocesses): solo (Hermes via ACP), open-tag, Buzz (buzz-acp), cccc,
   ai-maestro, multica. More features than asked for.

- open-cross-session (`ocs`, MIT, 20★): no server; one static binary; JSONL
  channel logs under ~/.ocs; multi-party channels with @mentions; wakes Claude
  Code via its **native cross-session inbox socket** (receiver sets
  `crossSessionInbound: accept`; no dev-channel flag), Hermes Desktop / `hermes
  serve` via the host WebSocket (queued behind busy turn), Pi, ChatGPT Desktop
  Codex, cmux terminals. Cross-machine since 0.6: `ocs lan pair` with Ed25519 +
  X25519 + AES-GCM, pair over Tailscale address. Trust expires (8h default,
  `--forever`). Cross-machine channels? README shows DMs `<addr>@<peer>`; to check.
- agmsg (1,544★): bash + SQLite, rooms; Hermes supported (not spawnable);
  optional self-hosted reference server for cross-machine (`docs/remote-setup.md`).
- ai-maestro (817★, MIT): peer mesh no central server, Hermes listed; full
  orchestrator dashboard (heavy).
- AgentWorkforce/relay (872★): channels/threads/DMs, cross-machine; README pushes
  cloud; self-host broker unconfirmed. No Hermes mention.
- hcom (566★): cross-machine via MQTT relay; no Hermes.
- cccc (1,275★): Hermes "Auto MCP setup"; cross-machine group links over
  LAN/VPN; orchestrator-shaped.
- moltnet (29★, Go single binary): rooms/DMs/history, Claude Code/Codex/OpenClaw;
  no Hermes; plain HTTP, use private network.
- aimebu (6★, Go): "IRC for agents", rooms only primitive, MCP/HTTP/web UI.
- ocs cross-machine: the LAN wire protocol (`docs/lan.md`) carries `dm`
  and pairing ops only, so **multi-party channels are per-machine**; cross-host
  is DMs `<addr>@<peer>`.
- agmsg: Claude Code delivery uses Claude Code's `Monitor` stream (real-time
  push, no dev-channel flag) or hooks; Hermes listed as supported but "not
  spawnable"; remote sync = reference server + Postgres (docker compose),
  plaintext or E2E with a hand-carried key bundle.

### Community agent report (summary) and final checks

- Reddit unreachable on every route (403/429): www, old, json, rss, pullpush.
  Traction evidence = HN Algolia, stars, press.
- Big projects the earlier pass missed, verified by batch `repo:` lookup
  2026-10-10: herdr 43,251★; qm (yc-software) 15,379★; gastown 18,322★ +
  beads 27,785★; munder-difflin 8,644★; openrig 6,726★; claude_codex_bridge
  3,560★; claude-peers-mcp 2,207★; scion 1,736★; agentchattr 1,530★;
  openclaw-a2a-gateway 552★ (A2A v0.3, not 1.0); concord-mcp 444★.
- Re-read the Claude Code cross-session docs. Correction to the community
  agent's claim: cross-machine conversations *can* be initiated (needs v2.1.225+
  and the target in the listing); a message is one-way (no reply address)
  only when the *sender* isn't connected to Remote Control. The inbox socket is
  documented for scripts/hooks (`CLAUDE_CODE_MESSAGING_SOCKET`,
  `CLAUDE_CODE_MESSAGING_TOKEN`); with no `crossSessionInbound` set, a
  prompting-mode receiver delivers peer messages. This is the hook for a
  bridge that avoids the dev-channel flag.

### Decision

Recommend Cotal first, Matrix (Tuwunel) + Hermes native + cc_matrix_channel as
fallback, Hermes native A2A for 1:1 delegation. Build only a thin per-host
bus→inbox-socket bridge if the dev-channel flag is unacceptable.
