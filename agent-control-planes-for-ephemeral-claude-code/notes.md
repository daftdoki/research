# Notes: agent control planes for ephemeral Claude Code sessions

## Plan

Split into four parallel research tracks (subagents with web search):
1. Paperclip itself: architecture, adapters, and whether an outside session can attach.
2. Comparable orchestrators / "AI company" tools and how agents join them.
3. Centralized review / security / issue services callable from local Claude Code.
4. Protocols and Claude Code features for "join while alive" (MCP, A2A, hooks, plugins, channels, agent mail).

Prior related report in this repo: `a2a-homelab-agent-communication` (A2A vs MCP vs cross-session messaging).

## Track 1: Paperclip (subagent read master source + docs, 2026-09-29)

- MIT, ~94k stars, created 2026-03, latest v2026.916.1 (2026-09-21). Date-based releases, very fast churn (49 migrations in one release, 6k open issues).
- Stack: React UI + Express 5 API + Postgres (embedded by default). "Control plane, not execution plane" (docs/start/architecture.md).
- Concepts: companies > org chart of agents (CEO at root) > issues with atomic checkout (409 on conflict), budgets, board approvals, heartbeats.
- Heartbeat = push-to-wake (schedule / assignment / manual) then agent pulls inbox from API. Adapters: claude_local, codex_local, gemini_local, opencode_local, cursor, process, http, openclaw_gateway, hermes_gateway, plugin adapters.
- Paperclip normally SPAWNS the agent. The `http` adapter lets an external service be woken instead.
- Guest attach route found: *board* credentials, not agent identity.
  - `paperclipai auth login` (browser approval, `auth logout` revokes) or `paperclipai token board create --ttl-days N` (in source cli/src/commands/client/token.ts, NOT in docs).
  - `paperclipai board prompt --agent <reviewer> "..."` creates an issue for that agent and wakes it (source only).
  - Documented: `paperclipai issue create --assignee-agent-id`; assignment triggers heartbeat.
  - `@paperclipai/mcp-server` (BETA since v2026.416.0): ~40 tools over REST, env PAPERCLIP_API_URL / PAPERCLIP_API_KEY / PAPERCLIP_COMPANY_ID. README only describes agent keys; board-key use unverified.
  - `paperclipai agent local-cli <agent>` makes a local session impersonate an EXISTING agent (long-lived key until revoked).
- Doc contradiction: core-concepts says @-mentions wake agents; docs/api/issues.md says they don't.
- Multi-project: many companies per instance, projects with workspaces (cwd or repoUrl) -> one company spans many repos.
- Limits: company-wide visibility, board tokens not company-scoped, no "guest agent" concept.

## Track 2: comparable orchestrators

Surveyed ~27 tools. Most "orchestrators" SPAWN Claude Code (worktree/tmux managers) and can't be joined by an outside session: Claude Squad, Sculptor, Crystal/Nimbalyst, Composio Agent Orchestrator, claude_code_agent_farm, Kiro, MetaGPT, ChatDev. Poor fit.

Can be called from a live session:
- Multica (Apache-2.0 + conditions: no third-party hosting, keep branding): `multica issue create/comment add` CLI with personal token + official Claude Code skill; local daemon drives CLIs.
- mcp_agent_mail: HTTP MCP server; `register_agent` gives each session a memorable identity, inbox, TTL file reservations; `project_key` per repo. Only tool built for ephemeral peers. No issues/review. License not confirmed.
- Hosted-agent-as-tool: Devin remote MCP `https://mcp.devin.ai/mcp`; GitHub MCP `assign_copilot_to_issue`, `request_copilot_review`; Cursor Cloud Agents API `POST /v0/agents` (docs redirected, via forum); Factory Sessions API; Conductor cloud API ("agents outside Conductor just need an API key"); OpenHands Cloud REST; Warp Oz; Tembo API.
- Issue hubs: Linear remote MCP + Cyrus (Apache-2.0, spawns Claude Code per assigned Linear issue). Backlog.md and Task Master are per-repo, not central.
- Dead or sunsetting: Terragon (shut Jan 2026), Crystal (deprecated Feb 2026), Vibe Kanban (sunsetting; its MCP was local-only).
- Claude Code agent teams: one team per session, can't share across sessions -> not a hub.
- Dead end: `paperclip.gxl.ai/mcp` is an unrelated research-paper "Paperclip". Community wizarck/paperclip-mcp (MIT, 95 tools) accepts board OR agent keys.
- Paperclip pattern the subagent proposed: one "laptop-guest" agent identity with a process/http adapter so Paperclip never spawns it; all ad-hoc sessions share that identity. Track 1 found the better route: board keys + `board prompt`, no agent identity needed.

## Track 4: attach protocols and Claude Code features

- MCP 2026-07-28 (final 2026-07-28): removed initialize handshake + Mcp-Session-Id; stateless requests. Good for guests (nothing to tear down).
- Tasks: experimental in 2025-11-25; in 2026-07-28 moved to extension `io.modelcontextprotocol/tasks` (poll `tasks/get`, `tasks/update`). Claude Code MCP docs do NOT mention it (unverified support). BUT Claude Code auto-backgrounds any MCP tool call >2 min (v2.1.212+) and notifies on completion. That is enough for "ask central reviewer, keep working".
- Sampling deprecated in 2026-07-28 -> don't design the hub to borrow the laptop's model. Elicitation replaced by multi-round-trip `input_required`.
- OAuth: DCR deprecated for CIMD. Claude Code supports DCR, CIMD, preset client IDs, `headersHelper`.
- A2A v1.0.0 (Mar 2026), joined AAIF 2026-08-17. No native Claude Code client; bridges are small or archived (GongRzhe archived 2026-03). Use it hub <-> standing agents, MCP for laptop -> hub.
- Hooks: SessionStart (command or mcp_tool; can inject additionalContext). SessionEnd can't block, shares a 1.5 s budget, supports `http` hooks. So: register on start, best-effort deregister on end, hub must expire leases (crash = no SessionEnd, my inference).
- Plugins + org marketplace can be required on every machine -> ship the "guest kit".
- Channels: stdio MCP server declaring `experimental['claude/channel']`, pushes events into the running session. Research preview, needs `--channels` flag, off by default on Team/Enterprise. A channel server that negotiates 2026-07-28 isn't registered.
- Cross-session messaging + Remote Control: only your own sessions. Agent teams: local, one per session.
- Coordination projects: mcp_agent_mail (~2.2k stars, register per session, TTL reservations) closest; Agent-MCP (token join, 60 s idle expiry, max 10 agents); Ruflo (ex claude-flow, federation claims unverified); Beads (Dolt-backed issues, `bd update --claim`; possible repo move unverified); Gas Town (resident-worker model, Witness/lease ideas).
- Anthropic standing side: Managed Agents (beta, sessions over REST+SSE, MCP support); Routines fire API (`POST /v1/claude_code/routines/{id}/fire`, experimental beta header); `claude --cloud`; claude-code-action@v1 on GitHub events.

## Track 3: centralized review / security / issue services

- Three attach patterns, none needs per-session registration: (1) remote MCP + per-user OAuth at user scope; (2) plugin from `claude-plugins-official` (CodeRabbit, Semgrep, Aikido); (3) vendor CLI that calls the cloud (`cr review --agent`, `qodo review`).
- Real server-side delegation (an agent does work, not just data): CodeRabbit, Greptile `trigger_code_review`, Qodo reviewer, Claude Code Review (`@claude review`, `/code-review ultra`), Cursor Bugbot REST (Enterprise, admin key), GitHub MCP `request_copilot_review` / `assign_copilot_to_issue`, Endor Labs `security_review` (Enterprise).
- Data/tools only: Linear, Atlassian Rovo, Plane, Notion, Socket, GitHub alert toolsets. Semgrep/Snyk/Aikido = deterministic scanners.
- Semgrep remote plugin uses fixed `guardian-default` ruleset; org Policies don't apply.
- GitHub remote MCP in Claude Code wants a PAT header -> bad fit for shared managed config.
- Claude Code centralization: `--scope user` (~/.claude.json, all projects); `managedMcpServers` (v2.1.259+, https only, per-user OAuth, users can toggle but not remove); `managed-mcp.json` (exclusive control); allow/deny by serverUrl; managed `extraKnownMarketplaces` + `enabledPlugins`; claude.ai admin-added connectors appear in Claude Code.
- Unverified: Atlassian endpoint (/v1 vs /v2), Snyk local-vs-cloud, Sourcery MCP, "Claude Code Security" status (press only), Endor execution location.
- Harness flagged this subagent's output for settings-JSON shaped text; it was just quoted config examples, treated as data.

## Synthesis

- No product found treats a human-started session as a first-class "guest". Paperclip comes closest via board credentials; mcp_agent_mail is the only one designed for per-session identities, but it only does messaging/locks.
- The gap every hub has to handle itself: SessionEnd isn't reliable -> leases with TTL.
- Recommendation depends on appetite: (A) no hub, just user-scope MCP/plugins; (B) Paperclip as hub with board key; (C) custom hub.
