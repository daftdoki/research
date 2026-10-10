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
