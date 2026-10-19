# Agent Control Planes That a Short-Lived Local Claude Code Session Can Plug Into

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Which products are like [Paperclip](https://github.com/paperclipai/paperclip), and which of them let a Claude Code session you started on your laptop connect to their agents while the session is running, without the session becoming a permanent member? The goal is to keep working as a developer in local Claude Code, while issue management, code review and security agents live in one central place that serves every project. ([original prompt](#original-prompt))

## Answer

**No product treats a human-started session as a first-class "guest." You can still get the pattern today, in one of three ways. They range from no hub at all to a hub you build yourself.**

1. **No hub (least work).** Set up hosted review, security and issue services once, at user scope or through managed settings, as remote MCP servers or plugins. Every Claude Code session in every repo then gets them, and nothing is registered per session. A few of these services actually hand the work to an agent on the vendor's side:
   - CodeRabbit
   - Greptile's `trigger_code_review`
   - Qodo
   - GitHub MCP's `request_copilot_review` and `assign_copilot_to_issue`
   - Devin MCP
   - Anthropic's own Claude Code Review (`/code-review ultra`, or `@claude review` on a PR)
2. **Paperclip as the hub (closest to what you described).**
   - How to connect: Paperclip normally *spawns* its agents. A local session can instead connect with a **board (human operator) credential** instead of an agent identity. Log in with `paperclipai auth login`, or create an expiring key with `paperclipai token board create --ttl-days N`.
   - How to use it: the session then works through the official `@paperclipai/mcp-server` or the CLI. It can create issues, or run `paperclipai board prompt --agent <reviewer> "..."` to wake a standing reviewer or security agent, and then leave.
   - Scope: one Paperclip instance can cover many repos, because projects map to workspaces.
   - Caveats: the board-key CLI commands exist in source but not in the docs. The MCP server is beta and documents only agent keys. The project is 7 months old and changes very fast.
   - Alternative: [Multica](https://github.com/multica-ai/multica) is the nearest equivalent (a CLI plus a Claude Code skill, used with a personal token).
3. **Build your own hub.**
   - What goes in it: an org plugin that bundles a SessionStart hook (register with the hub and get a lease), an HTTP SessionEnd hook (deregister, best effort), and a remote MCP façade exposing `request_review` and `request_security_scan` tools. The standing agents behind it run on Claude Managed Agents, Routines or the GitHub Action.
   - Coordination between sessions: [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) is the only project that gives each session its own identity when it connects and puts a time limit on its file claims.
   - One problem you must handle: SessionEnd can't block and has a 1.5 s budget, so the hub has to expire leases on its own.

Most tools that look like Paperclip don't fit, because they *launch* Claude Code themselves (worktree and tmux managers) and have no way for an outside session to connect. This covers Claude Squad, Sculptor, Conductor's desktop app, Composio Agent Orchestrator and agent-farm.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

The work was split into four parallel research tracks. Each used web search and fetched primary sources (vendor docs, GitHub READMEs, protocol specs). The Paperclip track also read the `master` source tree (commit of 2026-09-29) for CLI commands that aren't documented.

| Track | Scope |
|---|---|
| 1. Paperclip | Architecture, adapters, heartbeat model, auth, whether an outside session can connect, multi-project support |
| 2. Comparable orchestrators | About 27 "AI company", agent-orchestration and hosted-coding-agent products |
| 3. Central services | Code review, security and issue/project tools that a local Claude Code session can call, plus Claude Code's org-wide config features |
| 4. Protocols and plumbing | MCP 2026-07-28 and its Tasks extension, A2A v1.0, Claude Code hooks, plugins, channels, cross-session messaging, coordination hubs, Anthropic-hosted standing agents |

Nothing was installed or run. Every claim below comes from documentation or source code. Items marked *unverified* are ones where the source was secondhand or conflicting.

## Results

### Paperclip in brief

| Aspect | Finding |
|---|---|
| What it is | MIT-licensed, self-hosted "control plane, not execution plane" for a company of agents. React UI, Express API and Postgres (embedded by default). About 94k stars; latest release is v2026.916.1 (2026-09-21) ([repo](https://github.com/paperclipai/paperclip), `docs/start/architecture.md`) |
| Model | Company → org chart (a CEO agent at the top) → issues with an atomic checkout (a second claim gets a 409) → budgets, board approvals, audit log (`docs/start/core-concepts.md`) |
| How agents run | Heartbeats wake an agent (on a schedule, an assignment or a manual invoke), and the agent then pulls its inbox from the API. Adapters: `claude_local`, `codex_local`, `gemini_local`, `opencode_local`, `cursor`, `process`, `http`, `openclaw_gateway`, `hermes_gateway` (`docs/adapters/overview.md`, `docs/guides/agent-developer/heartbeat-protocol.md`) |
| Outside agents | The `http` adapter POSTs a wake-up to a service that is already running, which then calls back in (`docs/adapters/http.md`) |
| Guest-style access | Board login or expiring board keys (`cli/src/commands/client/auth.ts`, `token.ts`). `board prompt --agent` creates an issue and wakes that agent (`cli/src/commands/client/prompt.ts`). `@paperclipai/mcp-server` offers about 40 tools and is beta (`packages/mcp-server/README.md`) |
| Multi-project | Many companies per instance, isolated from each other. Projects contain workspaces (a `cwd` or a `repoUrl`), so one company can span many repos (`docs/api/goals-and-projects.md`) |
| Gaps | No "guest agent" concept. Board tokens have full authority and aren't limited to one company. Visibility is company-wide. The docs contradict each other on whether @-mentions wake agents |

### Comparable orchestrators

Fit is rated for the guest-session model.

| Tool | Who runs the agent | Can a live local session call in? | Fit |
|---|---|---|---|
| [Paperclip](https://github.com/paperclipai/paperclip) | Paperclip spawns agents via adapters | Yes: MCP server or CLI, with a board or agent key | **Good** |
| [Multica](https://github.com/multica-ai/multica) | A local daemon drives the installed CLIs | Yes: `multica issue create/comment` CLI with a personal token, plus a Claude Code skill ([docs](https://multica.ai/docs/cli)). Its license bars offering it as a hosted service to others | **Good** |
| [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) | Nothing is spawned; it's an HTTP MCP server | Yes: register per session, inbox, time-limited file reservations | **Best for coordination**; no issues or review |
| [Linear MCP](https://linear.app/docs/mcp) + [Cyrus](https://github.com/ceedaragents/cyrus) | Cyrus spawns Claude Code for each assigned issue | Yes: remote MCP for issues. Assigning an issue triggers the always-on worker | **Good** (issue hub plus workers) |
| [GitHub MCP](https://github.com/github/github-mcp-server) / Copilot coding agent | GitHub Actions runners | Yes: `assign_copilot_to_issue`, `request_copilot_review` | **Good** |
| [Devin MCP](https://docs.devin.ai/work-with-devin/devin-mcp) | Devin's VMs | Yes: remote MCP creates and drives sessions | **Good** for handing work off |
| [Conductor Cloud](https://www.conductor.build/docs/api) | Cloud workspaces | Yes: REST, MCP and CLI with an API key | Fair |
| OpenHands Cloud, Factory Sessions API, Cursor Cloud Agents API, Warp Oz, Tembo | Vendor cloud | REST APIs only; no MCP server found | Fair |
| [Backlog.md](https://github.com/MrLesk/Backlog.md), [Task Master](https://github.com/eyaltoledano/claude-task-master) | None (files inside the repo) | Yes: MCP plus CLI | Fair: per repo, not central |
| Claude Squad, Sculptor, Crystal/Nimbalyst, Composio Agent Orchestrator, claude_code_agent_farm, Kiro, MetaGPT, ChatDev | The tool spawns agents or runs its own framework | No | Poor |
| Claude Code [agent teams](https://code.claude.com/docs/en/agent-teams) | The lead session | No: "can't share a team across sessions" | Poor |
| Terragon, Vibe Kanban | — | Terragon shut down in January 2026; Vibe Kanban is sunsetting | Dead or ending |

### Central review, security and issue services

"Delegates" means an agent on the vendor's side does the work, rather than the service just returning data or deterministic scan results.

| Service | How a local session calls it | Delegates? |
|---|---|---|
| CodeRabbit | `/plugin install coderabbit` → `/coderabbit:review`, or `cr review --agent` ([docs](https://docs.coderabbit.ai/cli/claude-code-integration)) | **Yes** |
| Greptile | `claude mcp add --transport http greptile https://api.greptile.com/mcp`, OAuth ([docs](https://www.greptile.com/docs/mcp-v2/setup)) | **Yes** (`trigger_code_review`) |
| Qodo | Plugin skill `pre-pr-review` or `qodo review` ([docs](https://docs.qodo.ai/agentic-toolbox/agentic-toolbox-codebase-review-skill)) | **Yes** |
| Claude Code Review | `@claude review` on a PR, or `/code-review ultra` ([docs](https://code.claude.com/docs/en/code-review)) | **Yes**: several agents on Anthropic infrastructure; an admin enables it once for the org |
| GitHub MCP | Remote MCP with a PAT header ([docs](https://github.com/github/github-mcp-server)) | Partly: Copilot review and issue assignment; code-scanning, Dependabot and secret alerts are data |
| Semgrep Guardian | `claude plugin install semgrep@claude-plugins-official` ([docs](https://docs.semgrep.dev/semgrep-guardian/ide-setup/claude-code.md)) | Scanner. The remote plugin ignores org Policies |
| Aikido | `/plugin install aikido@claude-plugins-official` ([docs](https://help.aikido.dev/ai-and-dev-tools/aikido-mcp/anthropic-claude-code-mcp.md)) | Scanner plus issue feed |
| Snyk Studio | `npx -y snyk@latest mcp configure --tool=claude-cli` ([docs](https://docs.snyk.io/agent-security/agentic-security-with-snyk-studio/quickstart-guides/claude-code-guide)) | Scanner |
| Socket | Remote MCP `https://mcp.socket.dev/`, OAuth ([docs](https://docs.socket.dev/docs/guide-to-socket-mcp)) | Data |
| Endor Labs | `npx -y endorctl ai-tools mcp-server` ([docs](https://docs.endorlabs.com/setup-deployment/mcp/claude-code)) | `security_review` on the Enterprise tier |
| Linear / Atlassian Rovo / Plane / Notion | Remote MCP with OAuth ([Linear](https://linear.app/docs/mcp), [Rovo](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/), [Plane](https://developers.plane.so/dev-tools/mcp-server), [Notion](https://developers.notion.com/docs/get-started-with-mcp)) | Data |
| Sentry | Remote MCP or the `sentry-mcp` plugin ([docs](https://mcp.sentry.dev/)) | Partly (embedded LLM search) |

### Claude Code features for "join while alive"

| Feature | What it gives the pattern | Status |
|---|---|---|
| `--scope user` MCP | One setup, available in every repo ([docs](https://code.claude.com/docs/en/mcp)) | GA |
| `managedMcpServers`, `managed-mcp.json`, managed `enabledPlugins` / `extraKnownMarketplaces` | Push the same hub and services to every machine ([managed-mcp](https://code.claude.com/docs/en/managed-mcp), [plugins/org](https://code.claude.com/docs/en/plugins/org)) | GA |
| Long MCP calls sent to the background | A tool call still running after 2 minutes becomes a background task that notifies on completion, so a slow central reviewer doesn't block the session ([docs](https://code.claude.com/docs/en/mcp)) | GA (v2.1.212+) |
| SessionStart / SessionEnd hooks | Register with the hub and inject the list of available agents; deregister over HTTP. SessionEnd can't block and has a 1.5 s budget ([hooks](https://code.claude.com/docs/en/hooks)) | GA |
| Channels | A local stdio server pushes hub events (review finished, issue assigned) into the *running* session ([channels](https://code.claude.com/docs/en/channels)) | Research preview |
| Cross-session messaging / Remote Control | Messaging between *your own* sessions only; not an org hub ([docs](https://code.claude.com/docs/en/cross-session-messaging)) | Shipped |
| Managed Agents / Routines / `claude-code-action` | Where the standing reviewer and security agents live ([Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview), [Routines fire API](https://platform.claude.com/docs/en/api/claude-code/routines-fire), [Action](https://code.claude.com/docs/en/github-actions)) | Beta / experimental / GA |

Protocol notes:
- **MCP 2026-07-28** ([changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)):
  - It drops the session handshake, so each request stands alone and the server has no per-connection state to clean up when a guest leaves.
  - It moves Tasks into the `io.modelcontextprotocol/tasks` extension. Claude Code's docs don't mention this extension (*unverified*).
  - It deprecates sampling, so a hub shouldn't plan on borrowing the laptop's model.
- **A2A v1.0** ([spec](https://a2a-protocol.org/latest/specification/)): suits communication between the hub and its standing agents. Claude Code has no native A2A client, and the MCP↔A2A bridges are small or archived.

## Analysis

**Why "guest" access is rare.** Paperclip, Multica, Cyrus and Gas Town all assume the orchestrator owns the agent's lifecycle. It wakes the agent, measures its cost and charges it against a budget. A session that a human starts and stops doesn't fit that accounting, so these tools either spawn the agent or require a pre-registered identity. The workaround that works everywhere is to connect as the *human* (Paperclip board keys, a Multica personal token, per-user OAuth for SaaS MCP servers), not as an agent. That matches what you're doing: you are a developer delegating work, not an employee of the agent company.

**What each option costs.**

| | A: no hub | B: Paperclip hub | C: custom hub |
|---|---|---|---|
| Setup | Minutes: `claude mcp add --scope user`, `claude plugin install` | Self-host on a server or Tailscale in `authenticated` mode, define reviewer and security agents, give them budgets | Days: plugin, hooks, MCP façade, worker runtime, lease store |
| Central view across projects | Split across each vendor's dashboard | **One board**: issues, agents, costs and approvals for every repo | Whatever you build |
| Custom agents | Limited to what vendors offer | Any Claude Code, Codex or HTTP agent, with your own prompts and skills | Any |
| Risk | Vendor lock-in; code goes to several SaaS vendors | Very fast churn, beta MCP server, board-key paths undocumented | Maintenance burden |

**Recommendation.**
- **Start with A.** Use Linear or GitHub Issues through remote MCP, Claude Code Review or CodeRabbit for review, and the Semgrep plugin for security, all at user scope. It needs no infrastructure and works in every repo right away.
- **Add B if you want your own standing agents and a single board across projects.** Run Paperclip on your tailnet with a board key held in a `headersHelper` or environment variable, add `@paperclipai/mcp-server` at user scope, and use `board prompt` or `issue create --assignee-agent-id` to hand work to resident reviewer and security agents. Test the MCP server with a board key before relying on it, since this is undocumented.
- **Build C only if B's churn or all-or-nothing board authority is a problem.** If you do, use mcp_agent_mail or Beads as the store, and treat SessionEnd as best effort: leases with a time limit are required.

**Caveats.**
- These tools change quickly. Several findings come from source code or third-party pages, not official docs: Paperclip's board CLI, the Conductor license, the Cursor API, Claude Code Security's status and the Beads repo move.
- None of the setups was run end to end.

## Files

- `README.md`: this report
- `notes.md`: working notes from each research track, including dead ends and unverified items
- `_summary.md`: one-paragraph summary for the repository index

## Original Prompt

> Research other pieces of software like Paperclip.ai. I'm particularly interested in ones that allow one off sessions of Claude code running on my laptop to use agents within those products while they're alive but not be a permanent resident. For example, if I could act like a developer working on a project running Claude code locally and directly, but also have it plugged into these systems for issue management, security or code review agents, etc so that those functions could be centralized and usable across many software projects.
