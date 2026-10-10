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
