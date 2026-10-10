# Agent-harness integration surfaces for cross-machine agent messaging

Research date: 2026-10-10. Sources: primary docs and source code. The repos were shallow-cloned on 2026-10-10 and grepped; none of their code was run:
- `NousResearch/hermes-agent` @ 6a2662a (2026-10-10)
- `openclaw/openclaw` (2026-10-10)
- `anthropics/claude-plugins-official` (2026-10-10)

Every URL cited here was read during this session. Repo paths are given as `repo:path`.

---

## 0. Matrix: harness × inbound-message mechanism

Legend:
- **N** = native or bundled (first-party).
- **P** = first-party plugin or channel that you opt into.
- **C** = community project only.
- **—** = none found.
- **(bots)** = whether the harness's adapter *admits messages authored by other bots* by default.

| Inbound via → | Matrix | Slack | Discord | Telegram | IRC | Mattermost | Webhook / HTTP POST | MCP (as server others call) | ACP (as agent) | A2A | HTTP API (prompt in, reply out) | NATS / pub-sub |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Hermes Agent** | N (mautrix, E2EE; require-mention default on; no bot flag in Matrix, so other agents are ordinary users gated by `MATRIX_ALLOWED_USERS`) | N (`allow_bots: none\|mentions\|all`, default none) | N (`DISCORD_ALLOW_BOTS` default none; inline `<@id>` required) | N (`TELEGRAM_ALLOW_BOTS`, `bots_require_mention`, loop guard) | N (stdlib asyncio; channel msgs must address `nick:`) | N (require-mention default true) | N (`webhook` platform, port 8644, HMAC; can `deliver` to other platforms) | N `hermes mcp serve` (stdio only; exposes conversations, `messages_send`, `events_wait`; **no** `claude/channel` push) | N (`hermes acp`, stdio) | **N** (in/out, A2A v1.0, port 9900, bearer/per-peer tokens, anti-loop) | N (OpenAI-compatible `/v1/chat/completions`, `/v1/responses`, `/v1/runs` + SSE, port 8642) | C (Synadia `hermes/` on a fork branch; Cotal connector; commy platform plugin) |
| **Claude Code** | C (many channel plugins) | C (several; `jeremylongshore/claude-code-slack-channel` has `allowBotIds`). First-party "Claude in Slack / Claude Tag" spawns *cloud* sessions, not your local one | P (official channel; **drops all bot-authored messages**: `if (msg.author.bot) return`) | P (official channel) | C (smalltalk-channel, claude-comms, …) | C (2 channel plugins + bridges) | P/DIY (documented webhook-receiver channel; fakechat on :8787) | N `claude mcp serve` (exposes CC's *tools*, not a chat inbox) | C (Zed's `claude-agent-acp` adapter) | C (`jjacke13/claude-peer`: A2A v1.0 channel plugin) | — (no HTTP server; `claude -p` / Agent SDK / `stream-json` stdin) | C (Synadia `claude-code/` channel plugin; Cotal) |
| **OpenClaw** | N (`allowBots: true\|"mentions"`) | N (accepts bot msgs by default under mention rules) | N (accepts bot msgs by default) | N | N | N | N (gateway HTTP, `tools-invoke-http-api`) | N `openclaw mcp serve` (stdio; **emits `notifications/claude/channel`**, so it works as a Claude Code channel) | N (`openclaw acp` server; also ACP *client* via acpx to run Claude Code/Gemini/Codex) | **N** (A2A 1.0 channel plugin, `/a2a/v1`) | N (gateway) | C (Synadia `openclaw/`) |
| **Codex CLI** | — | C (OpenTag, handclaw…) | — | — | — | C | — | **removed** (`codex mcp-server` gone; use `codex app-server`) | C (`codex-acp` adapter) | — | `codex app-server` (experimental; stdio / WebSocket / Unix socket) | C (Synadia, Cotal) |
| **Gemini CLI** | — | — | — | — | — | — | — | — | N (`--acp`, JSON-RPC over stdio) | — | — | — |
| **OpenCode** | — | C | — | — | — | — | — | — | N (`opencode acp`) | — | N `opencode serve` (OpenAPI; `POST /session/:id/message`, SSE `/event`, port 4096, basic auth) | C (Synadia, Cotal) |
| **Goose** | — | — | — | — | — | — | — | — | N (`goose acp`, stdio) | — | — | — |

All harnesses in the table are **MCP clients**: Hermes, Claude Code, OpenClaw, Codex (`codex mcp add`), Gemini CLI, OpenCode and Goose.

---

## 1. Hermes Agent (NousResearch/hermes-agent)

Docs site: https://hermes-agent.nousresearch.com/docs/. It is built from `hermes-agent:website/docs`, with `url: 'https://hermes-agent.nousresearch.com', baseUrl: '/docs/'`.

### 1.1 Messaging gateway
`hermes-agent:website/docs/user-guide/messaging/index.md` describes the gateway as *"a single background process that connects to all your configured platforms, handles sessions, runs cron jobs, and delivers voice messages."*

Platform adapters live in `gateway/platforms/` (core) and `plugins/platforms/` (plugin adapters). The docs (`messaging/*.md`) cover:

- **Chat platforms:** Telegram, Discord, Slack, Google Chat, WhatsApp (Baileys and Cloud API), Signal, SMS, Email, Home Assistant (plugin), Mattermost, Matrix, DingTalk, Feishu/Lark, WeCom (and WeCom Callback), Weixin, BlueBubbles and Photon (iMessage), QQ, Yuanbao, Microsoft Teams (plus Teams meetings), LINE, ntfy, **IRC**, **Buzz** (Block's Nostr-based human+agent chat), **SimpleX**, **Raft** (external-agent wake bridge), Open WebUI.
- **Agent-facing surfaces:** **Webhooks**, the **API server**, **A2A**, MS Graph webhook.
- **Relay:** an experimental connector system. The gateway dials *out* over a WebSocket to a connector that holds the platform credentials, so the gateway needs no inbound port.

### 1.2 Bot-to-bot admission (important for multi-agent rooms)
- **Discord:** `DISCORD_ALLOW_BOTS` = `none` (default), `mentions` or `all`. `DISCORD_BOTS_REQUIRE_INLINE_MENTION` defaults to true, so a handoff from another bot needs a literal `<@BOT_ID>`. Source: `messaging/discord.md` lines 320–355.
- **Slack:** `platforms.slack.extra.allow_bots` = `none` (default), `mentions` or `all`. *"`mentions` is the recommended mode for bot-to-bot collaboration."* Detection covers `bot_id`, `subtype: bot_message`, and bot users probed via `users.info`. Source: `messaging/slack.md` around line 705.
- **Telegram:** `TELEGRAM_ALLOW_BOTS`, `telegram.bots_require_mention` and `exclusive_bot_mentions` exist, plus a "Multiple Hermes bots in one group" recipe (`messaging/telegram.md` around line 640).
- **Loop guard:** `gateway/bot_loop_guard.py` enforces 20 bot messages per 5 minutes per conversation, then a 10-minute cooldown. It is configurable under `gateway.bot_loop_guard`.
- **Matrix:** there is no bot flag in the Matrix protocol. The adapter only filters its *own* messages (`plugins/platforms/matrix/adapter.py` around line 1944). Another agent's account is therefore just a user, gated by `MATRIX_ALLOWED_USERS` and `MATRIX_REQUIRE_MENTION` (default true; threads the bot already joined don't need a mention). Room invites are auto-accepted.
- **IRC:** in channels the bot responds only when addressed as `nick:` / `nick,` (`plugins/platforms/irc/adapter.py:302`). Access is gated by `IRC_ALLOWED_USERS`; nicks are unauthenticated unless NickServ is used.
- **Mattermost:** `MATTERMOST_REQUIRE_MENTION` defaults to true and the bot is allowlist-gated. No special bot filter was found in the adapter.
- **Silence tokens:** `[SILENT]`, `NO_REPLY` and similar suppress delivery in group chats.

### 1.3 A2A: native and bidirectional
Source: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/a2a (read live) and `messaging/a2a.md`.

- **Inbound:** `gateway.platforms.a2a.enabled: true` serves the Agent Card at `GET /.well-known/agent-card.json` and JSON-RPC 2.0 at `POST /` (`SendMessage`, `SendStreamingMessage`, `GetTask`, `ListTasks`, `CancelTask`, push-notification CRUD). It supports SSE and HMAC-signed push. Inbound tasks are *"injected into a live gateway session"*, keyed by `contextId`.
- **Outbound:** the `a2a` toolset (off by default) provides `a2a_discover`, `a2a_call`, `a2a_list`, `a2a_history` and `a2a_orchestrate`. Peers are listed under `a2a_agents:` with a URL and bearer token.
- **Security:**
  - With no token the server binds `127.0.0.1` only. Remote exposure needs a token **and** `A2A_HOST`.
  - `A2A_PEER_TOKENS` gives per-peer identity; `A2A_TRUSTED_PEERS` sets trust.
  - Inbound text passes a prompt-injection filter, and outbound credentials are redacted.
  - Exchanges are audit-logged to `~/.hermes/a2a_audit.jsonl`.
  - `A2A_MAX_PINGPONG_TURNS` defaults to 5 (max 20).
- The docs name the use case directly: *"Hermes ↔ Hermes across machines"*. It is also tested against the official `a2a-sdk`.

### 1.4 MCP
- **Client:** yes. Supports stdio and HTTP, with a curated catalog and per-server tool filtering. `hermes import-agent claude-code` migrates `~/.claude.json` MCP servers (`features/mcp.md`).
- **Server:** `hermes mcp serve` (`mcp_serve.py`, `features/mcp.md` around line 1005) is a **stdio-only** MCP server. It exposes 10 tools *"matching OpenClaw's channel bridge surface"*: `conversations_list`, `conversation_get`, `messages_read`, `attachments_fetch`, `events_poll`, `events_wait`, `messages_send`, `channels_list`, `permissions_list_open`, `permissions_respond`.
  - Claude Code can mount it to send and read Hermes's Telegram, Discord and Slack conversations.
  - It does **not** emit `notifications/claude/channel` (grep found no hits), so Claude Code would have to long-poll `events_wait`.
  - It is local only (stdio) and needs the gateway running for sends.

### 1.5 ACP
`hermes acp` runs Hermes as an ACP server over stdio (`features/acp.md`) with a curated `hermes-acp` toolset. That toolset leaves out messaging delivery and cron. Hermes also contains ACP *client* code (`agent/copilot_acp_client.py`) for using Copilot as a model provider, which is deprecated.

### 1.6 API server
The API server is OpenAI-compatible and runs on `127.0.0.1:8642` (`features/api-server.md`). It requires `API_SERVER_ENABLED=true` and `API_SERVER_KEY`. Endpoints:
- `/v1/chat/completions` (stateless)
- `/v1/responses` (stateful via `previous_response_id` or named conversations)
- `/v1/runs` with SSE `/events`, `/stop` and `/approval`
- `/api/jobs` for cron CRUD

This is the easiest place for *any* agent to send Hermes a prompt and get a reply synchronously.

### 1.7 Other relevant pieces
- **Cron:** the gateway ticks every 60s (`features/cron.md`). Jobs deliver to a "home channel" on any platform.
- **Subagents:** the `delegate_task` tool supports parallel batches, structured output and steering (`features/delegation.md`).
- **Kanban:** a multi-gateway work queue.
- **Bot Mode:** profiles act as named Bots that *"message each other directly"* and share group chats (desktop app, same backend).
- **Outbound:** the `send_message` tool and `hermes send` CLI. Hermes can also `curl` any HTTP endpoint from its terminal tool.

### 1.8 How another agent can reach Hermes, ranked for cross-host use over Tailscale
1. **A2A** on `:9900`: set `A2A_HOST=<tailscale IP>` and a per-peer token. Multi-turn and auditable.
2. **API server** on `:8642`: OpenAI-compatible, so any agent can just `curl` it.
3. **Webhook platform** on `:8644`: fire-and-forget, with the reply routed to a chat platform.
4. **A shared chat room** (Matrix, IRC, Slack, Discord, Mattermost) with `allow_bots: mentions` or the equivalent.
5. **NATS / Cotal / commy** via community connectors.

---

## 2. Claude Code

### 2.1 Channels (research preview)
Docs:
- https://code.claude.com/docs/en/channels
- https://code.claude.com/docs/en/channels-reference

What a channel is:
- A channel is **an MCP server (stdio subprocess) declaring `capabilities.experimental['claude/channel']`** that emits `notifications/claude/channel` with `{content, meta}`.
- The event reaches Claude as `<channel source="..." k="v">body</channel>`.
- Replies go through an ordinary MCP tool, conventionally `reply(chat_id, text)`.

Official plugins (`anthropics/claude-plugins-official/external_plugins/`): **telegram, discord, imessage, fakechat**. These are the only four that declare `claude/channel` in that repo as of 2026-10-10. They require Bun.

How to enable:
- Run `claude --channels plugin:<name>@claude-plugins-official`.
- Custom or community channels need `--dangerously-load-development-channels plugin:x@mkt|server:x`. That flag shows an interactive confirmation and is **ignored under `-p` and the Agent SDK**.
- *"The community marketplace is not on the channel allowlist."*
- Team and Enterprise orgs must set `channelsEnabled`. They can also set `allowedChannelPlugins` to approve internal channels, which is the clean route for a custom Matrix or A2A channel.

Permission relay:
- Declare `claude/channel/permission`.
- Claude Code sends `notifications/claude/channel/permission_request {request_id (5 letters a–z minus l), tool_name, description, input_preview}`.
- The server answers with `notifications/claude/channel/permission {request_id, behavior: allow|deny}`.
- From v2.1.234, prompts go only to servers registered as channels for the session.

Delivery and gating:
- Events queue while Claude is busy and are delivered together.
- There is no acknowledgement, and events are dropped silently if the channel isn't registered.
- Gate inbound on the **sender** ID, not the room ID.
- On the v2 MCP client runtime, a channel server that negotiates protocol revision **2026-07-28** isn't registered as a channel (`/docs/en/mcp`). Channel servers must stay on the earlier handshake.

Official Discord channel behaviour: `server.ts:806` has `client.on('messageCreate', msg => { if (msg.author.bot) return ... })`. **Bot-authored messages are dropped unconditionally**, so a Hermes bot in a Discord channel cannot wake the official Claude Code Discord channel without patching it.

Official Telegram channel behaviour: it has group support with mention-triggering and allowlists keyed on sender ID. It has no explicit bot filter; the platform rules in §6 apply.

### 2.2 Cross-session messaging (`ListAgents` / `SendMessage`)
Source: https://code.claude.com/docs/en/cross-session-messaging

Versions and transport:
- Requires v2.1.224 or later on macOS and Linux.
- Same-machine messages travel over a per-session Unix socket. Its path is exported as `CLAUDE_CODE_MESSAGING_SOCKET`, with a token in `CLAUDE_CODE_MESSAGING_TOKEN`.
- **Other machines:** messages travel *"Through Anthropic servers, arriving over that machine's Remote Control connection"*. This needs a claude.ai sign-in and Remote Control on both ends, and works only between your own sessions.

Limits and controls:
- Plain text only. The receiver treats messages as peer data, never as user consent.
- `crossSessionInbound` = `accept`, `hold` or `refuse`. `isolatePeerMachines` requires approval before a message leaves the machine.
- Loop throttling is built in.

Other harnesses:
- **Claude Code only.** Non-Claude agents cannot use this, except that a local process running as the same OS user can post to the socket. Such messages go through inbound controls, and "own-child" verification applies to hooks and Bash.
- `claude -p` sessions bind an inbox, so a long-running `-p` worker is reachable; `--bare` sessions are not.

### 2.3 Other surfaces
- **Agent teams:** experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`), same machine only. Mailboxes are JSON files at `~/.claude/teams/{team}/inboxes/{agent}.json`. One team per session, and teams can't be shared across sessions. Source: https://code.claude.com/docs/en/agent-teams
- **Remote Control:** `claude remote-control` is a server mode with `--spawn same-dir|worktree|session` and `--capacity` (default 32). `--rc` works per session. It requires a claude.ai subscription (API keys are not supported) and routes through Anthropic. It is aimed at humans on claude.ai or the mobile app; there is no third-party API. Source: https://code.claude.com/docs/en/remote-control
- **Hooks:** handlers can be command, **HTTP** (POSTs event JSON to a URL), prompt, agent or MCP-tool. `asyncRewake` wakes Claude on exit code 2. These are outbound notifications and gates, not an inbound chat path. Source: https://code.claude.com/docs/en/hooks
- **MCP client:** supports stdio, http and sse/ws transports. `claude mcp serve` exposes Claude Code's *tools* over stdio to another MCP client (Source: https://code.claude.com/docs/en/mcp). A Hermes `mcp_servers: {cc: {command: claude, args: [mcp, serve]}}` entry would let Hermes use Claude Code's file and Bash tools, but would not talk to a Claude Code *agent*.
- **Headless:** `claude -p` supports `--output-format json|stream-json`, `--input-format stream-json`, `--resume <id>`, `--bare` and `--permission-prompts none`. The Agent SDK is available for Python and TypeScript. There is no built-in HTTP server. Source: https://code.claude.com/docs/en/headless
- **First-party Slack:** "Claude in Slack" and "Claude Tag" spawn *cloud* sessions from @mentions (`/docs/en/slack`). They do not bridge into a local terminal session.

### 2.4 Community Claude Code channel plugins
These all declare `claude/channel`. They were found via GitHub code and repo search, with metadata from ungh.cc. Treat them as unvetted: most have very few stars.

**Matrix:**

| Repo | Notes |
|---|---|
| `IA-PieroCV/cc_matrix_channel` | Rust, 16★; pairing, allowlist, groups, `fetch_messages` |
| `zekker6/claude-code-channel-matrix` | TypeScript, active 2026-10 |
| `nazbav/claude-code-matrix-channel` | Port of the official Telegram plugin |
| `maximeoliv/claude-code-matrix-channel` | Voice and images, permission relay |
| `TadMSTR/matrix-channel` | "permission relay and agent comms"; forwards only one allowlisted MXID |
| `coffeegrind123/prinny-channel` | E2EE, buttons |
| `arikw/claude-code-matrix-bridge` | Always-on daemon, per-session routing, headless fallback |
| `HutsonLabs/matrix-mcp-server` | Archived |
| `Dave700r/…`, `heintonny/claude-matrix-plugin` | E2EE-first |
| `kazamatzuri/matrix-claude-channels`, `Jazb/matrix-channel` | — |

**Slack:**
- `jeremylongshore/claude-code-slack-channel` (40★) is the most relevant. It supports **`allowBotIds` opt-in cross-bot delivery**, mention-to-engage by default (*"peer agents must `@`-mention every time"*), per-(channel, bot) rate limits, a circuit breaker, and the rule that peer bots cannot approve permissions.
- Others: `eric108lucas/claude-code-slack-channel`, `retrodigio/claude-channel-slack`, `AppGambitStudio/Claude-Code-Slack-Channel`, `osisdie/claude-code-channels` (multi-platform).

**IRC:**
- `sabotazysta/smalltalk-channel`: channel plugin on the Ergo ircd. *"Agents can talk to each other freely (no bot-to-bot restrictions)"*.
- `Meme-Theory/claude-comms`: two Claude Code sessions over IRC.
- Also `Shinichi-Aoyagi/claude-irc-channel`, `ezagent42/claude-zchat-channel`, and a skill-based `0xultravioleta/irc-agent-skill`.

**Mattermost:**
- `todd-chamberlain/claude-channel-mattermost` and `huyeon123/mattermost-claude-channel`.
- Process bridges rather than channels: `DigitalCyberSoft/claude-mattermost`, `tijszwinkels/mattermost-agent-bridge`.

**Zulip:**
- `PeteMichaud/zulip-claude-fleet` (`zulip-channel.ts`; one bot per stream).
- `meowkey-dev/machine-plugins` (plugins/zulip).
- `CodeForBreakfast/commy`: an inter-agent substrate on Zulip with **both** `clients/claude-code` and `clients/hermes` (a Hermes platform plugin).

**XMPP:** `zh/xmpp-channel` (allowlist on JID).

**A2A:** `jjacke13/claude-peer`, pushed 2026-10-05, 0★.
- An A2A v1.0 endpoint for a *live* Claude Code session. Inbound `SendMessage` becomes `<channel source="plugin:peer:peer" task_id=…>`, answered via `reply_peer`.
- Outbound `ask_peer`, bearer token, bind to a VPN IP, built-in loop guard.
- Designed for a private overlay network. This is the most direct Claude Code ↔ Hermes A2A pairing.

**NATS:**
- `synadia-ai/synadia-agents` (84★): Synadia Agent Protocol for NATS, with harness plugins for **Claude Code (channel plugin; permission relay as `query` chunks)**, **Hermes** (on the `synadia-ai/hermes-agent` `nats-gateway` branch, upstream PR pending), OpenClaw, OpenCode, Codex, PI and more. Subjects follow `agents.prompt.<type>.<owner>.<name>`.
- Also `elasticdotventures/_b00t_` (`nats-hive` channel).

**Pub/sub standards:**
- `Cotal-AI/Cotal` (317★, active): "open pub/sub standard for AI agents" on NATS/JetStream, JWT-authed, cross-machine. Connectors for **Claude Code (plugin + hooks), Hermes (gateway daemon + plugin)**, OpenCode, Codex, Jcode and pi. *"all six push, so a peer message wakes an idle agent"*.
- `sharpTrick/parley`: transport-agnostic MCP seam over SQLite, Redis, Matrix, XMPP or NATS.

**Multi-protocol hubs:**
- `firstintent/a2a-bridge`: "Claude Code, Codex, OpenClaw, Hermes Agent, Gemini CLI… talk to each other".
- `raysonmeng/agent-bridge` (374★): Claude Code ↔ Codex, local only.
- `infiquetra/hermes-claude-code-router`: Hermes plugin that routes Discord to Claude Code via a redis-bridge channel.

**Other:** WeChat, Feishu, LINE and iMessage-via-Linq channels exist in large numbers. `wuzf/claude-channels-patch` patches the binary to bypass the allowlist and is not recommended.

---

## 3. OpenClaw (formerly Clawdbot / Moltbot)

Source: `openclaw/openclaw:docs/`, published at docs.openclaw.ai.

Channels: about 49 channel docs. They include Matrix, Slack, Discord, Telegram, **IRC**, Mattermost, Signal, WhatsApp, iMessage/BlueBubbles, MS Teams, Google Chat, Nextcloud Talk, **Nostr**, Buzz, Raft, Synology, Twitch, Zalo, X, QQ, WeChat and WeCom, plus **A2A**.

Agent-to-agent features:
- **`sessions_send`**: cross-agent session tools, **on by default**, governed by `tools.agentToAgent.{enabled, allow}` and per-agent `send` lists. Calls look like `sessions_send({agentId, message})` and the reply comes back (`gateway/config-tools/sessions-and-subagents.md`). This is multi-agent routing *within one gateway*.
- **A2A channel plugin** (`channels/a2a.md`): A2A 1.0 JSON-RPC at `/a2a/v1`, Agent Card at `/.well-known/agent-card.json`, per-peer bearer tokens. The docs' own example peer is named `hermes`. It also sends to configured peers.
- **Bot-to-bot:** `channels/bot-loop-protection.md` says *"Discord and Slack default to accepting [other bots' messages] under the normal mention and access rules"*. Matrix uses `allowBots: true|"mentions"`. Pair loop protection allows 20 events per 60s, then a 60s cooldown.
- **`openclaw mcp serve`** (`cli/mcp/serve.md`): a stdio MCP bridge to OpenClaw conversations. Its `--claude-channel-mode auto|on|off` (default auto = on) **emits `notifications/claude/channel` and permission notifications**, so it is effectively a ready-made Claude Code channel for every OpenClaw-connected platform. In Claude Code it still needs the development-channels flag. Hermes's `mcp serve` copied the tool surface but not the push.
- **ACP:**
  - `openclaw acp` exposes a Gateway session as an ACP server (stdio or WebSocket).
  - The ACP agents runtime (acpx) lets OpenClaw *drive* Claude Code, Gemini CLI, Codex, OpenCode and Cursor via `/acp spawn` or `sessions_spawn({runtime:"acp"})`, bound to chat conversations (`tools/acp-agents.md`).

---

## 4. Codex CLI, Gemini CLI, OpenCode, Goose

**Codex CLI** (https://learn.chatgpt.com/docs/developer-commands?surface=cli; the `developers.openai.com/codex/cli/reference` page 308-redirects there):
- `codex mcp-server` has been **removed**. Use `codex app-server` instead, which is experimental and runs over stdio, WebSocket or a Unix socket.
- `codex exec` gives non-interactive runs with `--json` JSONL and `resume`.
- `codex mcp add` makes it an MCP client (stdio or streamable HTTP).
- `codex remote-control start|stop|pair` is experimental.
- ACP comes through the `codex-acp` adapter (https://agentclientprotocol.com/get-started/agents).
- It has no chat channels of its own.

**Gemini CLI:**
- MCP client.
- **`--acp`** mode: JSON-RPC over stdio for programmatic control. It replaces the deprecated `--experimental-acp` (https://geminicli.com/docs/cli/acp-mode/, via search summary).
- No messaging or server mode.

**OpenCode:**
- **`opencode serve`** is a headless HTTP server with an OpenAPI spec at `/doc` (https://opencode.ai/docs/server/). Defaults to `127.0.0.1:4096`, with `--mdns` and basic auth via `OPENCODE_SERVER_PASSWORD`.
  - `POST /session` creates a session.
  - `POST /session/:id/message` is synchronous; `/prompt_async` returns 204.
  - SSE streams are `GET /event` and `/global/event`.
- This is the cleanest "send a prompt over HTTP" surface among the coding CLIs. Bind it to a Tailscale IP.
- It is also an ACP agent and MCP client.

**Goose:**
- MCP-native: its extensions are MCP servers.
- **`goose acp`** is an ACP agent over stdio (https://goose-docs.ai/docs/gdk/acp/, via search summary).
- It can also *use* external ACP agents as providers.
- No chat gateway.

---

## 5. Zed's Agent Client Protocol (ACP): is it agent-to-agent?

Source: https://agentclientprotocol.com/overview/introduction. The spec *"standardizes communication between code editors/IDEs and coding agents"*, modeled on LSP:
- Local agents run as editor subprocesses over **JSON-RPC on stdio**.
- Remote agents over HTTP or WebSocket are *"a work in progress"*.
- The spec says nothing about agent-to-agent communication.

ACP is therefore a **client → agent control protocol**. The client owns the conversation and drives prompts, permissions and file I/O. It is not a peer messaging protocol.

ACP is still useful as a **uniform way for an orchestrator or bridge to drive many harnesses**. The client registry (https://agentclientprotocol.com/get-started/clients) lists:
- **Orchestrators:** Jockey (Claude Code + Gemini CLI + Codex via ACP), Raven (DAG), CompozyOS, Kronos, AgentConnect (puts ACP agents into Slack, Telegram, Discord, Lark, GitHub and GitLab).
- **Chat bridges:** OpenACP and acp-connector (Telegram, Discord, Slack); **Zooid (Matrix)**; cc-connect and VibeAround (many platforms).
- **CLI client:** acpx, which OpenClaw uses internally.

Agents in the ACP registry (https://agentclientprotocol.com/get-started/agents) include Claude (via Zed's `claude-agent-acp`), Codex (via `codex-acp`), Gemini CLI, OpenCode, Goose, **Hermes Agent** and **OpenClaw**.

Implication: a bridge such as Zooid (Matrix) or OpenACP can put *any* ACP harness into a chat room, Hermes and Claude Code included. Each agent then becomes a bridge-owned puppet. You get a uniform transport, but you lose each harness's own gateway features, and with Claude Code you go through the Agent SDK adapter rather than your live interactive session.

---

## 6. Platform-level bot-sees-bot facts

**Telegram:** this has **changed** since the commonly cited rule.
- The FAQ still says *"bots will not be able to see messages from other bots regardless of mode"* (https://core.telegram.org/bots/faq).
- But the Bot API changelog for **Bot API 10.0 (May 8, 2026)** added *"the ability to send messages to other bots via username if both bots enabled bot-to-bot communication"* and *"the ability to see certain messages sent by other bots in groups"*. The latest version is 10.3 (Aug 24, 2026). Source: https://core.telegram.org/bots/api-changelog
- https://core.telegram.org/bots/features describes what a bot can now receive from other bots:
  - `/command@OtherBot` mentions.
  - Replies to the bot's own messages.
  - With **Bot-to-Bot Communication Mode** enabled in @BotFather, *all* messages from other bots in a group, provided the receiver is an admin or has privacy mode off. *"If at least one bot has the mode enabled"*.
  - Bot-to-bot DMs need the mode on for both bots.
- Telegram also requires loop safeguards.
- Hermes already ships `TELEGRAM_ALLOW_BOTS` and a loop guard. The official Claude Code Telegram plugin would still need the Hermes bot's ID in its group `allowFrom`. Its compatibility with the new mode was not verified.

**Discord:** bots receive other bots' messages through the gateway. Filtering is up to the adapter:
- Hermes defaults to `none`; turn on `mentions`.
- OpenClaw defaults to accepting them.
- **The official Claude Code Discord channel hard-drops them.**

**Slack:** bot posts arrive as events (`bot_id`, `subtype: bot_message`). Filtering is again up to the adapter:
- Hermes `allow_bots`.
- jeremylongshore's Claude Code Slack channel `allowBotIds`.
- OpenClaw accepts them by default.

**Matrix, IRC, XMPP, Mattermost, Zulip:** no protocol-level bot class, so every agent is just a user account. Gating is per adapter allowlist and mention. These are the friendliest platforms for agent rooms and can be self-hosted (Synapse/Conduit, Ergo) on the tailnet.

---

## 7. Key implications for the Claude Code ↔ Hermes over Tailscale setup

1. **No chat platform is natively supported by both with bot-to-bot working out of the box.**
   - Official Claude Code channels cover only Telegram, Discord and iMessage. Discord drops bot authors, and Telegram depends on the new Bot-to-Bot mode.
   - Hermes supports nearly everything.
   - **Matrix** is the best shared room: Hermes has native E2EE support, about 10 community Claude Code channels exist, Matrix has no bot-visibility restriction, and you can self-host the homeserver on the tailnet. **IRC** (Ergo) is the minimal alternative: Hermes is native, and smalltalk-channel is explicitly built for agent-to-agent. **Slack** works if you use jeremylongshore's channel with `allowBotIds` and Hermes `allow_bots: mentions`.
   - All community Claude Code channels need `--dangerously-load-development-channels`, which is interactive only, or an org `allowedChannelPlugins` entry.

2. **Direct point-to-point messaging.** Hermes speaks **A2A** natively.
   - Claude Code reaches Hermes: `curl` the Hermes A2A endpoint or `/v1/responses` from Bash, or use claude-peer's `ask_peer`.
   - Hermes reaches Claude Code: needs a Claude Code-side inbound channel. That can be claude-peer (A2A), a small custom webhook channel (the docs' `webhook.ts` bound to the Tailscale IP with sender gating), or NATS (Synadia / Cotal).

3. **Claude Code's own cross-machine messaging (`SendMessage` via Remote Control) is Claude-to-Claude only** and routes through Anthropic, so Hermes can't join it. Agent teams are single-machine and Claude-only.

4. **`hermes mcp serve` in Claude Code** lets Claude Code read and send through Hermes's connected platforms, but it is poll-based, with no channel push. **`openclaw mcp serve`** *does* push Claude channel notifications.

5. **Pub/sub meshes that already have connectors for both harnesses:**
   - **Cotal** (NATS, JWT, cross-machine; Claude Code plugin + Hermes connector).
   - **Synadia agents** (NATS; the Hermes plugin is on a fork branch).
   - **commy** (Zulip-backed; Claude Code + Hermes clients).

6. **Loop safety** is built into Hermes (bot loop guard, A2A ping-pong cap), OpenClaw (pair guard), Claude Code cross-session messaging (throttle) and jeremylongshore's Slack channel. Custom Claude Code channels must implement their own.
