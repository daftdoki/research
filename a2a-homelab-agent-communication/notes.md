# A2A for homelab agent-to-agent communication: notes

## Goal

Map what the A2A protocol can do for agents on different homelab hosts
(laptop, a team-of-agents host) over Tailscale, with Claude Code as the
main agent runtime. The prompt's examples (an Obsidian agent on the laptop
reachable from a team host) are illustrations, not the scope.

Assumption: "A2A" means the Agent2Agent protocol Google open-sourced in
April 2025 and handed to the Linux Foundation. Verify what "Aperture" is
before writing anything about it.

## Work log

- Started on `claude/unslop-writing-for-agents-skills`, which carries open
  PR #23 on another topic. Branched `claude/a2a-homelab-agents` off
  origin/main instead so this report gets its own PR.
- Checked "Aperture" first. It is Tailscale's LLM API gateway (reverse proxy
  in front of OpenAI/Anthropic/Gemini/OpenAI-compatible APIs) that swaps
  tailnet identity for provider API keys, plus "connectors" that proxy MCP
  servers and HTTP APIs. `tailscale/aperture-cli` launches Claude Code and
  five other coding agents pointed at `http://ai`. So it sits on the
  model-provider side, not the agent-to-agent side. Relevant to the report
  as the credential story for agents on every host, not as A2A transport.
  Sources: tailscale.com/docs/aperture/what-is-aperture, github.com/tailscale/aperture-cli
- Read the spec from `a2aproject/A2A` `docs/specification.md` via `gh api`
  (3618 lines, latest released version 1.0.0, tag v1.0.1 on 2026-05-28;
  v0.3.0 was 2025-07-30). Key facts pulled: 11 core operations
  (SendMessage, SendStreamingMessage, GetTask, ListTasks, CancelTask,
  SubscribeToTask, four push-notification-config ops, GetExtendedAgentCard);
  three bindings (JSON-RPC, gRPC, HTTP+JSON/REST); agent card at
  `/.well-known/agent-card.json` with `supportedInterfaces[]` in preference
  order; task states SUBMITTED/WORKING/COMPLETED/FAILED/CANCELED/REJECTED/
  INPUT_REQUIRED/AUTH_REQUIRED; three update mechanisms (poll, stream,
  webhook push); contextId groups tasks; parts are text/file(raw or url)/
  data; security schemes are apiKey/http/oauth2/oidc/mTLS declared in the
  card, auth itself is "handled at the protocol layer". `A2A-Version`
  header required from clients in 1.0. Push-notification section says
  agents SHOULD reject private IP ranges for webhook URLs (SSRF), which
  matters on a tailnet (100.64.0.0/10 CGNAT is not in that list, but a
  strict SDK may still block it; check a2a-python).
- whats-new-v1.md: enum values went kebab-case -> SCREAMING_SNAKE_CASE,
  ops renamed (message/send -> SendMessage), `kind` discriminators removed,
  ListTasks is new, a2a.proto is now the normative source. So any blog
  post or bridge from 2025 is written against 0.2/0.3 wire format.
- README lists official SDKs: Python (a2a-sdk), Go, JS (@a2a-js/sdk), Java,
  .NET, Rust (a2a-lf). Project is under the Linux Foundation.
- docs/topics/a2a-and-mcp.md: "MCP is vertical, A2A is horizontal".
- Claude Code side, first pass:
  - No native A2A client or server in Claude Code. Searches for "Claude Code
    A2A" turn up third-party wrappers only.
  - `ericabouaf/claude-a2a` (TypeScript, 12 stars, pushed 2026-09-01): A2A
    v1.0 JSON-RPC server (`@a2a-js/sdk` 1.x) wrapping the Claude Agent SDK
    `query()`. Maps A2A contextId -> Claude session_id (persisted to
    `.claude/claude-a2a.sessions.json`), bridges AskUserQuestion and
    permission prompts to TASK_STATE_INPUT_REQUIRED, CancelTask ->
    query.interrupt(). README has a "tailscale serve" section: bind
    127.0.0.1, `tailscale serve --bg 3008`, set publicUrl to the ts.net
    URL, optional `allowedLogins` gate on the `Tailscale-User-Login`
    header. Warns the headers are only trustworthy while the port is
    loopback-only. Says plainly: access = a shell on that cwd.
  - `AmirK-S/a2a-to-mcp` (TypeScript, 1 star, pushed 2026-09-06): the
    other direction. Stateless MCP server (2026-07-28 with tasks
    extension) exposing a2a_discover / a2a_send_message / a2a_get_task /
    a2a_cancel_task for configured A2A v1.0.1 agents. Has a `.mcp.json`
    snippet for Claude Code. No auth on either side. Notes that in
    `claude -p` nobody can answer an elicitation so it cancels the task.
  - `regismesquita/MCP_A2A` (Python, 22 stars) last pushed 2025-05-04, so
    it is on the 0.2 wire format. Dead end for 1.0 agents.
  - `TonPC64/mcp-a2a-bridge` (Python, 0 stars, 2026-09-04) exists; did
    not read further.
  - Bigger gateways that speak both: `agentgateway/agentgateway` (Rust,
    4.8k stars) and `IBM/mcp-context-forge` (Python, 4.5k stars). Need to
    check what "A2A support" means in each.
- Claude Code cross-session messaging (code.claude.com/docs/en/cross-session-messaging):
  ListAgents + SendMessage. Same machine: Unix socket, never Anthropic
  servers. Other machine: "Through Anthropic servers, arriving over that
  machine's Remote Control connection". Needs v2.1.224+, claude.ai login
  (not API key, not Bedrock/Vertex). Plain text only, ~1M char cap,
  `crossSessionInbound` accept/hold/refuse, `isolatePeerMachines`. A
  `claude -p` worker binds an inbox socket and can take messages unattended
  with `crossSessionInbound: accept`. The channel does NOT use the tailnet
  at all for cross-machine. That is the crux for this user: the built-in
  path leaves the LAN; A2A over Tailscale stays on it.
- More Claude Code wrappers: `kanywst/a2acode` (Python, 5 stars, pushed
  2026-09-12): A2A 1.0 server fronting any ACP agent (Zed's Agent Client
  Protocol) via `@zed-industries/claude-agent-acp`; maps tool calls to
  working status updates, diffs to artifacts, permission prompts to
  input-required, session id to contextId; ships a GHCR container and an
  `--auth-token-file` bearer option. `jcwatson11/claude-a2a` (9 stars,
  last push 2026-02) has both server and client MCP tools; did not read.
- Claude Code docs index (llms.txt, 356 lines) has zero hits for a2a /
  agent2agent. Anthropic ships no A2A anything in Claude Code or the
  Agent SDK. Anthropic did a webinar on "MCP and A2A with Claude on
  Vertex AI", which is Google's ADK side.
- Channels (code.claude.com/docs/en/channels): an MCP server that pushes
  events into a running session (`claude --channels plugin:...`).
  Research preview; custom channels need
  `--dangerously-load-development-channels`. Works in `-p`. This is the
  one Claude Code mechanism for "someone outside pokes my running
  session" that does not go through Anthropic servers.
- Agent teams: mailbox is `~/.claude/teams/{team}/inboxes/*.json`,
  "One team per session", teammates are local processes. Single machine.
  Also interactive only (no -p). So "teams on host B" cannot include a
  teammate on host A without something like A2A or messaging.
- Tailscale serve KB (kb/1312): adds `Tailscale-User-Login`,
  `Tailscale-User-Name`, `Tailscale-User-Profile-Pic` for tailnet traffic,
  not Funnel. "These identity headers are not populated for traffic
  originating from tagged devices." Gotcha for the user: if the team host
  is a tagged server node, a login-allowlist on the laptop's agent sees
  no login header. Would need ACL/grants on the source node instead, or a
  bearer token. "best practice to only have the service listen on
  localhost." Requires HTTPS certs enabled on the tailnet.
- Tailscale identity for a tagged caller: read `ipn/ipnlocal/serve.go` in
  tailscale/tailscale. `addTailscaleIdentityHeaders` returns early when
  `node.IsTagged()` (comment dated 2023-06-14). But
  `addProxyForwardedHeaders` always sets `X-Forwarded-For` to the peer's
  tailnet address, and `addAppCapabilitiesHeader` sets
  `Tailscale-App-Capabilities` from `PeerCaps(srcAddr)` with no tagged
  check. So a backend behind serve can (a) `tailscale whois --json
  <X-Forwarded-For>` (the CLI KB says whois returns tags for tagged
  devices and capability grants) or (b) write a grant with
  `src: ["tag:agents"]` and an `app` capability and read the caps header.
  That is the fix for the tagged-node gotcha.
- a2a-python v1.1.4 (2026-09-08, 2.1k stars): implements 1.0 with 0.3
  compat, all three bindings both directions. `push_url_validator.py`
  blocks private/loopback/link-local by resolving the webhook host; the
  default on the request handler is None (off). Checked with Python
  3.14: `100.101.102.103` is_private=False (passes), `fd7a:115c:a1e0::1`
  is_private=True (blocked). MagicDNS names return both, and the
  validator rejects if ANY resolved address is blocked, so a `*.ts.net`
  webhook URL fails the validator if you turn it on. Use the bare
  100.x IP or leave the validator off on a tailnet.
- Official sample agents (a2a-samples/samples/python/agents): adk_*,
  langgraph, crewai, ag2, semantickernel, llama_index, beeai, marvin,
  azureaifoundry_sdk, plus grpc/rest dice agents and a
  headless_agent_auth sample. ADK ships `google.adk.a2a.utils.agent_to_a2a`
  and `RemoteA2aAgent`. a2a-inspector (490 stars) is the debug UI.
- agentgateway README: "A2A Gateway ... capability discovery, modality
  negotiation, and task collaboration". IBM ContextForge lists A2A too.
  Both are more than a homelab needs; noted as the "if it grows" option.
- MCP 2026-07-28 moved long-running tasks into the
  `io.modelcontextprotocol/tasks` extension (tasks/get, tasks/update,
  tasks/cancel, input_required state). That closes part of the gap that
  A2A's task model used to own.
- tsidp (tailscale/tsidp): OIDC/OAuth IdP on the tailnet, implements the
  MCP authorization spec incl. dynamic client registration. Relevant
  because an agent card can declare an openIdConnect scheme pointing at
  it. Experimental.
- Dead ends: `caomyer/claude-code-a2a-multiagent` 404s (repo gone).
  `regismesquita/MCP_A2A` is 0.2-era. The two `gh api` errors this session
  were a 404 on a renamed repo (kanywst/a2claude -> a2acode) and a
  search endpoint miss; nothing worth a memory page.
- Verified before writing: Remote Control doc says a custom
  `ANTHROPIC_BASE_URL` (an LLM gateway such as Aperture) makes Remote
  Control unavailable "even if you sign in with claude.ai" (since
  v2.1.196). That knocks out cross-machine cross-session messaging for
  anyone routing Claude Code through Aperture, which is worth a line in
  the report.
- Advisor corrected one of its own earlier suggestions: an agent card
  cannot declare "tailnet identity" as a security scheme. The scheme
  types are apiKey/http/oauth2/openIdConnect/mutualTLS. Report says so
  and points at tsidp for the OIDC route.
- Wrote README.md. Structure: three-way comparison table up front
  (cross-session messaging vs A2A over tailnet vs MCP over tailnet), then
  spec summary, A2A-vs-MCP, Claude Code participation with the wire
  diagram, eight protocol patterns, Tailscale auth section with the
  tagged-node finding, Aperture, analysis. Dispatched the summarizer
  subagent for `_summary.md`.
- Done-check corrections: read `agent_to_a2a.py` (function is `to_a2a`,
  not `agent_to_a2a`) and confirmed `class RemoteA2aAgent(BaseAgent)`.
  Re-read a2acode's README on permissions: every permission request goes
  to the caller as `input-required`; there is no bypassPermissions mode.
  Fixed both sentences in the README. `gh pr checks 24` reports no
  checks on the branch.
