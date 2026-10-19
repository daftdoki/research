# Community sweep: what people actually use to let agents from different harnesses talk (as of 2026-10-10)

Scope: tools for Claude Code / Codex / Gemini CLI / Hermes Agent / OpenClaw / OpenCode / Cursor / Pi agents to message each other, share rooms/channels, or coordinate, especially across machines. The ranking leans on traction: HN points and comments, GitHub stars, and repeated recommendations in comments.

Stars come from ungh.cc or the GitHub MCP search on 2026-10-10. HN numbers are story points/comments from the Algolia API (stories since 2025-01-01). Caveat: several 2026 repos have suspicious star/fork/issue ratios (e.g. sno-station 505★/363 forks, omnigent 1.8k open issues), so stars alone are weak evidence.

## 1. Query log

### Hacker News Algolia (worked well, the primary source)
`search?tags=story&numericFilters=created_at_i>1735689600`, sorted by points locally. Scripts: hnq.py, hncount.py, thread.py, urls.py (in scratchpad).
- Batch 1 (all worked): agents talk to each other; agent chat room; claude code codex chat; multi-agent chat; agent mail; agent to agent messaging; Show HN agent coordination; agent relay; agent mesh; inter-agent; agents irc; agents slack; agents matrix; hermes agent; openclaw; claude code channels; A2A; agent communication protocol; mcp agent coordination; swarm claude code; agent orchestration tmux; mcp_agent_mail; Gas Town; beads; claude-squad; coding agents coordinate; multiple coding agents; Slack for agents; Discord for agents; agents chat with each other.
- Batch 2 (worked, but short or ambiguous names gave noise: aweb, hcom, clink, AG2, Thenvoi, Band): aweb; agent relay workforce (0 hits); agentchattr; Coral Protocol; hcom; claude-flow; ruflo; Agent-MCP; zen mcp; clink; Moltbook; Letta multi-agent (1 hit); AutoGen group chat (1); AG2; Thenvoi (0 relevant); Band agents; let agents talk; agents talk; claude code talk to codex; gemini cli claude code; codex claude code collaborate; claude code teams; agent teams; cross-machine agents; agents across machines; shared chat agents humans; multiplayer agents; agent inbox; message bus agents; agent messaging; agent network; agent-to-agent; coding agents chat; Claude Code peer; peers claude; pi coding agent; opencode agents; openclaw agents talk; openclaw discord; openclaw matrix (noise); openclaw a2a; hermes a2a (noise); ACP agent client protocol; Zed ACP; MCP channel.
- Batch 3, name lookups: Claude Tag; Slack Code; Buzz Block; cross-session messaging; agmsg; herdr; OpenRig; Alook (noise); Scion; tutti (noise); Munder Difflin; Omnigent; cccc (noise); Moltnet; Band agents; Thenvoi (0); Agent Relay; aweb (noise); claude-peers (0); codex-plugin-cc; OpenAgents; hcom (noise); cc-connect; AgentsMesh; Agent Teams AI; claude_codex_bridge; Clawith (0).
- Exact-phrase comment counts since 2025, giving mention frequency: mcp_agent_mail 10; claude-squad 11; claude-flow 13; ruflo 4; zen-mcp 27; Agent-MCP 38 (generic); Gas Town 472; gastown 215; beads 559 (ambiguous); Moltbook 595; CrewAI 204; AutoGen 151; Letta 75; A2A 381; Agent2Agent 22; "agent teams" 133; Vibe Kanban 54; Omnara 70; Happy Coder 19; agent-talk 11; Druids 24; Coral Protocol 4; agent-relay 3; agentchattr 0; hcom 0; Thenvoi 0; claude-peers 0; Repowire 2; Cowchat 0; AgentCouch 1.
- Threads read in full or URL-mined: 49076136 (Ask: self-host messaging for agents), 48680842 (Ask: multi-agent orchestration personal), 49847249 (Ask: leaderless), 46993479 (Ask: agent orchestrator), 48582679 (Ask: anyone using A2A?), 48936534 (agent-talk), 47828968 (agents talk without API), 47538190 (agent-to-agent pair programming), 49702303 (Radio), 46902368 (CC agent teams), 46743908 (CC Swarms), 49563355 (OpenAI agent message board), 48283108 (oacp), 49126604 (qm), 49222824 (Message your other Claude Code sessions), 48756578/49201003/48714802 (herdr), 49398152 (Munder Difflin), 47675213 (Scion), 48648039 (Claude Tag), 49374965 (Slack Code).

### Reddit (failed)
- `www.reddit.com/search.json` with UA research-bot/0.1 returned 403 (HTML block page).
- `old.reddit.com/r/ClaudeAI/search.json` returned 403 "Blocked".
- `api.pullpush.io` and `reddit.com/...search.rss` both returned 429.
- WebSearch with `site:reddit.com` / "r/ClaudeAI OR r/ClaudeCode" / "r/LocalLLaMA OR r/selfhosted" returned no Reddit threads; the site filter was not honored. No Reddit data was collected, so subreddit-level traction for r/hermesagent, r/openclaw and r/AI_Agents is unknown.

### Awesome lists (raw.githubusercontent.com, all fetched OK)
- hesreallyhim/awesome-claude-code: hits were ACC (agents-can-communicate), Repowire, OpenRig, claude-intercom, Fusion Harness, WhatsApp channel plugin.
- jqueryscript/awesome-claude-code: hits were ai-maestro, claude-cognitive, cc-connect, agent-flow, Citadel, claude-code-merge-queue.
- bradAGI/awesome-cli-coding-agents: hits were herdr (42.4k), hcom, amux, ntm, CAO (awslabs), Agent Teams AI, AgentsMesh, Clawith, claude-flow, gastown, termlink-relay, Traycer, Agentlas OS (A2A hub).
- 0xNyk/awesome-hermes-agent: hits were hermes-bus / hermes-bus-plugin (unix-socket bus), hermes-plugins (inter-agent bridge), oh-my-hermes, arelay-skills (Agent Relay app), tiny.place (agent social network), mission-control, opencode-hermes-multiagent.
- Piebald-AI/awesome-gemini-cli: hits were hcom, wolfpack (across machines), Bernstein, squads-cli, puenteo, gemini-code-flow.
- punkpeye/awesome-mcp-servers: hits were "Communication" (agent-mq, join.cloud rooms, agenthop, covalent-bond, AgoraDM over A2A, fmsg-mcp, agent-comm-hub, zulipmcp, aamio) and "Coding Agents" (magents, claude-session-relay, concord-mcp, Agent-MCP, cursor-delegate-mcp, hermes-action-bridge).
- ai-boost/awesome-a2a, e2b-dev/awesome-ai-agents, SamurAIGPT/awesome-openclaw, VoltAgent/awesome-openclaw-skills and awesome-opencode were fetched; their entries were frameworks, SDKs and skills with nothing new for coding-agent messaging.

### GitHub discovery (mcp__github__search_repositories, worked)
- "agents talk to each other claude codex" (stars): found agmsg 1544, agencycli 238, tmux-bridge-mcp 101, let-them-talk 53, open-cross-session 20, plus about 20 repos with 0-10★.
- topic:agent-communication stars:>100: found Bindu 10k, robustmq, PrismerCloud, agmsg, caspian-sdk 973, AgentWorkforce/relay 872, ai-maestro 817, sno-station 505, Cotal 317, pilotprotocol 147, agents-can-communicate 129.
- "claude-code codex messaging agents stars:>300": found cc-connect 15.9k, agent-teams-ai 2.3k, amux, VibeAround, concord-mcp.
- topic:multi-agent topic:claude-code topic:codex stars:>400: found omnigent 10.7k, munder-difflin 8.6k, codeg 3.9k, golutra 3.9k, tutti 3.8k, agor 1.4k, alook 1.3k, takt 1.4k, solo 699, hive (tt-a1i) 563, claude-council 862, claw-orchestrator 589.
- Two queries returned 0: "chat room for AI agents claude code stars:>50" and topic:inter-agent-communication.
- ungh.cc was intermittently reset or hung, so retries were needed. thenvoi/thenvoi-sdk, band-ai/band, stoops-ai/stoops, kagehq/bus and redplanethq/town were not found under those names.

### WebSearch (worked; useful for products and press, not for Reddit)
Queries run (all worked):
- reddit claude code codex agents talk chat room
- site:reddit mcp_agent_mail/agentchattr/hcom
- Hermes multi-agent / OpenClaw channel
- "Slack for AI agents" / "Discord for AI agents" (surfaced Slack Code)
- Thenvoi; band.ai; aweb.ai
- herdr messaging
- best tool Claude Code + Codex across machines (extended)
- Coral Protocol adoption
- OpenClaw sessions_send / A2A plugin
- Hermes A2A (surfaced v0.20.0 A2A plugin)
- Anthropic Claude Tag
- Block Buzz
- r/ClaudeAI talk to each other (extended)
- r/LocalLLaMA / r/selfhosted agent chat room (extended)

WebFetch was used once, on developersdigest.tech, for the Claude Code cross-session messaging details.

## 2. Tool table

Abbreviations: CC = Claude Code; Cx = Codex; Gm = Gemini CLI; OC = OpenCode; Cur = Cursor; Ocl = OpenClaw; Hm = Hermes. "XM" means cross-machine.

| Tool | URL | Stars | HN (pts/comments) | What it does | Harnesses | XM? | Rooms/channels? | Self-host? |
|---|---|---|---|---|---|---|---|---|
| Claude Code cross-session messaging (ListAgents/SendMessage, `/peers`), v2.1.224, Aug 2026 | code.claude.com | n/a (first-party) | "Message your other Claude Code sessions" 173/72 | Native DM between CC sessions via local inbox socket; accept/hold/refuse policy | CC only | Partial: remote side can reply but not initiate | No (DM) | Local |
| Claude Code Agent Teams / "Swarms" | code.claude.com/docs/en/agent-teams | n/a | 396/224 (teams); 521/335 (swarms leak) | Lead + teammates with file-based inboxes and task list; tmux/iTerm integration | CC only (cs50victor/claude-code-teams-mcp, 281★, ports it to other harnesses) | No | Team inbox | Local |
| Block Buzz | github.com/block/buzz | 35,821 | Show HN 21/7; press (SiliconANGLE Jul 21 2026) | Slack-like workspace on Nostr; agents are members with keypairs; branch = channel; ACP to drive agents | CC, Cx, goose (ACP) | Yes (relay) | Yes | Yes (Apache-2.0; hosted relay beta) |
| herdr | github.com/herdrdev/herdr | 43,249 | 404/178; 281/189 (joins YC); 166/110 | Agent multiplexer; socket API lets agents spawn panes, prompt each other, wait on each other; multiple SSH machines in one window | CC, Cx, Cur, OC, Grok, etc. | Yes (SSH machines) | No (pane-to-pane) | Local |
| Gas Town (+ beads) | github.com/gastownhall/gastown, gastownhall/beads | 18,322 / 27,785 | 403/433, 354/224, 219/234, 253/127, 113/164, 68/96 (Wasteland); beads 111/68 | Multi-agent workspace manager; `gt mail` inter-agent mail, git-backed work state; Wasteland federates "thousands of Gas Towns" | CC, Copilot, Cx, Gm, Cur | Wasteland (federation) | Mail, convoys | Yes |
| qm (YC software) | github.com/yc-software/qm | 15,379 | 682/163 | Multiplayer agent harness in Slack + web; per-person and per-room scopes; humans share agents in channels | Pi, OC, Cx, CC drive the same core | Yes (cloud deploy) | Yes (Slack channels/projects) | Yes (own cloud) |
| Claude Tag (Anthropic) | claude.com | closed | 268/184 | Claude as persistent Slack teammate in channels | Claude only | Yes (SaaS) | Yes (Slack) | No |
| Slack Code (Aug 20 2026) | slack.com/blog/news/slack-code-channels-for-agents | closed | 81/110 | Per-project code channels where agents (CC, Devin...) work with humans | CC, Devin, others via Slack | Yes | Yes | No |
| open-tag | github.com/fancyboi999/open-tag | 204 | Show HN 4/0 | OSS self-hosted Claude Tag alternative; Slack-style channels/DMs for agents + humans | CC, Cx, Copilot | Yes | Yes | Yes |
| mcp_agent_mail (Py) / mcp_agent_mail_rust | github.com/Dicklesworthstone/mcp_agent_mail | 2,199 / 186 | Show HNs 14/2, 4/0; ~10 organic comment recommendations (Ask HN self-host messaging, Swarms thread, AgentMail launch, Opus 4.6 thread) | Gmail-like MCP server: identities, inbox/outbox, threads, file leases; Git + SQLite | Any MCP client (CC, Cx, Gm, Droid...) | Yes (HTTP server) | Threads (not live rooms) | Yes |
| OpenAI codex-plugin-cc | github.com/openai/codex-plugin-cc | 34,062 | 8/1, 7/0 | Official: call Codex from CC to review or delegate | CC to Cx | No | No | Local |
| Munder Difflin | github.com/HarnessMD/munder-difflin | 8,644 | 312/145 | "Office" of clones on your subscriptions; agents coordinate in one harness | CC, Antigravity, Cx, Grok, Kimi, Gm, Qwen, OC, Crush, pi, Copilot, Cur | Sandboxes/anywhere | Office | Yes (Pro plan exists) |
| Google Scion | github.com/GoogleCloudPlatform/scion | 1,736 | 230/62; recommended in Ask HN 48680842 | Orchestration for agent teams; message-bus-ish delegation; local to hosted Hub | CC, Gm, Cx, OC | Yes (Hub) | Teams | Yes |
| ruflo (claude-flow) | github.com/ruvnet/ruflo | 74,283 | small (3/0); 13 comment mentions | Swarm orchestration, "multi-player swarms" | Mostly CC (+ others) | Partial | Swarm memory | Yes |
| OpenRig | github.com/mvschwarz/openrig | 6,724 | 8/5, 6/8 | YAML-defined agent team; CC + Cx in one rig with roles and shared context | CC, Cx, Pi | ? | Team | Yes |
| CCB claude_codex_bridge | github.com/SeemSeam/claude_codex_bridge (was bfly123) | 3,560 | cited in agent-teams thread | Multi-agent TUI with message queues and collaboration graphs; mobile app | Cx, CC, Gm, Kimi, Qwen, Cur, Copilot, Pi, OC | Mobile | Queues | Yes |
| ccg-workflow | github.com/fengshao1227/ccg-workflow | 5,937 | cited in agent-teams thread | Chinese community: Claude orchestrates Codex + Gemini | CC, Cx, Gm | No | No | Local |
| agmsg | github.com/fujibee/agmsg | 1,544 | Show HN 3/0; PH #5 of the day | Bash + SQLite cross-vendor messaging, team concept | CC, Cx, Gm, Copilot, Antigravity, OC, Hermes | No (local DB; bridges exist) | Teams | Local |
| agentchattr | github.com/bcurts/agentchattr | 1,530 | Show HN 3/0 | Local chat server; channels; @mention auto-injects prompt into agent terminal | CC, Cx, Gm, Copilot, Kimi, Qwen, Kilo... | LAN-ish | Yes | Yes |
| alook | github.com/alookai/alook | 1,331 | none | "Rooms for people and agents"; servers/channels/DMs; agents keep running locally | CC, Cx, OC | Yes | Yes | ? (npx app; hosted) |
| cccc | github.com/ChesterRa/cccc | 1,275 | none | "Coordinate coding agents like a group chat": read receipts, IM bridges, cross-instance groups | CC, Cx, ChatGPT Web, Grok, ACP agents | Yes | Group | Yes |
| tutti | github.com/tutti-os/tutti | 3,813 | none | Workspace where people and agents build; shared context | CC, Cx, Hermes | ? | Yes | Local-first |
| agor (Preset) | github.com/preset-io/agor | 1,435 | none | Multiplayer canvas for team + agents | CC, Cx, Gm | Yes | Boards | Yes |
| solo | github.com/solo-agent/solo | 699 | none | Humans + coding agents via channels, tasks, teams | CC, Cx, OC | ? | Yes | Local-first |
| hcom | github.com/aannoo/hcom | 566 | 0 HN; listed in 2 awesome lists | Hooks-based message/watch/spawn across terminals; MQTT relay for cross-machine | CC, Cx, OC, Copilot, Grok, Pi, agy, Cur, Kimi, Kilo, Gm | Yes (MQTT relay) | Event bus | Yes |
| AgentWorkforce/relay (Agent Relay) | github.com/AgentWorkforce/relay | 872 | 3/1; 4 URL mentions in CC agent-teams thread (author) | Channels, threads, DMs, real-time events for coding agents; different machines, same workspace | CC, Cx, any | Yes | Yes | Yes (+ hosted) |
| aweb | github.com/awebai/aweb | 115 | author comments in 49222824 | Identities, mail + chat, wake-ups; federation; `aw` CLI/MCP | CC, Pi, any terminal agent | Yes | Chat | Yes (MIT; hosted aweb.ai) |
| Concord | github.com/Get-Concord-AI/concord-mcp | 444 | Show HN 9/4 | MCP live messages, scope claims, handoffs | CC, Cx, Cur, Gm, Grok, Goose | No (local-first) | No | Yes |
| ai-maestro | github.com/23blocks-OS/ai-maestro | 817 | none | Dashboard, agent-to-agent messaging, war rooms, multi-machine | CC, Cx, Grok, Cur, Ocl, Hm | Yes | War rooms | Yes |
| Agent Teams AI | github.com/777genius/agent-teams-ai | 2,254 | none | Kanban; agents message and review each other | Cx, CC, OC, Cur, Grok, Kiro... | ? | Team | Local |
| AgentsMesh | github.com/AgentsMesh/AgentsMesh | 2,366 | 3/3 | Agent fleet across your machines | Many | Yes | ? | Yes |
| awslabs CLI Agent Orchestrator | github.com/awslabs/cli-agent-orchestrator | 1,406 | none | Supervisor/worker via tmux, inbox messaging | CC, Kiro, Cx | No | No | Local |
| cc-connect | github.com/chenhg5/cc-connect | 15,866 | 1/2 | Bridges local agents to Slack/Discord/Telegram/Feishu (human to agent; can share group chats) | CC, Cur, Gm, Cx | Yes | Via IM | Yes |
| agent-talk | github.com/xhluca/agent-talk | 191 | 55/24 | E2E-encrypted messages between agents across sessions/machines (skill) | Any | Yes | No | Yes |
| murmur / agent-bridge / wire (from agent-talk thread) | instavm/murmur, raysonmeng/agent-bridge, SlanchaAi/wire | 38 / 374 / 12 | comments | MCP bus / CC-Cx channel / relay with identity | CC, Cx, OC | wire: yes | murmur: bus | Yes |
| tmux-cli (claude-code-tools) | github.com/pchalasani/claude-code-tools | 2,014 | recommended in 47828968 and agent-teams threads | tmux send-keys wrapper so CC consults Cx | Any CLI | No | No | Local |
| Repowire | github.com/prassanna-ravishankar/repowire | 266 | Show HN 4/0 | Mesh for CC/OC/Cx/Pi sessions across projects and machines | CC, OC, Cx, Pi | Yes | ? | Yes |
| Radio (plasma.ai) | radio.plasma.ai | closed? | 21/15 (comments read as astroturf) | Chatroom for multiplayer agent work | CC, Cx | Yes | Yes | ? |
| Thenvoi / Band (band.ai) | band.ai, docs.thenvoi.com | closed SaaS | 0 HN; $17M seed (Sierra), Product Hunt, VentureBeat | "Slack for agents": rooms, @mention routing, MCP server for CC/Cursor, governance | CC, Cur, LangGraph, CrewAI, ADK... | Yes | Yes | No (free tier) |
| Coral Protocol coral-server | github.com/Coral-Protocol/coral-server | 253 | arXiv post 41/13 | MCP thread-based agent messaging, @mentions; now "CoralOS" | MCP agents | Remote mode WIP | Threads | Yes |
| A2A protocol | github.com/a2aproject/A2A | 26,104 | 450/280 (launch); Ask HN "anyone using A2A?" 96/45 (mostly skeptical) | Agent-to-agent protocol; OpenClaw official A2A channel plugin; Hermes v0.20 A2A plugin | Ocl, Hm, ADK, Gm (remote subagents) | Yes | No | Yes |
| ACP (Agent Client Protocol) + acpx | agentclientprotocol, openclaw/acpx | 4,407 / 3,326 | Zed CC via ACP 683/406; ACP 281/98 | Editor/host to agent protocol; used by Buzz, OpenClaw (bind CC to Discord/Telegram channels) | CC, Cx, Gm, goose... | via host | via host | Yes |
| OpenClaw channels / sessions_send | docs.openclaw.ai | 391,612 (OpenClaw) | many big threads | Gateway binds agents to Discord/Telegram/Matrix/IRC; sessions_send between agents; A2A plugin | Ocl (+ CC via ACP) | Yes | Yes (chat apps) | Yes |
| Moltbook | moltbook.com | closed (Meta-acquired) | 1652/5, 287/885, 554/383 (Meta acquires) | Social network for OpenClaw bots | Ocl | Yes | Forum | No |
| OpenAgents | github.com/openagents-org/openagents | 4,197 | 42/42 | A2A-compatible multi-agent network/workspace | Many | Yes | Yes | Yes |
| claude-squad | github.com/smtg-ai/claude-squad | 8,588 | 5/1; 11 comment mentions | Parallel session manager (no messaging) | CC, Cx, OC, Amp | No | No | Local |
| PAL (zen-mcp) clink | github.com/BeehiveInnovations/pal-mcp-server | 11,777 | 3/0; 27 comment mentions | CC calls other CLIs/models (clink) | CC, Gm, Cx | No | No | Local |
| Agent-MCP | github.com/rinadelph/Agent-MCP | 1,305 | low | MCP multi-agent coordination with shared context | MCP clients | Partial | No | Yes |
| Mysti | github.com/DeepMyst/Mysti | 1,140 | 216/178 | VS Code: CC/Cx/Gm debate then synthesize | CC, Cx, Gm | No | No | Local |
| Letta / CrewAI / AutoGen / AG2 | various | 25k / 60k / 61k / 5k | frameworks; AG2 suggested once in Ask HN | Agent frameworks with group chat; not used to bridge coding-agent harnesses | Framework agents | Yes | GroupChat | Yes |

Long tail (≤60★, mostly single Show HN or none): AgentCouch, Cowchat, crew (0xmmo), Parley, PeerTalk, AgentDM, AgentBus, oacp, Thrum, agent-exchange, smux (1.5k★ but tmux config), Moltnet, aimebu, open-cross-session (ocs, LAN), join.cloud, agent-mq, agenthop, covalent-bond, claude-session-relay, magents, let-them-talk, tmux-bridge-mcp (101), agencycli (238), agents-can-communicate (129), switchboard, kreteg, flotti, hermes-bus, ai-sns (OpenClaw-Hermes XMPP, 333★), wanman (688★, agent matrix).

## 3. Dead ends and notes
- Reddit was fully blocked (403/429) and WebSearch never returned reddit.com threads. X/Twitter was not searchable directly. Community evidence therefore rests on HN plus GitHub stars plus press.
- Thenvoi/Band has zero HN presence despite funding. Coral has only an arXiv post, and agentchattr and hcom have almost no HN discussion even with 1.5k / 566 stars.
- HN fuzzy matching makes short names (aweb, hcom, qm, Radio, Hive, Crystal, Conductor) unusable as counts.
- The Radio HN thread reads as astroturfed (many one-line praise comments).
- HN sentiment on A2A (Ask HN 48582679) is mostly "not using it; MCP or REST plus tmux send-keys is enough". One commenter cited a2a-sdk at ~10.9M monthly downloads vs MCP's 257M.
- The recurring DIY pattern in comments is tmux send-keys, a shared markdown/txt file, or a local IRC server; many people say "I built my own".
- Context event: the "OpenAI agent message board" story (collusion.wiki, 2301/1603) was about agents creating their own messaging channel. It is not a tool, but it explains heightened interest in late 2026.
- Parallel sibling agents share this scratchpad. Files such as github_sweep.md, table.md and protocols_infra.md are theirs, not mine.
