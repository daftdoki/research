# Cross-harness agent messaging: Claude Code, Hermes and others in shared channels across a tailnet

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Is there existing, preferably self-hostable software that lets agents from different harnesses (Claude Code, Nous Research's Hermes Agent, and others) message each other directly and join shared channels with several agents in them, when the agents run on different machines joined by Tailscale? Or does this need to be built? The prompt asked for a wide and deep sweep, because an earlier pass ([`../a2a-homelab-agent-communication/`](../a2a-homelab-agent-communication/)) missed popular projects. ([original prompt](#original-prompt))

## Answer

**It exists. Don't build the transport.** In 2026 this went from nothing to a crowded field. The sweep found about 100 candidate projects, about 50 of them on target, and almost all of them are less than a year old. Four of them cover what you described: Claude Code plus Hermes, DMs plus channels, multiple hosts, self-hosted.

| Pick | What it is | Claude Code | Hermes | DMs | Channels | Across hosts on a tailnet | Weight |
|---|---|---|---|---|---|---|---|
| **[Cotal](https://github.com/Cotal-AI/Cotal)** (Apache-2.0, 317★) | Agent pub/sub standard on NATS JetStream | Plugin + hooks; dev-channel flag for idle wake | Connector, **alpha** (Unix, hermes-agent 0.18–0.21) | Yes, durable | Yes, named (`#general`), plus anycast to a role | Yes. Docs show a `nats://100.x.y.z` broker and name Tailscale's ranges | One `nats-server` + `cotal` CLI |
| **Matrix** ([Tuwunel](https://github.com/matrix-construct/tuwunel), 2.6k★) | Self-hosted chat server, federation off | Community channel plugin [`cc_matrix_channel`](https://github.com/IA-PieroCV/cc_matrix_channel) (16★, last push Mar 2026); dev-channel flag | **Native**, mature (E2EE, allowlists, mention gating) | Yes | Yes, rooms + threads; humans join from Element | Yes, it's just a server on a tailnet node | One Rust binary |
| **[aweb](https://github.com/awebai/aweb)** (MIT, 115★) | Signed agent mail + chat with wake-up events, federating servers | Channel plugin, **needs `--dangerously-skip-permissions`** to surface messages | Platform plugin, **prototype** v0.1.0 | Yes, durable, offline-safe | Multi-party chat sessions only, no named rooms | Yes | Docker: server + identity registry + Postgres + Redis |
| **Hermes native A2A** + a Claude-side A2A shim | A2A 1.0 over HTTP | [`claude-peer`](https://github.com/jjacke13/claude-peer) (0★) or `curl` from Bash | **Native**, both directions, per-peer tokens | Yes | **No** (A2A is strictly 1:1) | Yes | None on the Hermes side |

**My recommendation.** Try Cotal first. Among the purpose-built tools it is the only one that has all of the following:
- a maintained Hermes connector and a Claude Code connector;
- real named channels as well as DMs;
- presence;
- durable delivery to agents that are busy or offline;
- documented cross-machine setup that explicitly accepts Tailscale addresses.

Expect churn: the wire protocol is v0.3 pre-1.0, npm `cotal-ai` shipped 138 versions in four months, and Hermes support is labelled alpha.

If Cotal disappoints, run a Tuwunel Matrix homeserver on one tailnet node. Hermes speaks Matrix natively and well, and it gives you a human UI for free. The weak link there is the Claude Code side, which is a small community plugin you may end up maintaining.

Neither option needs you to build the transport. The only thing worth building is a thin adapter for whichever harness edge breaks. The likeliest one to build is a per-host bridge that posts into Claude Code's documented [inbox socket](https://code.claude.com/docs/en/cross-session-messaging#the-sessions-inbox-socket), which avoids the development-channel flag ([details](#the-one-thing-worth-building)).

**Two constraints shape every option.**

1. **Getting a message into an idle Claude Code session is the bottleneck, not the network.** There are four ways in, and each has a cost:
   - Channels: any non-allowlisted channel needs `--dangerously-load-development-channels`, and only interactive sessions honour it.
   - Hooks, or the `Monitor` tool: these only fire on the session's next turn.
   - The per-session inbox socket: same machine, same OS user only.
   - Built-in cross-session messaging: Claude to Claude only, and it reaches other machines through Anthropic's servers rather than your tailnet.

   Hermes is the easy side. It is a long-running gateway with about 30 pluggable platforms.
2. **On self-hosted chat, every agent sees every other agent.** Matrix, IRC, NATS, Zulip and Mattermost have no bot class, so loop control (mention-gating, turn caps, allowlists) is your job. Telegram and Discord are worse: they aren't self-hostable, and the official Claude Code Discord channel drops every message written by a bot.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

Public sources only; nothing was installed or run. Repositories were shallow-cloned into a scratch directory to read their source and docs, and none of them are committed here.

### Fixing the search sources

The prompt asked me to fix any source that wasn't working. GitHub search was broken at the start:

| Source | Result | Fix |
|---|---|---|
| `gh search repos` | HTTP 403, "sessions are bound to their configured repositories" (this session's proxy) | Use the GitHub MCP tool `search_repositories`, which isn't scope-restricted for search and supports full qualifier syntax |
| `curl api.github.com/search/...` (unauthenticated) | Same 403 (the proxy intercepts the host) | Same |
| `gh api repos/OTHER/REPO` | 403 | Star counts from `ungh.cc/repos/O/R` or `repos.ecosyste.ms/.../lookup`, or batch `repo:a/b repo:c/d …` in one MCP search |
| `github.com/search` HTML | 403 | n/a |
| grep.app | Vercel bot wall | n/a; GitHub MCP `search_code` worked instead |
| READMEs | `raw.githubusercontent.com` worked | n/a |
| Hacker News | Algolia API worked | n/a |
| Reddit (www, old, json, rss, pullpush) | 403/429 every route | **Not fixed.** Popularity evidence is Hacker News, stars and press only |

### Search approach

Four research subagents ran in parallel, and each wrote a report, kept as an appendix:

1. **GitHub sweep:** 71 searches, varying the specificity in both directions:
   - Broad phrases such as "agent chat" or "agent mesh", which return a lot of noise.
   - Harness-pair phrases such as "claude code codex communicate".
   - Protocol and substrate names such as "mcp irc", "nats agents" or "a2a hermes".
   - `topic:` queries, which gave the best signal: `agent-communication`, `agent-to-agent`, `a2a`+`claude-code`, `agent-mesh`, `hermes-agent`.
   - Code search, which found repos that repo search missed.
   - `stars:>N pushed:>DATE` filters.

   38 READMEs were read to verify the claims. ([appendix](appendix-github-sweep.md))
2. **Community traction:**
   - About 110 Hacker News queries, covering both stories and comments, the latter to catch tools people recommend in passing.
   - About 16 web searches.
   - 12 awesome-lists grepped for chat, mail, relay, mesh, room and inter-agent terms.

   ([appendix](appendix-community-sweep.md))
3. **Harness integration surfaces:**
   - Docs and source of Hermes Agent, Claude Code, OpenClaw, Codex, Gemini CLI, OpenCode and Goose.
   - The question for each: how can an outside message get in?

   ([appendix](appendix-harness-surfaces.md))
4. **Protocols and infrastructure:**
   - Protocols: A2A, ACP (both the IBM and Zed ones), ANP, AGNTCY SLIM, Coral, NLIP and MCP 2026-07-28.
   - Chat servers: Matrix, IRC, XMPP, Mattermost, Zulip, NATS and MQTT.
   - Tailscale's own offerings.

   ([appendix](appendix-protocols-infra.md))

I then checked the shortlist myself:
- Shallow clones of aweb, Cotal and hermes-agent: the Hermes platform plugins, the Cotal Hermes and Claude Code connectors and multi-host docs, and the aweb Hermes adapter and chat API.
- READMEs of 11 more candidates.
- A batch star check of 24 repos on 2026-10-10.
- The Claude Code cross-session messaging docs page.

## Results

### How each harness can receive a message

| Inbound path | Claude Code | Hermes Agent |
|---|---|---|
| Self-hosted chat (Matrix, IRC, Mattermost) | Community channel plugins only; `--dangerously-load-development-channels`; interactive only | **Native** gateway platforms (`plugins/platforms/{matrix,irc,mattermost,…}`) |
| Slack / Discord / Telegram | Official Telegram and Discord channels (Discord drops bot authors); Slack community | Native; bot messages opt-in per platform (`*_ALLOW_BOTS` = none\|mentions\|all, default none) |
| A2A | Community (`claude-peer`, `a2a-bridge`, `claude-a2a`) | **Native**, in and out (`plugins/platforms/a2a/`); binds 127.0.0.1 unless token + `A2A_HOST` |
| HTTP API | None (`claude -p` / Agent SDK) | OpenAI-compatible API server; `hermes serve` WebSocket |
| Local socket / file | Per-session inbox socket (documented, same OS user); hooks; `Monitor` | `hermes serve` WebSocket (used by open-cross-session) |
| MCP server | `claude mcp serve` exposes tools, not an inbox | `hermes mcp serve` (stdio, poll-only) |
| Custom plugin | Channel = MCP server emitting `notifications/claude/channel` | Platform plugin = `BasePlatformAdapter` + `ctx.register_platform` |

Sources: [Claude Code channels](https://code.claude.com/docs/en/channels), [cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging), [Hermes messaging docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging), `NousResearch/hermes-agent` source, and aweb's [Hermes integration memo](https://github.com/awebai/aweb/blob/main/docs/hermes-aweb-gateway-integration.md), which documents the Hermes platform-plugin contract.

### Shortlist: buses that your existing agents join

These keep each agent in its own harness and connect it to a shared transport. That is the "without needing many other features" shape.

| Project | ★ (2026-10-10) | Transport | Harnesses with a wake path | Channels | Cross-host | Notes |
|---|---|---|---|---|---|---|
| [Cotal-AI/Cotal](https://github.com/Cotal-AI/Cotal) | 317 | NATS + JetStream | Claude Code, OpenCode, Codex, **Hermes (alpha)**, Jcode, pi | Named channels, DMs, anycast to roles, presence | `cotal meshes add --server nats://100.x:4222 --allow-unencrypted-overlay` | Per-agent JWT ACLs; web dashboard. Joining an auth mesh from a second host copies the space's signing seed there (a machine holding it can mint any identity). Hermes runs under Cotal's launcher in an isolated `HERMES_HOME` unless `COTAL_HERMES_ADOPT_HOME` is set |
| Matrix: [Tuwunel](https://github.com/matrix-construct/tuwunel) / Continuwuity + Hermes + [cc_matrix_channel](https://github.com/IA-PieroCV/cc_matrix_channel) | 2,611 / 16 | Matrix C-S API | Hermes native; Claude Code via community channel | Rooms, threads, DMs | Server on any tailnet node | Most "boring" option; humans participate from Element; Claude-side plugin is small and quiet since March |
| [awebai/aweb](https://github.com/awebai/aweb) | 115 | HTTP + SSE, signed messages | Claude Code (channel, needs permission bypass), Pi, Codex (`aw run codex`), Hermes (prototype) | Multi-recipient chat sessions; `--cc` not supported | Yes; federation between servers | Identity is DNS-rooted (AWID); local stack uses a reserved `local` namespace for no-DNS setups. Ships an A2A gateway |
| [leeguooooo/open-cross-session](https://github.com/leeguooooo/open-cross-session) (`ocs`) | 20 | Local JSONL logs + paired LAN links | Claude Code (**native inbox socket**, set `crossSessionInbound: accept`), **Hermes (`hermes serve` WebSocket)**, Pi, ChatGPT Desktop Codex, cmux TUIs | Multi-party channels **per machine** only | DMs only (`name@peer`), Ed25519/X25519/AES-GCM pairing, works over Tailscale IPs | No server and no dev-channel flag. Closest to "minimal". Cross-host channels missing |
| [fujibee/agmsg](https://github.com/fujibee/agmsg) | 1,544 | SQLite (+ optional reference server with Postgres) | Claude Code (`Monitor` push), Codex (bridge), Gemini, Copilot, OpenCode, Hermes (listed, not spawnable) | Teams = rooms | Via self-hosted reference server | Bash + SQLite; macOS primary |
| [aannoo/hcom](https://github.com/aannoo/hcom) | 566 | Hooks + MQTT relay | 12+ CLIs; no Hermes | DM + broadcast | `hcom relay` over MQTT | Hooks-based |
| [synadia-ai/synadia-agents](https://github.com/synadia-ai/synadia-agents) | 84 | NATS | Claude Code channel, Codex, OpenCode, OpenClaw, Pi; Hermes on a fork branch | Prompt/RPC, not rooms | Yes | From the NATS company |
| [alexfrmn/murmur](https://github.com/alexfrmn/murmur) | 19 | NATS, E2E | Claude Code, Codex, any MCP | Channels + DMs | Yes, federation | Small |
| [noopolis/moltnet](https://github.com/noopolis/moltnet) | 29 | HTTP, single Go binary | Claude Code, Codex, OpenClaw | Rooms, threads, DMs | Bind all interfaces, private net | No Hermes |
| [hrubymar10/aimebu](https://github.com/hrubymar10/aimebu) | 6 | Go binary, MCP/HTTP | Any MCP | Rooms only primitive ("IRC for agents") | Yes | Tiny |
| [Dicklesworthstone/mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) | 2,199 | MCP HTTP + Git + SQLite | Any MCP client (poll) | Threads/mail | Possible with token | Most-recommended in HN comments, but mail-shaped and no push |
| [AgentWorkforce/relay](https://github.com/AgentWorkforce/relay) | 872 | Relay service | Claude Code, Codex | Channels, threads, DMs | Yes | README pushes its Cloud; couldn't confirm a self-hostable broker |

### Bigger tools that spawn or drive agents (more features than asked for)

These run agents as subprocesses, usually over ACP or a terminal multiplexer, inside a workspace product. They're relevant if you want a Slack-like home, but they own the agent's lifecycle.

| Project | ★ | What it is | Hermes |
|---|---|---|---|
| [block/buzz](https://github.com/block/buzz) | 35,820 | Self-hostable Nostr-relay workspace where agents are channel members with keys (Rust + Postgres/Redis/MinIO) | **Native platform** in Hermes; Claude Code and Codex attach via `buzz-acp` |
| [yc-software/qm](https://github.com/yc-software/qm) | 15,379 | Multiplayer agent harness shared through Slack/web channels | — |
| [herdrdev/herdr](https://github.com/herdrdev/herdr) | 43,251 | Terminal-multiplexer runtime; agents prompt and wait on each other via socket API; multi-SSH | — |
| [gastownhall/gastown](https://github.com/gastownhall/gastown) + beads | 18,322 / 27,785 | Multi-agent workspace with `gt mail`; aweb can be its mail transport | — |
| [HarnessMD/munder-difflin](https://github.com/HarnessMD/munder-difflin) | 8,644 | "Office" of agents across ~12 harnesses | — |
| [mvschwarz/openrig](https://github.com/mvschwarz/openrig) | 6,726 | Claude Code, Codex, Pi as persistent teams | — |
| [SeemSeam/claude_codex_bridge](https://github.com/SeemSeam/claude_codex_bridge) | 3,560 | Visible multi-agent CLI workspace, ~10 harnesses | — |
| [GoogleCloudPlatform/scion](https://github.com/GoogleCloudPlatform/scion) | 1,736 | Agent teams with a message bus; hosted hub for cross-machine | — |
| [bcurts/agentchattr](https://github.com/bcurts/agentchattr) | 1,530 | Local chat room; @mentions prompt the agent's terminal | — |
| [ChesterRa/cccc](https://github.com/ChesterRa/cccc) | 1,275 | Group-chat orchestrator with receipts; links instances across machines | Auto MCP setup |
| [23blocks-OS/ai-maestro](https://github.com/23blocks-OS/ai-maestro) | 817 | Dashboard + agent messaging over a peer mesh, no central server | Listed |
| [solo-agent/solo](https://github.com/solo-agent/solo) | 699 | Local-first workspace: channels, threads, task boards | Via ACP |
| [fancyboi999/open-tag](https://github.com/fancyboi999/open-tag) | 204 | Self-hosted Slack-style workspace; per-machine daemon | Mentioned |

The [GitHub appendix](appendix-github-sweep.md) ranks about 50 candidates plus a long tail, and the [community appendix](appendix-community-sweep.md) gives Hacker News points per tool.

### Protocols

| Protocol | Groups/rooms? | Claude Code | Hermes | Verdict |
|---|---|---|---|---|
| A2A 1.0 (Linux Foundation) | No, 1:1 task model | Community shims | **Native** | Good for direct delegation, can't be the channel |
| IBM ACP | — | — | — | Merged into A2A, archived Aug 2025 |
| Zed ACP (Agent Client Protocol) | No, editor↔agent | Adapter | Native (`hermes acp`) | How workspaces *drive* agents, not peer messaging |
| AGNTCY SLIM | Yes, MLS-encrypted groups | None | None | Best design, no adapters |
| Coral | Threads, orchestrator-centric | — | — | Remote agents closed beta |
| MCP 2026-07-28 | No room primitive, no unprompted push | Client | Client | Every "chat over MCP" tool needs channels or hooks for wake |
| Cotal (on NATS) | Yes | Connector | Connector | Reuses A2A `AgentCard`/`Message` shapes |

### What the earlier pass missed

Compared with [`a2a-homelab-agent-communication`](../a2a-homelab-agent-communication/README.md), the earlier pass missed these:
- **Hermes's native A2A.**
- **Every purpose-built bus:** Cotal, aweb, agmsg, open-cross-session, hcom, mcp_agent_mail, Agent Relay, Synadia.
- **The large workspaces:** Buzz, herdr, qm, Gas Town, Munder Difflin, OpenRig, CCB.
- **The Claude Code inbox socket**, which is the low-friction way to inject a message locally.

The earlier search went protocol-first, starting from "A2A". This sweep went substrate-first and used `topic:` and harness-pair queries, and that is where these projects turned up.

## Analysis

**Why not just A2A.** Hermes's native A2A makes Claude Code→Hermes delegation nearly free: `curl` its endpoint over the tailnet with a bearer token. But A2A has no rooms, and the Claude Code side of A2A is still 0–15★ shims. Use it for "ask the Hermes agent to do X" if Cotal or Matrix feels heavy. It doesn't answer "join channels".

**Why Cotal over Matrix.**
- What Cotal has that Matrix doesn't:
  - **Agent-native semantics:** presence, attention modes (`dnd`/`focus`), anycast to "whoever is a reviewer", and durable per-reader bookmarks for agents that were offline.
  - **Push into Claude Code**, written by people who designed for it: a hook drain delivers messages even without the channel flag, and the channel only adds wake-when-idle.
  - **A Hermes connector** that handles Hermes's habit of replying to every message, so two Hermes seats don't answer each other forever.
- What Matrix has:
  - Maturity, and a human-first UI.
  - A Hermes adapter that Nous maintains.
- Both put the risky part on the Claude Code side. For Matrix that's a 16★ community plugin; for Cotal it's a young but very active project. Run either one for a week before committing.

**Security on the tailnet.**
- **Cotal:**
  - Without TLS, it refuses ordinary RFC 1918 addresses and accepts the Tailscale ranges only with an explicit `--allow-unencrypted-overlay` acknowledgement, which is a careful design.
  - The signing-seed copy is the real risk: every host that registers an auth mesh becomes a CA for it. Prefer `--user-auth` or a single trusted broker host.
- **aweb:** its Claude Code wake path requires running Claude with all permission prompts off. That is a poor trade for a message bus.
- **Everywhere:** lock the bus port with tailnet ACL tags, give each agent its own credential, mention-gate by default, cap agent-to-agent turns, and never relay permission approvals from peers.

<a id="the-one-thing-worth-building"></a>**The one thing worth building.** If you want to avoid `--dangerously-load-development-channels`, write a tiny per-host daemon. It subscribes to the bus (NATS subject, Matrix room) and writes each message to the target Claude session's documented inbox socket (`CLAUDE_CODE_MESSAGING_SOCKET`). That's how `ocs` wakes Claude Code. The receiving session needs `crossSessionInbound: accept`, or must be in a prompting permission mode; there the default delivers. Replies go out through a CLI or MCP tool on the same bus. It is probably a few hundred lines. Everything else (rooms, history, presence, auth, Hermes integration) already exists.

**Caveats.**
- Reddit was unreachable, so community sentiment comes from Hacker News, stars and press.
- Several 2026 repos have odd star/fork/issue ratios, so stars are weak evidence on their own.
- Some Hermes details (A2A version, Buzz platform maturity) came from docs pages and source, not from running it.
- Everything here moves weekly. Re-check versions before installing.

## Files

- `README.md`: this report.
- `notes.md`: work log, including the search-source fixes, dead ends and per-candidate verification notes.
- `appendix-github-sweep.md`: query log for the 71 GitHub searches (hit counts, notable hits), about 50 ranked candidates plus a long tail, and the search tricks that worked or failed. Written by the GitHub-sweep subagent.
- `appendix-community-sweep.md`: Hacker News, awesome-list and web query log; about 50 tools with traction evidence; dead ends. Written by the community subagent.
- `appendix-harness-surfaces.md`: matrix of inbound mechanisms per harness (Hermes, Claude Code, OpenClaw, Codex, Gemini CLI, OpenCode, Goose), with citations. Written by the harness subagent.
- `appendix-protocols-infra.md`: protocol and self-hosted chat infrastructure comparison tables, with sources. Written by the protocols subagent.
- `_summary.md`: one-paragraph summary for the repo index, written by the summarizer subagent.

## Original Prompt

> Do some research on ways to allow agents of multiple harnesses to communicate without needing many other features. Ideally I'd like to be able to have diverse agent harnesses like the claude code and hermes be able to talk directly to each other, and also joing channels that contain multiple agents. This should allow agents on different machines to participate. e.g., a claude code and hermes agent on one host can talk to a claude code on a different host. Connectivity between them can be handled with something like Tailscale (which I use already), so it doesn't have to be internet accessible. Self hostable software preferred. Is there something that exists that I can use, or do I need to think about building it? Go wide and deep on research of existing artifacts, I've noticed that you haven't found some things that were popular in past research. If a source isn't working, like searching github, try and fix it. In your search terms try many things, changing the specificity to be more or less, etc. Think about your search approach for turning up the most results for later evaluation.
