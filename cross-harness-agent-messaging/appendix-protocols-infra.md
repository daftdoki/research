# Protocols and self-hosted infrastructure for cross-harness agent messaging on a tailnet

Research date: 2026-10-10. Scope: substrates that let Claude Code, Nous Research Hermes Agent, Codex and similar agents message each other directly (DMs) and in shared multi-agent channels, across machines on a Tailscale tailnet.

Star counts and push dates come from the GitHub search API (via the GitHub MCP tool) or ungh.cc on 2026-10-10. "Read" means I fetched the page or README myself. Where I only saw a secondary source, the text says so.

---

## 0. The constraint that decides everything: how a message gets into a live agent session

A substrate is only useful if a message can wake an idle agent, not just sit there until the agent polls for it. Each harness has its own way in:

| Harness | Native inbound path for messages from elsewhere | Notes |
|---|---|---|
| **Claude Code** | **Channels** (research preview): an MCP server declares `capabilities.experimental['claude/channel']` and emits `notifications/claude/channel` → arrives as `<channel source=… meta…>` in the running session. Two-way via a normal `reply` tool. Optional `claude/channel/permission` relay. | Official plugins: Telegram, Discord, iMessage, fakechat. Custom channels need `--dangerously-load-development-channels server:<name>` (interactive only; ignored with `-p`/Agent SDK) unless an org admin allowlists them through `allowedChannelPlugins`. Stdio only. Claude Code "doesn't register a channel server that negotiates protocol revision 2026-07-28", so channel servers must stay on the older handshake MCP. Notifications are not acknowledged, are queued while busy, and are delivered as a batch on the next turn. Requires claude.ai or Console auth, not Bedrock/Vertex/Foundry. [code.claude.com/docs/en/channels], [channels-reference] |
| | Hooks (Stop/UserPromptSubmit) and polling MCP tools | Used by Murmur, a2abridge and agmsg as fallbacks. |
| **Hermes Agent** | **Messaging gateway** (`hermes gateway`): Telegram, Discord, Slack, Google Chat, WhatsApp, Signal, **Mattermost, Matrix, IRC**, Teams, SimpleX, **Buzz**, **ntfy**, Email, SMS, Home Assistant, Webhooks, **A2A**, plus an API server at `/v1`. | It has per-platform allowlists, `require_mention` defaults and `[SILENT]`/`NO_REPLY` tokens for group chats. Bot-to-bot handling is opt-in: `DISCORD_ALLOW_BOTS`, `TELEGRAM_ALLOW_BOTS`, `SLACK_ALLOW_BOTS`, `FEISHU_ALLOW_BOTS` = `none` (default) / `mentions` / `all`, and `DISCORD_BOTS_REQUIRE_INLINE_MENTION=true` (from `gateway/authz_mixin.py` and the Discord docs, via GitHub code search). [hermes messaging docs] |
| | **A2A plugin** (since roughly v0.20, Aug 2026, per a secondary news source) | Inbound: Agent Card at `/.well-known/agent-card.json` and JSON-RPC `SendMessage`/`GetTask`/SSE streaming/HMAC-signed push webhooks. Outbound tools: `a2a_discover`, `a2a_call`, `a2a_list`, `a2a_history`, `a2a_orchestrate`. Binds to localhost unless a bearer token and `A2A_HOST` are set. `A2A_PEER_TOKENS`; `A2A_MAX_PINGPONG_TURNS` caps agent loops. **No group chat.** [hermes a2a docs] |
| **Codex** | app-server / MCP / hooks; no push-into-session primitive equivalent to Claude Code channels | Cotal and Murmur drive it through `codex app-server`; agmsg notes Codex "has no Monitor" and can't be woken once idle. |

**Implication:** the strongest options are the ones where (a) Hermes already has a native gateway adapter, and (b) Claude Code has a channel plugin (official or community). Those are Matrix, Mattermost, IRC, Discord, Telegram and Buzz on the chat side, A2A on the protocol side, and Cotal (NATS) on the purpose-built side.

---

## 1. Agent protocols

### Summary table

| Protocol | Steward / status (Oct 2026) | Group / room semantics? | Self-hostable reference server? | Claude Code adapter | Hermes adapter | Verdict for this use case |
|---|---|---|---|---|---|---|
| **A2A** | Linux Foundation; **v1.0.0 released (Mar/Apr 2026)**; 26.1k★; 150+ orgs | **No.** Client→server task model. `contextId` groups tasks and messages into one conversation, and §3.5.2 allows several streams per task, all getting the same events. There are no rooms, topics or pub/sub. | Each agent *is* a server (SDKs in Python/Go/JS/Java/.NET). No central hub. | Community: a2abridge (Go, A2A 1.0 mesh plus MCP for Claude Code, Codex and Cursor), Murmur A2A bridge | **Native plugin** (inbound and outbound) | Good for 1:1 delegation. Groups need a layer on top. |
| **ACP (IBM/BeeAI)** | **Merged into A2A** under the LF (repo banner: "ACP is now part of A2A"; archived; last push 2025-08-25) | Had sessions, no rooms | n/a | n/a | n/a | Dead. Don't confuse it with Zed's *Agent Client Protocol* (editor↔agent), which Buzz uses as its harness interface. |
| **AGNTCY SLIM** | Cisco / AGNTCY (LF); IETF Internet-Draft `draft-mpsb-agntcy-slim` (-02, Jul 2026, Informational); 228★, active | **Yes.** Point-to-point, **group/multicast channels with MLS (RFC 9420) E2EE**, P2P and multicast RPC. Group channels have data and control names plus a moderator, and a Channel Manager service moderates them. | **Yes.** Rust `slim` node (Docker/Cargo/Helm), control plane, `slimctl`. Bindings for Python, Go, .NET, JS/TS, Kotlin and Java. Auth: TLS, mTLS, JWT, SPIRE. | Only indirectly: `slim-mcp` (2★) carries MCP *over* SLIM, but that is client→server tooling, not chat into a session | None | Technically the closest "real protocol" match for E2EE groups, but there's no harness integration. You'd be writing bridges. |
| **AGNTCY Directory (dir)** | AGNTCY; 195★, active | n/a (discovery) | Yes (P2P directory of OASF records) | No | No | Discovery only. Overkill for a homelab. |
| **Coral Protocol / CoralOS** | coral-server (Kotlin) 253★; rebranded "Kubernetes for AI agents" | **Yes**, sessions and threads among agents through a per-agent MCP server (`create_thread`, `send_message`, `wait_for_mention(s)`; exact names vary by version). | Yes (`./gradlew run` or Docker; needs the docker socket to spawn agents) | Possible as a plain MCP client of the per-agent URL (`/mcp/v1/{agentSecret}/mcp`), but agents are normally *spawned by* the orchestrator. Remote agents are "closed beta". There's no push, only long-poll `wait_for_mention`. | No | Orchestrator-centric. A poor fit for long-lived, independently launched harnesses. |
| **ANP** | Community (China-led); 1.4k★; spec set v1.2 | **Yes, on paper.** The ANP-09 messaging profiles include P4 `anp.group.base.v2` and P6 `anp.group.e2ee.v2` (MLS, candidate) plus mentions. DID (`did:wba`) identity. | AWiki open server (`awiki-open-server`) and Rust CLI | No | No | Interesting design with internet-scale DID focus, but heavy for a tailnet. |
| **Agora** | Oxford research protocol; python lib 69★, last push 2025-03 ("Open Beta") | No (sender/receiver, LLM-negotiated protocol documents) | Library only | No | No | Research curiosity, stale. |
| **Eclipse LMOS** | Eclipse/Deutsche Telekom; lmos-runtime 47★ | No (routes user queries to the best agent; multi-tenant/multi-channel means customer channels, not agent rooms) | Yes (Kubernetes operator, router, runtime) | No | No | Enterprise routing, wrong shape. |
| **Agent Protocol (AI Engineer Foundation → AGI, Inc.)** | REST API spec for task/step control of one agent | No | SDK stubs | No | No | Legacy (2023-era benchmarking API). |
| **NLIP (Ecma TC56)** | **ECMA-430..434 + TR/113 published 10 Dec 2025** (core message format; HTTP, WebSocket and AMQP bindings; security profiles) | Not in the core spec. The AMQP binding gives you broker topologies. | Reference implementations on GitHub (nlip-project, small) | No | No | A formal standard with near-zero harness adoption. |
| **MCP** | Current revision **2026-07-28** (stateless, no `initialize`, sessions removed, `subscriptions/listen`, Tasks moved to the `io.modelcontextprotocol/tasks` extension, MRTR replaces server-initiated elicitation/sampling; Roots/Sampling/Logging deprecated) | **No room semantics.** The spec has no way to push an unsolicited message *into the model*: `subscriptions/listen` only carries list-changed and resource-change notifications. Claude Code channels add that through a vendor-specific `notifications/claude/channel` extension. | n/a | Channels | MCP client | MCP is the *attachment* layer. Every chat bus below is reached through an MCP server, so MCP isn't the bus itself. |

### Key details

**A2A v1.0 (read: a2a-protocol.org/latest/specification).** The core operations are SendMessage, SendStreamingMessage, GetTask, ListTasks, CancelTask, SubscribeToTask, push-notification config CRUD and GetExtendedAgentCard. Bindings are JSON-RPC (§9), gRPC (§10) and HTTP+JSON (§11). v1.0 added signed Agent Cards and multi-tenancy. `contextId` (§3.4.1) is the only grouping primitive, and the spec defines no multi-party conversation. The LF press release (2026-04-09) cites 150+ orgs and v1.0 as the first stable spec. One secondary source claims A2A moved under the Agentic AI Foundation in Aug 2026; I could not confirm that.

**ACP.** The i-am-bee/acp README banner reads "ACP is now part of A2A under the Linux Foundation!" and links a migration guide. The repo's last push was 2025-08-25.

**SLIM (read: README, slim.agntcy.org overview, IETF draft listing).** Data plane routing nodes forward on hierarchical names (`org/namespace/service/<key-hash>`). The session layer handles reliability, MLS E2EE and group membership. The control plane manages routes and group membership. It "works across NAT and firewalls" over gRPC/HTTP2. Of all the protocols here, it has the most complete design for many-to-many encrypted groups.

**Coral (read: coral-server README, docs.coralos.ai writing-agents).** Each agent gets `CORAL_CONNECTION_URL` (streamable HTTP `/mcp/v1/{agentSecret}/mcp` or SSE) and `CORAL_SESSION_ID`. Sessions are created through `POST /api/v1/local/session`. Remote agents are "not common in v1.1.0" and exporting one is "closed beta".

**ANP (read: README spec index).** The full messaging profile catalogue P1–P9 includes group base semantics, group E2EE (MLS, multiple leaves per device), federation relay and mentions. There's an open server implementation (AWiki).

**MCP 2026-07-28 (read: versioning and changelog pages).** The changes that matter here: sessions and `Mcp-Session-Id` are removed; the GET SSE endpoint and `resources/subscribe` are replaced by `subscriptions/listen`; SSE resumability is removed; Tasks are now an extension with `tasks/get` polling plus `tasks/update`; MRTR replaces `elicitation/create`. **No MCP-native chat-room primitive exists.** "Chat-room MCP servers" do exist (aimebu, agents-mcp-server, Murmur, Coral, matrix-mcp-server, zulipmcp…), but they expose rooms as tools, with push only through Claude Code channels or hooks.

---

## 2. Generic chat / message infrastructure as an agent bus

### Comparison table

| System | Self-host on tailnet | How bots join | Do bots see other bots' messages? | MCP servers / agent bridges found | Hermes native? | Claude Code push path |
|---|---|---|---|---|---|---|
| **Matrix – Synapse** (4.7k★, Python+Rust) | Medium: Postgres recommended. Federation can be disabled. Any `server_name` works on a private tailnet. | A normal user account (password/token), or an appservice | **Yes.** There's no bot flag in Matrix, so a bot is just a user. Clients must filter themselves out. | mjknowles/matrix-mcp-server (52★, 15 tools, OAuth); **IA-PieroCV/cc_matrix_channel** (Rust, *Claude Code channel*, E2EE, permission relay, `allowFrom`, per-room mention-only) | **Yes** (mautrix, E2EE optional, `MATRIX_ALLOWED_USERS/ROOMS`, `MATRIX_REQUIRE_MENTION` default true, `MATRIX_FREE_RESPONSE_ROOMS`, ignores `m.notice` and `_`-prefixed appservice users) | cc_matrix_channel (dev-channel flag) |
| **Matrix – Tuwunel** (2.6k★, Rust, "official successor to conduwuit") / **Continuwuity** (1.1k★, community fork) | **Easy**: single Rust binary with embedded RocksDB | same | same | same | same (Hermes docs list Synapse, Conduit, Dendrite; any spec-compliant server should work) | same; cc_matrix_channel names Continuwuity explicitly |
| **IRC – Ergo** (3.3k★, Go) | **Easiest**: single binary, YAML, runtime rehash. Built-in services, bouncer and **always-on clients**; history in memory or MySQL; IRCv3 `chathistory`; websockets. | NickServ account (or no auth on a closed tailnet) | **Yes.** IRC has no bot distinction (convention: bots use NOTICE). | sabotazysta/smalltalk-channel (Claude Code IRC coordination plugin, 2★), mcp-irc-ts, soulshack; **aimebu** (IRC-style bus in Go for agents, MCP + web UI, 6★) | **Yes** (stdlib asyncio, TLS, `IRC_ALLOWED_USERS`, NickServ password; nicks are unauthenticated unless NickServ is enforced) | No official plugin; small community ones |
| **XMPP – Prosody / ejabberd** (6.7k★) | Easy (Prosody) to medium (ejabberd) | Normal JID; MUC rooms | **Yes** (MUC broadcasts to all occupants) | alcalin/xmpp-mcp (2★; MUC, PubSub) | **No** | None |
| **Mattermost** (39.3k★) | Medium: Go server plus Postgres. Good docker-compose. | Bot accounts with tokens; REST v4 plus WebSocket | **Yes**, as far as I can tell. The WebSocket delivers all posts in joined channels, and filtering is up to the client. | cloud-ru-tech/mcp-server-mattermost (47★), pvev/mattermost-mcp (43★) | **Yes** (`MATTERMOST_REQUIRE_MENTION` default true, `MATTERMOST_FREE_RESPONSE_CHANNELS`, `MATTERMOST_ALLOWED_USERS` (deny-all if unset), `group_sessions_per_user`) | None found (would need a custom channel) |
| **Zulip** (26k★) | Medium-heavy (Python/Django, Postgres, RabbitMQ, memcached; installer script) | "Generic" bots with API keys; event queues | **Yes**, as far as I can tell. A generic bot gets all messages in subscribed streams. | **zulip/zulipmcp** (official org, 24★: MCP server plus a listener that spawns Claude Code/Codex/OpenCode on @mention); akougkas/zulipchat-mcp (31★) | No | zulipmcp listener spawns sessions (not push into an existing one) |
| **Rocket.Chat** (46k★) | Heavy (Node + MongoDB) | Bot users; realtime API | Yes (no platform filter) | a few | No | None |
| **Discord** (SaaS) | n/a (not self-hostable) | Bot apps | Platform **delivers** bot messages, but **the official Claude Code Discord plugin hard-drops them** (`if (msg.author.bot) return`, server.ts L806). Hermes defaults `DISCORD_ALLOW_BOTS=none`. Bot-to-bot loops are a classic risk. | Official CC plugin | Yes (with `ALLOW_BOTS`) | Official channel, but you must fork it to allow bots (dev.to write-up: added `allowBots`, used hub-and-spoke to break loops, and found a permission-approval bypass) |
| **Telegram** (SaaS) | n/a | BotFather | **Historically no** (FAQ: "bots will not be able to see messages from other bots regardless of mode"). **Bot API 10.0 (8 May 2026)** added "the ability to see certain messages sent by other bots in groups" and opt-in bot-to-bot DMs by username "if both bots enabled bot-to-bot communication". The FAQ hasn't been updated. | Official CC plugin | Yes (`TELEGRAM_ALLOW_BOTS`) | Official channel (it doesn't drop bots explicitly, but the platform limits apply) |
| **Slack** (SaaS) | n/a | Apps | Bot posts emit `message`/`bot_message` events with `bot_id`. Apps usually filter them. | many | Yes (`SLACK_ALLOW_BOTS`) | None official (Claude in Slack spawns cloud sessions) |
| **NATS / JetStream** (20.9k★, Go) | **Easiest broker**: single static binary; JetStream gives durable streams, KV and per-consumer replay; accounts and JWT/nkeys ACLs. | Client connection + subject ACLs | **Yes**: pub/sub is symmetric. | **Cotal** (see §4), **Murmur** (NATS + JetStream, E2EE, A2A bridge), **Piotr1215/agents-mcp-server** (NATS+JetStream MCP *with Claude Code Channels push*), bmorphism/nats-mcp-server, lizTheDeveloper/ai-agent-messaging | Via Cotal's connector | Cotal plugin+hooks; agents-mcp-server channel |
| **MQTT** (Mosquitto 11.3k★) | Easy | Client + topic ACL | Yes | robustmq ("communication infrastructure for the AI era", mq9) and misc | No | None |
| **Redis Streams** | Easy | Consumer groups | Yes | misc | No | None |
| **ntfy** (34.7k★, Go) | Easy: single binary, HTTP pub/sub topics | Topic URL plus optional token | Yes (topic subscribers get every publish) | gitmotion/ntfy-me-mcp (76★), teddyzxcv/ntfy-mcp (45★) | **Yes** (gateway platform) | None; best kept as a human notification sink |
| **Buzz (Block)**: see §4 | Medium: relay plus Postgres, Redis and MinIO in docker-compose | Nostr keypair per agent (`BUZZ_PRIVATE_KEY`), channel membership | Agents are "members, not bots". Hermes responds only when @-addressed and never to its own messages. | `buzz-cli`, `buzz-acp` (Zed ACP harness for Goose, Codex, Claude Code), `buzz-dev-mcp` | **Yes** (gateway: NIP-42 websocket subscription) | via buzz-acp (Buzz drives the agent) |

### Notes on bot-to-bot visibility

- **Self-hosted protocols (Matrix, IRC, XMPP, Mattermost, Zulip, NATS, MQTT) do not stop agents from seeing each other.** That's what you want, but loop prevention then becomes your job. Useful guards: mention-required by default in every room except a few free-response rooms; the Hermes `[SILENT]` token; `A2A_MAX_PINGPONG_TURNS`-style turn caps; a hub-and-spoke "who may wake whom" allowlist; and a server-side rate limit.
- **The SaaS platforms each add friction.** Telegram is still partly gated (opt-in since Bot API 10.0). The official Claude Code Discord plugin drops all bot authors. Slack apps typically drop `bot_id`. None of them are on your tailnet anyway.
- **Gate on sender, not room.** The Claude Code channels-reference warns: "gating on the room would let anyone in an allowlisted group inject messages into the session". Permission relay must exclude bot senders, or else one agent can approve another's tool calls. The Discord fork author hit exactly this bug.

---

## 3. Tailscale-specific

| Offering | What it is | Relevance |
|---|---|---|
| **tsnet** | A Go library that embeds a Tailscale node in a process, which gets its own tailnet identity and IP/MagicDNS name | You can wrap any bus or relay (NATS, a custom room server, an A2A endpoint) as its own tailnet node with ACL-controlled reachability. Tailscale's "secure AI agent connectivity" page pitches this exactly: "Control which agents can talk to each other and access your MCP servers." |
| **tsidp** (679★, experimental, community project) | An OIDC/OAuth IdP backed by tailnet identity, run on tsnet. It "supports all of the endpoints required & suggested by the MCP Authorization specification, including Dynamic Client Registration", with MCP client/server and MCP gateway examples. | Gives remote HTTP MCP servers and A2A peers real auth with no shared secrets. Needs `TAILSCALE_USE_WIP_CODE=1` while below 1.0. |
| **Aperture** (Tailscale, alpha/beta; free during alpha, 6 users) | An AI gateway: an identity-authenticated LLM proxy (OpenAI, Anthropic, Google), **MCP server proxying** with identity-based access, a chat UI, and a CLI to run coding agents through it. Hosted (aperture.tailscale.com); I didn't confirm whether it can be self-hosted. | Governs agent→LLM and agent→MCP traffic. **Not an agent-to-agent messaging bus.** |
| **"Tailscale MCP"** | No official Tailscale MCP server found. Community ones (itunified-io/mcp-tailscale with 48 tools, AGPL; tailscale-blade-mcp; r167/tailscale-mcp) wrap the admin API. | Admin automation only. |
| Agent-messaging products built on tailnets | **None found.** Several tools (open-cross-session, agentlink) target LAN/cross-machine use and run fine over a tailnet, but nothing ships tsnet-native. | Gap: a tsnet-embedded Cotal/NATS or room server with tailnet identity as the agent identity would be novel. |

Practical tailnet pattern: run the bus (NATS, Matrix homeserver or Ergo) on one always-on node such as `bus.tailnet-name.ts.net`. Use Tailscale ACL tags (`tag:agent`, `tag:bus`) so only agent machines can reach the ports. Use the bus's own per-agent credentials for sender identity, because tailnet identity is per-node, not per-agent-session. Optionally use tsidp for OAuth on HTTP MCP endpoints.

---

## 4. "Slack for agents" self-hostable products and purpose-built agent buses

| Product | Stars | Transport / storage | Rooms / channels | Push into session | Claude Code | Hermes | Codex | Cross-machine | License |
|---|---|---|---|---|---|---|---|---|---|
| **Cotal** (Cotal-AI/Cotal) | 317 (created Jun 2026; very active, 498 open issues) | **NATS + JetStream**; reuses A2A `AgentCard` and `Message`/`Part` shapes | **Yes**: multicast `#channels`, durable unicast DMs, anycast-to-role work queues; presence (idle/waiting/working/offline); attention modes (open/dnd/focus); per-agent default-deny JWT ACLs; server-pinned sender identity; durable per-reader replay; web dashboard; durable workflow runs | **Yes**: "all six push, so a peer message wakes an idle agent the instant it arrives" | plugin + hooks | **gateway daemon + plugin connector** | app-server + TUI (live `steer()`) | Yes ("the broker can equally sit on a server you reach over the internet") | Apache-2.0 |
| **Buzz** (block/buzz) | 35.8k (launched Jul 2026; early, v0.4.x) | Nostr relay (Rust) + Postgres/Redis/MinIO | Channels, threads, DMs, canvases, huddles, git forge (NIP-34), workflows; every event signed | Hermes: websocket subscription. Claude Code/Codex: via `buzz-acp` (Buzz runs the agent over Zed ACP) | via buzz-acp | **native gateway platform** | via buzz-acp | Yes (relay you own) | Apache-2.0 |
| **Agent Relay** (AgentWorkforce/relay) | 872 | WebSockets; SDK `@agent-relay/sdk` | Channels, threads, DMs, group DMs, reactions, mentions, read state | Harness adapters deliver into live sessions with receipts | Yes | not mentioned | Yes | Yes | Apache-2.0 (self-host story unclear from docs; hosted workspace by default) |
| **Murmur Connect** (alexfrmn/murmur) | 19 | core NATS + SQLite outbox, optional JetStream; XChaCha20-Poly1305 E2EE | Peer DMs; "scoped channels" (flagged) | Claude Code Stop-hook wake; Codex app-server wake | Yes | No | Yes | Yes (cross-org federation) | MIT |
| **agents-mcp-server** (Piotr1215) | small | NATS + JetStream | agent registry/messages | **Claude Code Channels** | Yes | No | MCP | Yes | — |
| **aimebu** | 6 | single Go binary, SQLite, MCP + HTTP/SSE/WS + web UI | "Everything is a room" (IRC-like) | `bus_wait` long-poll and an `aimebu agent` wrapper | Yes | No | Yes | Yes (HTTP port) | — |
| **agmsg** (fujibee) | 1.5k | Bash + SQLite (local); self-hosted "reference server" for remote sync | teams | Claude Code `monitor` mode (real-time) | Yes | Yes (listed, but not spawnable) | Yes (no idle wake) | Through the reference server | — |
| **a2abridge** | 15 | A2A 1.0 (a2a-go), mTLS cross-machine | shared inbox + "broadcast" skill | A2A push webhooks + UserPromptSubmit hook | Yes | Interoperable through Hermes's A2A plugin (untested) | Yes | Yes | MIT |
| **zulipmcp** (zulip org) | 24 | Zulip | streams/topics | Listener spawns agent per @mention | Yes | No | Yes | Yes | — |
| Slack Code (Salesforce, Aug 2026) | SaaS | — | project channels with agents | — | — | — | — | — | not self-hostable |

---

## 5. Recommendations for a mixed Claude Code + Hermes homelab on a tailnet

Ranked by how much glue you'd write and how real the group semantics are:

1. **Matrix (Tuwunel or Continuwuity) is the best "boring infra" choice.** Hermes has a mature first-party Matrix adapter (E2EE, room and user allowlists, mention gating, free-response rooms, bridge-loop guards). Claude Code gets push into a live session through the community `cc_matrix_channel` Claude Code channel (Rust, E2EE, `allowFrom`, per-room mention-only, permission relay). Matrix has no bot flag, so every agent sees every other agent in a room. Rooms, threads, DMs and history are all native. Humans join from Element on the phone. Run with federation off on one tailnet node. Costs: the channel needs `--dangerously-load-development-channels` (interactive sessions only), and you must add other agents' MXIDs to `allowFrom` / `MATRIX_ALLOWED_USERS` and design loop limits.

2. **Cotal (NATS + JetStream) is the best purpose-built agent bus.** It's the only thing I found with first-class connectors for both Claude Code and Hermes, plus Codex, OpenCode and pi. It has real channels/DMs/anycast, presence, durable replay, per-agent ACLs and push wake-ups. Run one `nats-server` on a tailnet node and point every machine at it. Risks: young (Jun 2026), small community, fast-moving, TypeScript-only reference. Raw NATS underneath is rock-solid and easy to self-host, and you could fall back to it (with agents-mcp-server for Claude Code channel push) if Cotal stalls.

3. **A2A v1.0 is for 1:1 delegation alongside either of the above.** Hermes ships a native A2A server and client. On the Claude Code side, a2abridge or a small A2A→channel shim works. Use it for "Hermes, go do X and report back" task semantics with streaming and push. It has no rooms, so don't make it your group channel.

4. **Ergo IRC is the lightest group-chat option.** One Go binary, always-on clients, history. Hermes has a native IRC adapter. Claude Code would need a small custom channel, roughly 150 lines from the channels-reference template. Its identity and auth are weaker than Matrix's.

5. **Mattermost works if you want a polished Slack-like UI for humans.** Hermes is native. Claude Code needs a custom channel. It's heavier than Matrix and Ergo.

6. **Watch Buzz (Block).** It's the most "Slack for agents" product: a self-hostable relay where agents are first-class members with keys. Hermes already supports it natively, and Claude Code and Codex attach through `buzz-acp`. It's young, the stack is heavy (Postgres, Redis, MinIO), and Claude Code joins through Buzz's harness rather than as an independent session.

**Avoid as the primary bus:**
- Telegram and Discord: not self-hosted; bot-to-bot is restricted or dropped by default; loop risk.
- SLIM, ANP and Coral: no harness adapters; you'd write all the glue.
- ntfy and MQTT: fine for notifications but no conversation semantics.

**Cross-cutting tailnet hygiene:**
- Tag the bus node.
- ACL agent machines to the bus port only.
- Give each agent its own bus credential (not a shared token).
- Gate on sender ID in every channel and keep permission relay human-only.
- Default to mention-required everywhere except one or two "free-response" rooms.
- Cap agent-to-agent turns.

---

## Sources read

- A2A spec v1.0: https://a2a-protocol.org/latest/specification/ ; repo https://github.com/a2aproject/A2A ; LF press release (search result) https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year
- ACP: https://github.com/i-am-bee/acp (README banner)
- SLIM: https://github.com/agntcy/slim ; https://slim.agntcy.org/latest/slim/slim-overview/ ; https://datatracker.ietf.org/doc/draft-mpsb-agntcy-slim/ ; https://github.com/agntcy/slim-mcp-python
- AGNTCY dir: https://github.com/agntcy/dir
- Coral: https://github.com/Coral-Protocol/coral-server ; https://docs.coralos.ai/guides/writing-agents ; https://docs.coralos.ai/welcome
- ANP: https://github.com/agent-network-protocol/AgentNetworkProtocol
- Agora: https://github.com/agora-protocol/python ; LMOS: https://github.com/eclipse-lmos/lmos-runtime ; Agent Protocol: https://github.com/AI-Engineer-Foundation/agent-protocol
- NLIP: https://ecma-international.org/news/ecma-international-approves-nlip-standards-suite-for-universal-ai-agent-communication/ (search summary); https://github.com/nlip-project/documents
- MCP: https://modelcontextprotocol.io/specification/versioning ; https://modelcontextprotocol.io/specification/2026-07-28/changelog
- Claude Code channels: https://code.claude.com/docs/en/channels ; https://code.claude.com/docs/en/channels-reference ; plugin source https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins (discord/server.ts L806 `if (msg.author.bot) return`)
- Hermes: https://github.com/NousResearch/hermes-agent ; https://hermes-agent.nousresearch.com/docs/user-guide/messaging ; …/messaging/matrix ; …/messaging/a2a ; …/messaging/irc ; …/messaging/mattermost ; …/messaging/buzz ; code search `gateway/authz_mixin.py` (`*_ALLOW_BOTS`)
- Telegram: https://core.telegram.org/bots/faq ; https://core.telegram.org/bots/api-changelog (Bot API 10.0, 2026-05-08)
- Slack bot_message: https://docs.slack.dev/reference/events/message/bot_message
- Discord fleet write-up: https://dev.to/vladonemo/making-a-fleet-of-claude-code-agents-talk-to-each-other-over-discord-5ei7
- Matrix: https://github.com/matrix-construct/tuwunel ; https://github.com/IA-PieroCV/cc_matrix_channel ; https://github.com/mjknowles/matrix-mcp-server
- Ergo: https://ergo.chat/about ; https://github.com/ergochat/ergo/blob/master/docs/MANUAL.md
- Zulip: https://github.com/zulip/zulipmcp ; XMPP: https://github.com/alcalin/xmpp-mcp ; Mattermost MCP: https://github.com/cloud-ru-tech/mcp-server-mattermost
- NATS buses: https://github.com/Cotal-AI/Cotal ; https://github.com/alexfrmn/murmur ; https://github.com/Piotr1215/agents-mcp-server
- Others: https://github.com/AgentWorkforce/relay , https://agentrelay.com/docs/introduction ; https://github.com/fujibee/agmsg ; https://github.com/vbcherepanov/a2abridge ; https://github.com/hrubymar10/aimebu ; https://github.com/automatis-tools/agents-can-communicate
- Buzz: https://github.com/block/buzz (README); launch coverage https://forklog.com/en/block-launches-buzz-an-open-source-platform-for-teams-and-ai-agents/
- Tailscale: https://tailscale.com/use-cases/secure-ai-agent-connectivity ; https://tailscale.com/docs/aperture.md ; https://github.com/tailscale/tsidp
