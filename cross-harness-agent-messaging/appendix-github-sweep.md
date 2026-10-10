# GitHub sweep: cross-harness agent messaging / shared rooms (as of 2026-10-10)

Scope: software that lets agents from *different* harnesses (Claude Code, Hermes Agent, Codex CLI, Gemini CLI, OpenCode, OpenClaw, Pi, ...) message each other directly and/or share rooms/channels, ideally across machines (Tailscale OK) and self-hostable.

Tooling: `mcp__github__search_repositories` (71 queries incl. 2 code searches), `mcp__github__search_code` (works), raw.githubusercontent.com READMEs for 38 repos. Stars/dates below are from the GitHub search API on 2026-10-10 (`updated` = updated_at).

## 1. Queries run

| # | Query | Sort | Total | Notable hits |
|---|---|---|---|---|
| 1 | agent mail | stars | 3147 | Dicklesworthstone/mcp_agent_mail (2199), mcp_agent_mail_rust (186), awebai/aweb (115); rest noise (email MTAs) |
| 2 | multi-agent chat claude code codex | stars | 49 | Sompote/tiger_cowork (62), noopolis/moltnet (29), 20Totodile/agent-collab (15), routa.kt (11), appoly/multiagent-chat (8), LambdaLabsHQ/xmatrix (7), herdr-group-chat, agent-room-cli, collab-mcp, AgentHub, amahpour/switchboard |
| 3 | agent-to-agent messaging mcp | stars | 70 | kushneryk/join.cloud (65), HUA-Labs/tap (36), junghan0611/entwurf (26), MustaphaSteph/agent-bus (20), alexfrmn/murmur (19), slima4/agent-message (18), oktsec (17), non4me/cc2cc (14), laoyudashu/voko (14), agentic-comm (5), claude-bridge (5), pollen, synapbus, AgoraHub, agentbus, agentdm, earshot-mcp, tincan |
| 4 | agent chat room claude code | stars | 20 | linuskelsey/agent-chat-room, RLabs-Inc/agent-chat-mcp, glirgang/agent-rooms (Claude channels), michaelblaess/chatterdome (tailscale), insourcedata/clanker-room (P2P federation), WarrenSchultz/chatroom-mcp (separate machines, HTTP MCP), kentlincku/aa-forum-public (ACP: Hermes/CC/Codex/pi), Alexander-Ollman/agora, zhixuanlucasfeng-cmyk/power (Hermes, opencode), TobiasCoding/agent-chat-mcp, jacazjx/agentbridge (all 0-1 stars) |
| 5 | topic:agent-to-agent | stars | 427 | 777genius/agent-teams-ai (2254), a2aproject/a2a-go (479), ai-sns/ai-sns (333, OpenClaw+Hermes A2A/XMPP), local-operator (217), markus (202), agentanycast (78), 5dive (67), join.cloud (65), abhishekgahlot2/codex-claude-bridge (62), hermes-a2a-bridge (47, archived; superseded by Hermes built-in A2A), tap (36), leeguooooo/AgentParty (34), matanrak/agent-meet (28), IronMesh (24) |
| 6 | topic:agent-communication | stars | 332 | GetBindu/Bindu (10079), robustmq (1832), fujibee/agmsg (1544), caspian-sdk (973), AgentWorkforce/relay (872), 23blocks-OS/ai-maestro (817), sno-ai/sno-station (504), Cotal-AI/Cotal (317, NATS), pilotprotocol (147), automatis-tools/agents-can-communicate (129), Riccardo8888/agent-link (58), agentmessaging/protocol AMP (36), viche (27), meet-ai (22), uam (21), open-cross-session (20), claude-intercom (19), slm-mesh (18) |
| 7 | hermes agent claude code codex messaging | stars | 11 | Noelune/dsh-agent-relay (4; dsh/Codex/CC/Hermes HMAC loopback broker), hyyu189/pneu (2; CC/Codex/Hermes/OpenClaw file mail), egregore-io/egregore-nexus (1; CC/Codex/OpenCode/Hermes event bus), ThomasMarcelis/agent-peers (Hermes plugin), MaururuTakumi/agmsg-bridges (OpenClaw+Hermes into agmsg), sushiHex/hardline-mcp, openmaxai/openmax-agent-sdk |
| 8 | topic:hermes-agent | stars | 4162 | Mostly noise (hermes-agent 252k itself, cc-switch, UIs). Signal: tutti-os/tutti (3813, multi-agent workspace w/ shared context), agent-of-empires (3331, manager not messaging) |
| 9 | topic:hermes-agent topic:multi-agent | stars | 208 | synadia-ai/synadia-agents (84; NATS agent protocol, CC/Hermes/OpenClaw/pi), hermes-agent-control-room (727; Hermes-only), hermes-agent-team (184), reevesagents (88; tmux), hermes-conductor (78), Network-AI (78) |
| 10 | topic:openclaw agent communication | stars | 26 | win4r/openclaw-a2a-gateway (552; A2A v0.3 plugin), offgrid-ing/arp (63; WS relay), voko (14), aramisfacchinetti/openclaw-a2a-plugins (5), Shy-Plus/openclaw-a2a-bridge (tailscale), msg2agent-openclaw-plugin, openclaw-buddy |
| 11 | claude code channels plugin | stars | 260 | Mostly human-chat bridges (WeChat 313, WhatsApp 103, LINE, Feishu, Slack, Discord). Agent-relevant: msanchezdev/agent-bridge (20; file group chat for CC, channels+DMs), machinepulse-ai/world2agent-plugins (CC/Hermes/OpenClaw channel adapters), aktech/pi-channels (CC channels protocol for pi), danielfbm/claude-discord-multisession |
| 12 | claude code codex gemini talk to each other | stars | 10 | fujibee/agmsg (1544), chenhg5/agencycli (238), howardpen9/tmux-bridge-mcp (101), Dekelelz/let-them-talk (53), firstintent/a2a-bridge (9; CC/Codex/OpenClaw/Hermes/Gemini/Zed via A2A+ACP hub), zqkra/plano (7), agents-mesh (2), agents-connector (2), mano7onam/puenteo (1; HTTP/SSE+A2A), qoral |
| 13 | agent relay claude code codex | stars | 129 | Mostly remote-control/handoff noise. Relevant: ebibibi/ebi-agent-chat-relay (59; CC/Codex via Discord/Teams), prakrititz/relayBrain (31; rooms + locks), sean2077/pairroom (22; 2-agent room CC/Codex/Grok), pdparchitect/buzzbox (15; Buzz chat workspace w/ Codex/CC/Goose), ai-creed/ai-whisper (8) |
| 14 | cross-machine agents messaging tailscale | stars | 0 | (too many AND terms -> 0) |
| 15 | topic:tailscale topic:claude-code | stars | 246 | Mostly phone remote-control (collie 1282, pocketdev, mimi-remote). Relevant: Hoylon/peerbridge-mcp (241; multi-agent control room, tailscale), projectmentor/hive-mind (65; P2P shared memory, Hermes/OpenClaw/CC), godfaddaai/multiplayer-ai (19), almogdepaz/wolfpack (47, multi-machine mgmt) |
| 16 | inter-agent communication coding agents | stars | 31 | let-them-talk (53), kin-cli (7), sanztheo/claude-intercom (4), CodeForBreakfast/commy (2; channels/threads across machines, Zulip-backed), zimdin12/aify-comms (Docker hub), TadMSTR/agent-bus (NATS JetStream), kickinrad/bridgey (A2A, archived), hagakiyo/a2a-relay |
| 17 | agent mesh mcp claude | stars | 55 | gossipcat-ai (41), Ggrryta/agent-mesh (9; gateway across machines), ycanerden/mesh (5; rooms), kioku-mesh (shared memory, Zenoh), markl-a/spectyn-mesh (tailscale cluster runtime), nickvasilescu/slack-agent-mesh (Slack transport for Hermes/CC/Codex), Vlad9572324/agent-mesh (self-hosted, LAN), raymond-UI/agent-switchboard (CC+pi+OpenCode) |
| 18 | agent message bus mcp | stars | 74 | MustaphaSteph/agent-bus (20), Komdosh/komnet (8; git-backed), joaquinbejar/ai-crew-sync (7; Postgres server, multi-machine), ppravdin/patchcord (4; cross-machine), smollini/AgentQueueMcp (Azure queues), biswajitpatra/agentbus, parf/ai-agent-bus, GuyMannDude/disco-bus (Discord mirror), codeprakhar25/agentwire, intercom-mcp |
| 19 | agent coordination claude code codex stars:>30 | stars | 6 | mathomhaus/guild (301; shared context/tasks, not chat), gojaja (41), edda (36), Recollect (36), relayBrain (31) |
| 20 | multi-agent messaging stars:>100 pushed:>2026-03-01 | stars | 15 | **aannoo/hcom (566; CC/Codex/OpenCode/Pi/Kimi/Antigravity message+spawn across terminals)**, mixpeek/amux (526), kirincolor/openmesh (224), opencode-ensemble (235), avirtual/clodex (124; across Mac + Linux boxes), awebai/aweb (115), agents-can-communicate (129), DeepSeek-Bot (153) |
| 21 | agents message each other claude codex in:readme stars:>50 | stars | 2511 | FAILED as a filter: in:readme w/ generic words = noise (public-apis etc.). Only lead: multica-ai/multica (52k; humans+agents team, self-hostable) - check |
| 22 | mcp chat server agents rooms | stars | 8 | dappros/ethora-mcp-server (6), kolotovalexander/mcp-huddle (2), collab-mcp, switchboard, LAPSrj/ChatMCP, agent-rooms |
| 23 | irc agents llm claude | stars | 0 | (zero - AND too narrow) |
| 24 | matrix agents claude code bridge | stars | 1 | noopolis/moltnet |
| 25 | irc ai agents | stars | 36 | turborg (18), c4pt0r/aircd (17; IRC server for agents), hrubymar10/aimebu (6; IRC-like shared rooms across harnesses+machines, MCP/HTTP/web), Marlinski/airc (5), CambrianTech/airc (3; gist-backed E2E rooms, tailscale, CC/Codex/Hermes/OpenClaw/OpenCode skills), sabotazysta/smalltalk-channel (IRC MCP plugin for CC), noblepayne/workshop, sarfata/agents-chat, JorDunn/agent-irc-channel |
| 26 | matrix mcp agents | stars | 96 | mindroom-ai/mindroom (323; Matrix-based agent chat, self-host), gebruder/wirken (190), ominiverdi/opencode-chat-bridge (110; ACP agents -> Matrix/Slack/Mattermost/etc), agentic-chatops (107) |
| 27 | claude code matrix channel | stars | 14 | IA-PieroCV/cc_matrix_channel (16), zekker6/claude-code-channel-matrix (4), nazbav (2), arikw/claude-code-matrix-bridge (2), maximeoliv, HutsonLabs/matrix-mcp-server (E2EE), TadMSTR/matrix-channel ("agent comms"), coffeegrind123/prinny-channel |
| 28 | a2a claude code | stars | 159 | vbcherepanov/a2abridge (15; A2A 1.0 mesh for CC/Codex/Cursor/Cline/Gemini), AliceLJY/telegram-ai-bridge (15; CC+Codex+Agy+Kimi in Telegram groups, A2A-TG), OdysseyFather/lingxi (19; A2A Nexus cross-device group chat), protoLabsAI/protoAgent (12), kanywst/a2acode (10; ACP->A2A), jcwatson11/claude-a2a (10), ericabouaf/claude-a2a (12), sdyuyouth/agenthop (6; pairing code, E2E, cross-network), kariemSeiam/fangai (4; wrap CLI agents as A2A servers), dwmkerr/claude-code-agent |
| 29 | acp agent client protocol bridge multi-agent | stars | 1 | allvegetable/acp-bridge (36; OpenClaw orchestrates Codex/Claude/Gemini/OpenCode via ACP) |
| 30 | topic:a2a topic:claude-code | stars | 81 | nautilus-compass (1260; memory, not msg), Cotal (317), aweb (115), hybroai/a2a-adapter (99; A2A adapter SDK for CC/Codex/Hermes/OpenClaw/pi), tamdogood/parler-protocol (15), rperez93/collab-a2a (9; A2A hub, agents on different machines), husker/a2acast (8; ntfy relay cross-machine) |
| 31 | topic:multi-agent topic:mcp topic:codex | stars | 445 | preset-io/agor (1435; multiplayer canvas), claw-orchestrator (589), claudexor (501), **raysonmeng/agent-bridge (374; CC<->Codex bidirectional)**, zenith (338), yicheng47/runner (275), peerbridge-mcp (241), sleep2agi/agent-network (91), **agent-room-alkl/agent-room (81; self-hostable MCP room CC/Cursor/Codex/Gemini/Antigravity)**, Terse-AI/terseai (68; agent rooms CLI), agent-link (58) |
| 32 | topic:agent-communication (page 2) | stars | 332 | vrknetha/clawdentity (9; DM/group chat across platforms), parasxos/postbag (9), Peuqui/AI-Connect (8; self-hosted MCP HTTP/SSE bridge across machines/accounts), spranab/swarmcode (7; Redis-backed cross-machine), fakiho/neohive (6), frane/grpvn (5), osteele/agent-loom (4; ex agent-mail, Slack), amyodov/yet-another-agentic-chat (4; ZeroMQ), DEscalanteZ (8; 2 CC on diff computers via synced folder), Kickflip73/agent-communication-protocol (7; P2P), divisionseven/opencode-mesh (3) |
| 33 | agents slack self-hosted claude codex | stars | 17 | **fancyboi999/open-tag (204; self-hosted Slack-style workspace, channels/threads/DMs w/ CC/Codex/Copilot as teammates)**, Opendray/opendray (67), agentx (13), moltnet |
| 34 | nats agents claude code | stars | 13 | mtzanidakis/praktor (44; CC-only orchestrator over NATS), murmur (19), cocodrino/bridge-harness (3; NATS CC<->Pi), lizTheDeveloper/ai-agent-messaging (2), RaistlinMuc/agentMailSystem (Codex/Gemini/CC/OpenCode mail over NATS), danmestas/synadia-agent-shim (wraps CC/codex/pi/gemini on NATS bus), saiGou-14H/a2amesh (Hermes/Codex/OpenCode/CC across machines via public NATS registry), kaushikhazra/crosschat, bob-ms/nats-channel (fork of synadia nats-channel CC plugin) |
| 35 | agent group chat coding agents | stars | 76 | **ChesterRa/cccc (1275; group-chat coordination for coding agents, read receipts, remote ops)**, anqinou-art/mousecrew (33; group chat + work board for CLI agents, headless/remote), yoqu/gonggong-space (13; self-hosted group chat, agents on teammates' machines), xmatrix (7), opensquad (7), glebis/claude-relay-mcp-server (4; across machines), amazedsaint/droidring (2; P2P E2E Hyperswarm group chat MCP), nvganta/agentschat, Krishnaa0023/coflow, JChan2787/parley |
| 36 | agent inbox mcp claude codex | stars | 13 | Mostly email-inbox skills (noise). OpenRoly/openroly (portable identity+inbox), Nyankoro2856/crewmail |
| 37 | cross-agent messaging | stars | 30 | cote-star/agent-chorus (14), patchcord (4), whooperlove/cross-agent_mcp (2), guidodl/agentmsg (Redis), barkerja/herdr-msg, LZHcode1986/herdr-link, rrrrnmtsu/agmsg-tui, projectamazonph/conduit (MQTT), utenadev/agmsg-opencode-plugin |
| 38 | tmux agents communicate claude codex | stars | 1 | ecoopnet/cc-tmux-manager (1) |
| 39 | agent federation identity messaging self-hosted | stars | 1 | awebai/aweb (115) |
| 40 | opencode agents talk each other | stars | 13 | DragonBallerZ/dragon-ide (8), GonGe1018/oh-my-msgcode (4), wiscaksono/opencode-session-bridge, mdementev/mismcp, Hackerprod/Agent-Orchestrator, marciob/openmsg, irawit1430/agent-hub, melfloc/crewhall, dianw/kreteg (MCP hub group convos CC/OpenCode/Codex) |
| 41 | gemini cli agents communicate mcp claude | stars | 3 | tap (36), zetbrush/multiagents (14), mikusnuz/agent-link-mcp (11) |
| 42 | agent hub register agents message claude code | stars | 1 | irawit1430/agent-hub |
| 43 | claude code peers multiple machines messaging | stars | 2 | Co-Messi/agent-peers-mcp (6; CC+Codex peers), edumntg/claude-broker (AMQP/LavinMQ) |
| 44 | claude-peers in:name | stars | 22 | **louislva/claude-peers-mcp (2207; CC instances message each other ad hoc)**, forks: WillyV3/claude-peers-go, hinescreative (fleet-wide), ABAELGARCH/claude-peers-cloud (cross-machine broker), kylejfrost/claude-peers-tailnet (Tailscale!), bedezign/claude-peers |
| 45 | agent-mail in:name | stars | 1284 | mcp_agent_mail (2199), mcp_agent_mail_rust (186), stelee410/agent-mailer (19; AMP async mailbox CC/Codex/Cursor/OpenClaw/Hermes), Tencent/AgentlyMail (44; no desc), andrealaforgia/agents-mailbox (10); rest email |
| 46 | agent-chat in:name | stars | 12999 | Noise (LangGraph chat UIs). ziwang-Physics/AgentChat (785, no desc - checked below) |
| 47 | agent channels claude code codex gemini opencode self-hosted rooms | stars | 0 | (too many terms) |
| 48 | topic:agent-network | stars | 64 | phronesis-io/eigenflux (1984; broadcast network for agents - check), compozy/agh (183; archived; local runtime w/ A2A networking), sleep2agi/agent-network (91), moltnet (29), fosenai/cord (14; distributed fabric across machines), hraness/valhalla (10; P2P rooms MLS-encrypted, MCP), miikkij/aimeat-protocol (8; federated self-hosted) |
| 49 | topic:inter-agent | stars | 11 | agmsg (1544), oktsec (17), harisnopen/diavlos (3; rooms w/ shared key, any computer), fabrica-land/claude-code-el-ipc |
| 50 | agent swarm messaging claude code | stars | 6 | zircote-plugins/claude-team-orchestration (15), relux-works/swarma-session-host |
| 51 | claude code hooks messaging agents wake | stars | 1 | egregore-nexus |
| 52 | zulip agents claude | stars | 9 | **zulip/zulipmcp (24; official Zulip org; agents as @mentionable bots or any MCP client)**, commy, kfet/zulip-acp (ACP agents <-> self-hosted Zulip), musubi-works/zulip-agent-team, soto-mate/agent-teams |
| 53 | xmpp agents llm | stars | 2 | vulnerability-lookup/VulnAgent (24; SPADE/XMPP, not coding agents) |
| 54 | discord agents bot-to-bot claude code codex | stars | 0 | — |
| 55 | mcp pubsub agents | stars | 9 | Cotal (317), stevenvo780/clawbus (CC/OpenClaw across hosts, WS), mmurakaru/broadcaster (Redis rooms/presence/mailboxes), jyswee/oddsockets |
| 56 | agent communication claude code codex | updated | 36 | Recent tail: Digital-Leprechaun/AgentHUB, DhanushSantosh/AgentComms, hoangsonww/AI-Agents-Orchestrator (92), jjacke13/codex-peer (A2A Codex<->CC), tulong66/agent-bus-mcp, pushan01/AgentBus, kevinArgueta96/open-agent-bridge (4; CC/Codex/Gemini via MCP+ACP), rishabhjava/agent-bus, unknownsorcerer007/ai-mesh (OpenClaw/CC/Codex), hamedbecirovic10-del/conclave, Azhovan/Threadline, huaweixiong-debug/Hermes-Wechat-Codex-Claude-Communication |
| 57 | agents talk to each other across machines | best-match | 4 | 1gr14/agents-party (10), open-cross-session (20; LAN), opcastil11/rogerthat (1; long-poll HTTP across machines) |
| 58 | hermes a2a | stars | 101 | NOTE: Hermes Agent now has BUILT-IN A2A (docs: hermes-agent.nousresearch.com/docs/user-guide/messaging/a2a); asimons81/hermes-a2a-bridge (47) archived as superseded. JuniorXcoder/hermes-virtual-office (112; meetings via A2A), emiltsoi/hermes-agent-a2a (11, archived) + emiltsoi/hermes-mesh (Ed25519 mesh relay), hopewang123456/ziyan-mailbus (7; file A2A bus Hermes/OpenClaw/Cline/OpenCode), jbellsolutions/hermes-super-agent (A2A+NATS), 001JoeJOE Feishu A2A group chat skill for OpenClaw+Hermes |
| 59 | workspace humans and agents channels self-hosted claude code codex hermes | stars | 0 | — |
| 60 | slack alternative ai agents teammates | stars | 2 | fancyboi999/open-tag (204) |
| 61 | openclaw claude code codex bridge messaging | stars | 2 | MaururuTakumi/agmsg-bridges |
| 62 | websocket relay agents mcp self-hosted claude codex rooms | best-match | 0 | — |
| 63 | agent coordination server multiple machines claude code | stars | 1 | Grayghost333/fleet-coordination-kit (Tailscale + MCP-over-SSE + Discord bridge recipe) |
| 64 | topic:agent-teams | stars | 195 | **agentscope-ai/AgentTeams (5726; multi-agent OS w/ Matrix rooms, OpenClaw-tagged)**, desplega-ai/agent-swarm (873), ccg-workflow (5937; orchestration not messaging), risingwavelabs/box0 (80), opencode-ensemble (235) |
| 65 | agent-to-agent pushed:>2026-08-01 stars:>40 | stars | 1617 | FAILED: free-text "agent-to-agent" w/o topic: matches generic "agent" repos -> noise |
| 66 | [code] "notifications/claude/channel" room | search_code | 643 files | Leads: gzapi-org/InterWeave (libp2p P2P transport + CC channel bridge), TerryCM/vibegroup (12; team's CC agents talk e2e), HelgeSverre/agentline, enowdev/succubus (18), emmahyde/deleg8, ignition-is-go/marshal (rooms broadcast identity spec), noriq-dev/noriq, jouve/matrix-channel-mcp, asheshgoplani/agent-deck (1056; TUI mgr) |
| 67 | [code] "Hermes" "OpenClaw" "Claude Code" "Codex" rooms agents chat filename:README.md | search_code | 179 files | Leads: **solo-agent/solo (699; local-first workspace, channels/tasks/teams for humans+coding agents)**, allenpeng0705/EnvoyMesh (3100; decentralized P2P mesh, P2P chat), skalesapp/skales (1953; A2A teams across paired desktops), Abilityai/trinity (637; self-hosted CC/Codex/Gemini agents platform), swarmclawai/swarmclaw (689), andyrewlee/awesome-agent-orchestrators (2153; list), ai-boost/awesome-a2a (697; list), hashgraph-online/awesome-codex-plugins -> kotinder/codex-roomcomm |
| 68 | repo:a/b repo:c/d ... (batch metadata lookup) | n/a | 12 | Used to fetch stars/desc for leads in one call (ungh.cc was flaky: timeouts/resets) |
| 69 | humans and coding agents channels workspace local-first | stars | 1 | solo-agent/solo (699) |
| 70 | peer-to-peer agents chat encrypted claude code codex | stars | 0 | — |
| 71 | topic:agent-mesh | stars | 39 | **google/agentmesh (962; A2A P2P mesh networking)**, Cotal (317), HOOLC/zork (17; local-first agent mesh across own devices, Slack), htekdev/agent-mesh (Copilot CLI) |

## 2. Ranked candidates

Ranking = relevance to the brief first (cross-harness + direct messaging/rooms + cross-machine + self-host), then stars. "XM" = cross-machine supported. "Rooms" = group channels/rooms (vs DM / point-to-point only). README-verified rows are marked (R).

### Tier A — closest fit: multi-harness, rooms/channels and/or DMs, cross-machine, self-hostable

| # | Repo | Stars | Updated | What it is | Harnesses claimed | XM | Rooms vs DM | Self-host | Found by |
|---|---|---|---|---|---|---|---|---|---|
| 1 | AgentWorkforce/relay (R) | 872 | 2026-10-10 | "Agent Relay": channels, threads, DMs, files, search, realtime events for coding agents; agents on different machines coordinate in one workspace | Claude Code, Codex, "etc" | Yes | Channels+threads+DMs | OSS CLI (`npm i -g agent-relay`); Cloud is the "easiest" path, check self-host broker | topic:agent-communication |
| 2 | ChesterRa/cccc (R) | 1275 | 2026-10-10 | Coordinate coding agents "like a group chat": durable ledger, read receipts/delivery facts, Web UI + MCP + IM bridges; "CCCC Connect" links instances | Claude Code, Codex CLI, Hermes (auto MCP setup), OpenCode, Grok Build, ChatGPT Web | Yes (CCCC Connect across instances; LAN/remote access tokens) | Group + DM | Yes, local daemon, no broker/DB | agent group chat coding agents |
| 3 | Cotal-AI/Cotal (R) | 317 | 2026-10-10 | "Open pub/sub standard for AI agents" on NATS JetStream; shared space, any topology, every agent can DM anyone | Claude Code, OpenCode, Hermes, Codex (+Cursor/Gemini via skills) | Yes ("cross-machine capable") | Channels + DM | Yes (NATS) | topic:agent-communication |
| 4 | 23blocks-OS/ai-maestro (R) | 817 | 2026-10-10 | Dashboard + agent-to-agent messaging (AMP) + memory; "multi-machine from day one, peer mesh, no central server" | Claude Code, Codex, Grok Build, Cursor, OpenClaw, Hermes, any terminal agent | Yes (peer mesh) | DM/mail (+teams) | Yes, MIT, no account | topic:agent-communication |
| 5 | aannoo/hcom (R) | 566 | 2026-10-09 | CLI that agents use to message, watch and spawn each other across terminals; hooks-based | claude, codex, opencode, copilot, gemini, pi, cursor, kimi, kilo, grok, agy, qoder, omp | Yes (`hcom relay` over MQTT) | DM + broadcast | Yes (relay token; MQTT) | multi-agent messaging stars:>100 |
| 6 | fujibee/agmsg (R) | 1544 | 2026-10-10 | Cross-vendor messaging via bash+SQLite skill; teams; no daemon | Claude Code, Codex, Gemini CLI, Copilot, Antigravity, OpenCode, Hermes (+agmsg-bridges for OpenClaw) | Optional ("self-hosted reference server", docs/remote-setup.md) | Team (group) + DM | Yes | topic:agent-communication |
| 7 | solo-agent/solo (R) | 699 | 2026-10-10 | Local-first workspace for humans + coding agents: channels, threads, task boards, channel-scoped teams | Claude Code, Codex, OpenCode, Hermes, OpenClaw (latter three via ACP) | Likely (per-machine daemon registers machine) | Channels + threads + DMs | Yes (Go) | code search README |
| 8 | fancyboi999/open-tag (R) | 204 | 2026-10-10 | Self-hosted Slack-style workspace; agents are teammates in channels/threads/DMs; daemon launches runtime on your machine | Claude Code, Codex, Copilot, OpenCode (+others) | Yes (daemon per machine, central server) | Channels+threads+DMs | Yes, explicitly | agents slack self-hosted claude codex |
| 9 | awebai/aweb (R) | 115 | 2026-10-10 | Stable agent identities, durable mail + chat, wake-up events across sessions/runtimes/machines/orgs; servers federate | Runtime-independent (CLI/HTTP/MCP); mentions Claude Code, Codex, Hermes | Yes (+federation) | Mail + chat | Yes, MIT | agent mail |
| 10 | noopolis/moltnet (R) | 29 | 2026-10-08 | "Chat room of their own": single Go binary, rooms, threads, DMs, history, browser console | Claude Code, Codex, OpenClaw, PicoClaw, TinyClaw (+any CLI) | Yes (bind all interfaces) | Rooms+threads+DMs | Yes | multi-agent chat claude code codex |
| 11 | alexfrmn/murmur (R) | 19 | 2026-10-07 | E2E-encrypted agent messaging over NATS (+JetStream), cross-org federation, A2A interop, Mac/Win apps | Claude Code, Codex, any MCP client; OpenClaw mentioned | Yes (machines, orgs) | Channels + DM | Yes (own NATS) | agent-to-agent messaging mcp |
| 12 | synadia-ai/synadia-agents (R) | 84 | 2026-10-07 | SDKs + channel plugins putting agents on NATS as `agents` micro-services (prompt/status/heartbeat) | Claude Code, Codex, OpenCode, OpenClaw, Pi, Hermes (WIP), Flue, DSPy | Yes (NATS) | RPC/prompt between agents (not chat rooms) | Yes | topic:hermes-agent topic:multi-agent |
| 13 | hrubymar10/aimebu (R) | 6 | 2026-10-04 | "IRC for you and your AI agents": shared rooms across harnesses, Docker and machines; Go binary w/ MCP, HTTP, CLI, web UI | Claude Code, Codex, Cursor (any MCP/HTTP) | Yes | Rooms (+DM) | Yes | irc ai agents |
| 14 | leeguooooo/open-cross-session | 20 | 2026-10-07 | Single local binary; sessions message/wake each other; `ocs lan pair`; Tailscale/WireGuard for different networks (successor to AgentParty, 34★, shutting down 2026-10-31) | Claude Code, Codex, Pi, Hermes | Yes (LAN + Tailscale) | DM (`name@peer`) | Yes, serverless | topic:agent-communication |
| 15 | CambrianTech/airc (R) | 3 | 2026-10-07 | "Agentic Internet Relay Chat": IRC-shaped rooms over signed events; private GitHub gist as room, E2E; delivery receipts | Skills for Claude Code, Codex, Hermes, OpenClaw, OpenCode | Yes (behind NAT; Tailscale optional) | Rooms (#project) + DM | Yes (no server; gist) | irc ai agents |
| 16 | Peuqui/AI-Connect (R) | 8 | 2026-10-10 | Small self-hosted Bridge in your LAN/VPN; MCP (HTTP/SSE); messages to one peer or `*`, status, code context | Any MCP client; Claude Code integration | Yes | DM + broadcast | Yes | topic:agent-communication p2 |
| 17 | kushneryk/join.cloud (R) | 65 | 2026-09-23 | Real-time rooms for agents: messages, shared git storage, reviews; MCP/A2A/HTTP/TS SDK | Any MCP/A2A agent | Yes | Rooms + DM | Yes (or hosted) | agent-to-agent messaging mcp |
| 18 | agent-room-alkl/agent-room (R) | 81 | 2026-10-10 | Shared room with decisions/evidence-gated tasks; MCP or REST; hosted at agent-room.com | Claude Code, Cursor, Codex, Antigravity, OpenClaw, Hermes | Yes | Rooms | "self-hostable" per description | topic:multi-agent topic:mcp topic:codex |
| 19 | raysonmeng/agent-bridge (R) | 374 | 2026-10-08 | CC <-> Codex bidirectional bridge (CC channel push); v3 (0.1.31, experimental) adds shared rooms across machines via broker | Claude Code, Codex (OpenCode/OpenClaw/Hermes/Gemini on roadmap) | Experimental (broker rooms) | Pair + rooms (v3) | Yes | topic:multi-agent topic:mcp topic:codex |
| 20 | firstintent/a2a-bridge (R) | 9 | 2026-09-05 | One daemon, star topology over A2A + ACP; any agent prompts a live Claude Code session; CC delegates to Codex | Claude Code, Codex, OpenClaw, Hermes, Gemini CLI, Zed, VS Code | Yes (`A2A_BRIDGE_CONTROL_HOST=0.0.0.0`) | Point-to-point via hub | Yes | claude code codex gemini talk to each other |

### Tier B — strong partial fits (single-machine, single-pair, protocol layer, or a different harness set)

| # | Repo | Stars | Updated | What it is | Harnesses | XM | Rooms vs DM | Self-host | Found by |
|---|---|---|---|---|---|---|---|---|---|
| 21 | Dicklesworthstone/mcp_agent_mail (R) | 2199 | 2026-10-10 | Async coordination: identities, inboxes, searchable threads, file leases; FastMCP + Git + SQLite; HTTP server w/ bearer token | Any MCP agent (Claude Code, Codex, Gemini, OpenCode, Cline, Windsurf auto-install) | Possible (HTTP server; bind beyond localhost w/ token) | Threads/mail | Yes | agent mail |
| 22 | Dicklesworthstone/mcp_agent_mail_rust | 186 | 2026-10-10 | Rust port: 34 tools, git archive, TUI | Any MCP | Same | Mail | Yes | agent mail |
| 23 | louislva/claude-peers-mcp (R) | 2207 | 2026-10-10 | CC instances discover each other and message ad hoc; broker on localhost:7899; channel push | Claude Code only | No ("localhost-only"); forks: kylejfrost/claude-peers-tailnet, ABAELGARCH/claude-peers-cloud, hinescreative (fleet-wide) | DM | Yes | claude-peers in:name |
| 24 | agentscope-ai/AgentTeams (R) | 5726 | 2026-10-10 | Multi-agent OS: Manager/Workers in a Matrix room (Tuwunel server + Element), MinIO shared FS, Higress gateway | OpenClaw, QwenPaw, Hermes, DeepSeek Harness workers (not CC/Codex natively) | Yes (containers, Matrix) | Matrix rooms | Yes | topic:agent-teams |
| 25 | win4r/openclaw-a2a-gateway (R) | 552 | 2026-10-04 | OpenClaw plugin implementing A2A v0.3; servers talk over Tailscale/LAN | OpenClaw (any A2A peer) | Yes (Tailscale shown) | P2P A2A | Yes | topic:openclaw agent communication |
| 26 | NousResearch/hermes-agent (built-in A2A) | 252535 | 2026-10-10 | Hermes now ships built-in A2A messaging (docs: hermes-agent.nousresearch.com/docs/user-guide/messaging/a2a); asimons81/hermes-a2a-bridge (47) archived as superseded | Hermes (+any A2A peer) | Yes | P2P A2A | Yes | topic:agent-to-agent / hermes a2a |
| 27 | hybroai/a2a-adapter (R) | 99 | 2026-10-09 | Wrap agent CLIs as A2A servers (`--host 0.0.0.0`) | Claude Code, Codex, Pi, OpenClaw, Hermes, n8n, LangGraph... | Yes | P2P A2A | Yes | topic:a2a topic:claude-code |
| 28 | google/agentmesh (R) | 962 | 2026-10-10 | Private P2P network for agents; nodes + relay router; exposes mesh as local MCP / OpenAI API | Any (tools/models publishing, not chat) | Yes (relays, NAT) | Service calls | Yes | topic:agent-mesh |
| 29 | phronesis-io/eigenflux (R) | 1984 | 2026-10-10 | Broadcast/communication network for agents; interest-routed broadcasts; self-host hub | OpenClaw, Codex, Claude Code | Yes | Broadcast feed | Yes (own hub) | topic:agent-network |
| 30 | multica-ai/multica (R) | 52416 | 2026-10-10 | Humans + agents workspace; agents pick up issues, report progress; daemons on your machines | Claude Code, Codex, Cursor, Copilot, Kimi, OpenCode, Hermes/OpenClaw mentioned | Yes (daemon per machine) | Issue board (+channels mentioned) - not chat-first | Yes (Docker/Helm) | in:readme (incidental) |
| 31 | preset-io/agor (R) | 1435 | 2026-10-10 | "Multiplayer AI" spatial boards; team + agents; Slack/GitHub gateway channels | Claude Code, Codex, Gemini, OpenCode, Copilot, Cursor | Yes (web server) | Boards; gateway channels | Yes | topic:multi-agent topic:mcp topic:codex |
| 32 | mixpeek/amux (R) | 526 | 2026-10-10 | Control plane: parallel workers, kanban, origin-stamped @ messaging, phone dashboard | Claude Code, Codex, Gemini CLI, OpenCode | Remote access (Tailscale mentioned), workers local tmux | @mentions | Yes (MIT+Commons Clause) | multi-agent messaging stars:>100 |
| 33 | anqinou-art/mousecrew (R) | 33 | 2026-10-03 | Group chat + work board for CLI agents; `local` or `remote` (another machine) agents | CLI coding agents | Yes | Group chat | Yes | agent group chat coding agents |
| 34 | mindroom-ai/mindroom (R) | 323 | 2026-10-10 | Matrix-based chat app for agents and humans; self-host whole stack | Its own agents (not harness bridging) | Yes | Matrix rooms | Yes | matrix mcp agents |
| 35 | ominiverdi/opencode-chat-bridge | 110 | 2026-10-08 | Bridge ACP agents to Matrix/Slack/Mattermost/Discord/Telegram | OpenCode + any ACP agent | Yes (via chat server) | Chat-platform rooms | Yes | matrix mcp agents |
| 36 | Hoylon/peerbridge-mcp (R) | 241 | 2026-10-02 | Auditable multi-agent "control room"; per-agent stdio MCP; Tailscale Serve for private remote | Codex, Claude Code, Grok, Kimi, Gemini, local | Remote UI via Tailscale | Room | Yes | topic:tailscale topic:claude-code |
| 37 | sno-ai/sno-station (R) | 504 | 2026-10-10 | Squad workstation: shared encrypted memory + "Reach" agent-to-agent messaging | Codex, Claude Code, Hermes, Cursor, OpenClaw | No (own machine) | DM | Yes | topic:agent-communication |
| 38 | automatis-tools/agents-can-communicate (R) | 129 | 2026-10-10 | Messages between CC and Codex sessions; no lead agent | Claude Code, Codex, Antigravity | No (same machine + OS user) | DM | Yes | topic:agent-communication |
| 39 | Riccardo8888/agent-link (R) | 58 | 2026-09-29 | E2E channel between two agents on two machines; transport = a shared git remote | Claude Code, Codex | Yes (git) | Pair / rooms | Yes, no server | topic:agent-communication |
| 40 | 777genius/agent-teams-ai | 2254 | 2026-10-10 | Desktop app: agent teams message each other, kanban | Codex, Claude, OpenCode, Cursor, Grok, Copilot, ... | No (desktop) | Team messaging | Yes | topic:agent-to-agent |
| 41 | howardpen9/tmux-bridge-mcp | 101 | 2026-10-07 | MCP server for cross-pane talk via tmux | Claude Code, Gemini CLI, Codex, Kimi | No | DM | Yes | claude code codex gemini talk to each other |
| 42 | Dekelelz/let-them-talk | 53 | 2026-08-14 | MCP message broker + web dashboard | Claude Code, Gemini CLI, Codex CLI | No (local) | Broker | Yes | claude code codex gemini talk to each other |
| 43 | HUA-Labs/tap | 36 | 2026-09-08 | File-based P2P protocol (git) | Claude, Codex, Gemini | Via git | DM | Yes | agent-to-agent messaging mcp |
| 44 | abhishekgahlot2/codex-claude-bridge | 62 | 2026-10-08 | CC and Codex talk through one markdown file | Claude Code, Codex | No | Pair | Yes | topic:agent-to-agent |
| 45 | MustaphaSteph/agent-bus | 20 | 2026-10-10 | Local SQLite message bus, 20 MCP tools | Claude Code, Codex, other MCP | No | Bus | Yes | agent-to-agent messaging mcp |
| 46 | slima4/agent-message | 18 | 2026-08-12 | File-based SAMP reference impl, no server | Claude Code, Codex, Cursor, Copilot, Aider | No | DM | Yes | agent-to-agent messaging mcp |
| 47 | zulip/zulipmcp | 24 | 2026-10-09 | Official Zulip org: agents as @mentionable Zulip bots or via any MCP client | Any MCP client | Yes (Zulip server) | Zulip streams/topics | Yes (self-host Zulip) | zulip agents claude |
| 48 | kirincolor/openmesh | 224 | 2026-09-30 | Messenger-style local multi-agent workspace, group chats | (own teammates; harness support unverified) | ? | Group chats + DMs | Local | multi-agent messaging stars:>100 |
| 49 | sleep2agi/agent-network | 91 | 2026-10-10 | One-command agent networking + dashboard | Claude Code, Agent SDK, Codex, Grok Build | ? | Network | Yes | topic:multi-agent topic:mcp topic:codex |
| 50 | skalesapp/skales | 1953 | 2026-10-10 | Personal agent app; "teams of agents and humans across paired desktops", A2A | Own agent (+A2A) | Yes | Teams | Local app | code search README |
| 51 | allenpeng0705/EnvoyMesh | 3100 | 2026-10-10 | Decentralized P2P agent mesh, identity, P2P chat | Own agents | Yes | P2P chat | Yes | code search README |

### Tier C — long tail (low stars, early, but on-target; worth a look if Tier A doesn't fit)

| Repo | Stars | Note |
|---|---|---|
| amahpour/switchboard | 1 | Group chat rooms for CC/Codex/Devin/Cursor "on your own machines or one shared server" |
| LambdaLabsHQ/xmatrix | 7 | Channel group chat; @claude/@codex/@cursor/@gemini run on your machine |
| yoqu/gonggong-space | 13 | Self-hosted group chat; @bot runs CC/Codex on a teammate's machine |
| 20Totodile/agent-collab | 15 | Group chat + DM channels + web UI; CC + Codex |
| Webeleven/collab-mcp | 1 | MCP chat rooms for CC/Codex/Cursor |
| RLabs-Inc/agent-chat-mcp | 1 | Per-project chat rooms; CC, Codex, Gemini CLI |
| WarrenSchultz/chatroom-mcp | 0 | CC agents on separate machines: task board + room chat + UserPromptSubmit hook injection; streamable HTTP MCP; Docker |
| insourcedata/clanker-room | 0 | Elixir room; encrypted P2P federation across machines |
| michaelblaess/chatterdome | 0 | CC sessions across machines (Tailscale) + message bus |
| Grayghost333/fleet-coordination-kit | 0 | Recipe: Tailscale + shared MCP-over-SSE server + Discord bridge |
| kylejfrost/claude-peers-tailnet | 0 | claude-peers fork for a tailnet |
| ABAELGARCH/claude-peers-cloud | 0 | Cloud broker for cross-machine claude-peers |
| CodeForBreakfast/commy | 2 | CC agents + humans share channels/threads across machines (Zulip-backed) |
| kfet/zulip-acp | 0 | Self-hosted Zulip <-> ACP coding agents relay |
| IA-PieroCV/cc_matrix_channel | 16 | Matrix channel for Claude Code (Rust); also zekker6, nazbav, arikw, HutsonLabs (E2EE), TadMSTR ("agent comms") variants |
| sabotazysta/smalltalk-channel | 2 | IRC coordination layer MCP plugin for CC |
| c4pt0r/aircd | 17 | "Modern IRC server for AI agents" |
| Marlinski/airc | 5 | IRC server for agents + humans (Rust) |
| amazedsaint/droidring | 2 | P2P E2E group chat (Hyperswarm) MCP + web/TUI |
| hraness/valhalla | 10 | P2P rooms, MLS-encrypted, MCP |
| harisnopen/diavlos | 3 | Rooms by name+shared key, any computer, Rust |
| spranab/swarmcode | 7 | Redis channel for CC on different machines + dashboard |
| joaquinbejar/ai-crew-sync | 7 | Postgres-backed coordination server: messages/tasks/presence/locks, any MCP client |
| ppravdin/patchcord | 4 | Cross-machine shared message bus for MCP clients |
| Ggrryta/agent-mesh | 9 | Gateway + skill for CC across machines |
| rperez93/collab-a2a | 9 | A2A hub for agents on different machines (CC/Codex/OpenCode) |
| husker/a2acast | 8 | A2A over ntfy relay across machines, no ports |
| sdyuyouth/agenthop | 6 | Pairing code, E2E, no public IP; CC/Codex/Cursor/Gemini/grok |
| vbcherepanov/a2abridge | 15 | A2A 1.0 mesh for CC/Codex/Cursor/Cline/Continue/Gemini |
| kanywst/a2acode | 10 | Serve ACP agents (CC/Gemini/Codex) over A2A |
| saiGou-14H/a2amesh | 0 | Hermes/Codex/OpenCode/CC across machines via public NATS registry, A2A semantics |
| danmestas/synadia-agent-shim | 0 | Wrap CC/codex/pi/gemini onto a NATS bus |
| stevenvo780/clawbus | 0 | WS bus: CC/OpenClaw across processes, containers, hosts |
| egregore-io/egregore-nexus | 1 | Event-driven middleware: CC/Codex/OpenCode/Hermes message + wake on webhooks |
| Noelune/dsh-agent-relay | 4 | HMAC loopback broker: DeepSeek Harness/Codex/CC/Hermes |
| hyyu189/pneu | 2 | File-mail for CC/Codex/Hermes/OpenClaw/Grok |
| ThomasMarcelis/agent-peers | 0 | CC/Codex local messaging + native Hermes plugin |
| MaururuTakumi/agmsg-bridges | 0 | Bridges OpenClaw & Hermes into agmsg |
| kentlincku/aa-forum-public | 0 | Mailbox + group chat web UI, per-room ACP sessions (Hermes, CC, Codex, pi) |
| zhixuanlucasfeng-cmyk/power | 0 | Mac app: CC/Codex/Hermes/opencode group chat |
| hopewang123456/ziyan-mailbus | 7 | File A2A bus: Hermes/OpenClaw/Cline/OpenCode |
| emiltsoi/hermes-mesh | 2 | Ed25519-signed Hermes fleet mesh relay |
| stelee410/agent-mailer | 19 | AMP async mailbox: CC/Codex/Cursor/OpenClaw/Hermes |
| agentmessaging/protocol | 36 | Agent Messaging Protocol (AMP) spec (federated, Ed25519); used by ai-maestro |
| offgrid-ing/arp | 63 | Agent Relay Protocol: stateless WebSocket relay (OpenClaw skills) |
| AgentAnycast/agentanycast | 78 | libp2p, NAT traversal, E2E, A2A/MCP |
| pilot-protocol/pilotprotocol | 147 | Overlay network for agents (virtual addresses, NAT traversal) |
| TerryCM/vibegroup | 12 | Team's CC agents talk to each other end-to-end |
| enowdev/succubus | 18 | One daemon/DB for agents in one repo |
| gzapi-org/InterWeave | 0 | libp2p P2P transport + Claude Code channel bridge |
| AliceLJY/telegram-ai-bridge | 15 | CC+Codex+Agy+Kimi collaborate in Telegram groups (A2A-TG), self-hosted |
| nickvasilescu/slack-agent-mesh | 1 | Slack transport for Hermes/CC/Codex agent-to-agent |
| ebibibi/ebi-agent-chat-relay | 59 | CC/Codex/AG-UI agents from Discord/Teams |
| JuniorXcoder/hermes-virtual-office | 112 | 3D office; meetings where real agents take turns over A2A |
| ai-sns/ai-sns | 333 | OpenClaw+Hermes agent "social network" over A2A/XMPP |

Lists worth mining further: andyrewlee/awesome-agent-orchestrators (2153), ai-boost/awesome-a2a (697), nMaroulis/awesome-a2a-libraries (24), AgentLineHQ/awesome-agent-communication (1), commune-dev/awesome-agent-protocols (2).

## 3. Search tricks that worked / failed

Worked:
- `topic:` qualifiers were the best signal-to-noise: `topic:agent-communication` (332 hits, 2 pages), `topic:agent-to-agent` (427), `topic:multi-agent topic:mcp topic:codex` (445), `topic:a2a topic:claude-code` (81), `topic:agent-network`, `topic:agent-mesh`, `topic:inter-agent`, `topic:agent-teams`, `topic:tailscale topic:claude-code`.
- Short 3-5 word phrases with harness names ("claude code codex gemini talk to each other", "agent group chat coding agents", "irc ai agents", "zulip agents claude") surfaced many on-target small repos.
- `in:name` for known project names (`claude-peers in:name`, `agent-mail in:name`) found the high-star originals plus forks (e.g. claude-peers-tailnet).
- Combining `stars:>N pushed:>DATE` with a specific phrase ("multi-agent messaging stars:>100 pushed:>2026-03-01") gave a tight high-star list (hcom, amux, aweb, clodex...).
- `mcp__github__search_code` works: `"notifications/claude/channel" room` (Claude Code channels used for rooms) and a README filename search for "Hermes" "OpenClaw" "Claude Code" "Codex" found solo-agent/solo, skales, EnvoyMesh, trinity that repo search missed.
- Batch metadata lookup via one repo search: `repo:a/b repo:c/d ...` (returns stars/desc for up to ~12 repos at once) — more reliable than ungh.cc here.
- Sorting by `updated` exposed the very active long tail (repos created in the last 2 weeks).

Failed / caveats:
- Too many AND terms returns 0 (e.g. "cross-machine agents messaging tailscale", "irc agents llm claude", "agent channels claude code codex gemini opencode self-hosted rooms").
- Free-text `agent-to-agent` without `topic:` and generic `in:readme` queries with `stars:>N` return famous unrelated repos (public-apis, dify, crewAI).
- `agent mail` and `agent-chat in:name` are swamped by email tooling / LangGraph chat UIs.
- Some search responses are huge (descriptions with junk); results >~100KB get spilled to a file and must be parsed (wrote a small python summarizer). Use perPage<=25 for broad queries.
- ungh.cc frequently timed out / reset; raw.githubusercontent.com README fetches were reliable.
- Stars are noisy in this space: many 2026 repos have inflated or brand-new counts; several Tier-A tools have <100 stars and were created in the last 6 months. AgentParty (hosted) shuts down 2026-10-31.
