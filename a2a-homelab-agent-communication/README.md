# A2A for agents on different homelab hosts

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What can the A2A protocol do for agents that live on different machines in a homelab, where the hosts are joined by Tailscale and the agents are mostly Claude Code? The prompt's examples (an Obsidian agent on a laptop, teams of agents on another host, either side calling the other) are illustrations. The goal is the map of the space, so the reader can find out what they don't know. ([original prompt](#original-prompt))

Assumption: "A2A" means the Agent2Agent protocol Google open-sourced in April 2025 and moved to the Linux Foundation, spec version 1.0 as of March 2026.

## Answer

A2A is a small HTTP protocol for one agent handing another agent a task and getting back status, artifacts, and follow-up questions. It is not something Claude Code speaks. Nothing in Claude Code or the Claude Agent SDK implements it, on either side. Every path that gets a Claude Code agent onto an A2A mesh goes through a third-party wrapper, and the ones that exist are one-person projects with under 15 stars each.

So the real choice for this homelab is between three ways to let agent A on the laptop and agent B on the team host talk, and A2A is only one of them:

| | Claude Code cross-session messaging | A2A over the tailnet | MCP server over the tailnet |
|---|---|---|---|
| What you build | Nothing | An A2A server wrapper on the serving host, an MCP-to-A2A bridge on the calling host | One MCP server on the serving host |
| What crosses the wire | Plain text, capped, one message at a time | Tasks with states, streamed status, artifacts (files, JSON), `input-required` round trips | Tool calls; long-running work via the 2026-07-28 tasks extension |
| Route between machines | Anthropic servers, over each machine's Remote Control connection | Tailscale only, never leaves the tailnet | Tailscale only |
| Auth | Your claude.ai login on both machines | Whatever the wrapper does; in practice Tailscale identity at the network edge | Same |
| Requires | v2.1.224+, claude.ai sign-in (not API key), Remote Control on the target | Hobby-grade wrappers, HTTPS certs enabled on the tailnet | Claude Code's built-in HTTP MCP client |
| Maturity | Shipped, documented | Spec stable at 1.0; Claude Code adapters experimental | Shipped |

My read: for "laptop session, tell the team host something" the built-in messaging already does it and there is nothing to run, but it leaves the LAN and is text-only. For "team host delegates a real job to the Obsidian agent and gets a structured result back", A2A is the protocol designed for exactly that shape, and the Tailscale side of it is straightforward. Before building it, ask whether the thing on the laptop is an agent or a tool. If a caller only ever needs "search the vault, return matches", an MCP server behind `tailscale serve` is one process, no bridge, and Claude Code connects to it natively. A2A earns its extra process when the remote side reasons, runs multiple turns, needs to ask the caller questions mid-task, or produces files as results.

One finding worth reading before the rest: if the team host is a tagged Tailscale node, `tailscale serve` sends no identity headers for its requests. The main Claude Code A2A wrapper gates on those headers. Details in [Tailscale as the auth layer](#tailscale-as-the-auth-layer).

For additional and more detailed information see the [research notes](notes.md).

## Methodology

Everything here comes from public sources read during the session, mostly through `gh api` against the source repos and `WebFetch` against the docs. Nothing was installed and no host on the tailnet was touched, per this repo's portability rule.

- The A2A spec, read from `docs/specification.md` in [a2aproject/A2A](https://github.com/a2aproject/A2A) at the `main` branch (latest released 1.0.0, tag v1.0.1 on 2026-05-28), plus `docs/whats-new-v1.md` and `docs/topics/a2a-and-mcp.md`.
- The Python SDK [a2aproject/a2a-python](https://github.com/a2aproject/a2a-python) (v1.1.4, 2026-09-08), specifically `src/a2a/utils/push_url_validator.py`.
- Claude Code docs: [cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging), [Remote Control](https://code.claude.com/docs/en/remote-control), [agent teams](https://code.claude.com/docs/en/agent-teams), [channels](https://code.claude.com/docs/en/channels), and a grep of the 356-page [docs index](https://code.claude.com/docs/llms.txt) for "a2a" and "agent2agent" (zero hits).
- Third-party wrappers: READMEs and `package.json` of [ericabouaf/claude-a2a](https://github.com/ericabouaf/claude-a2a), [AmirK-S/a2a-to-mcp](https://github.com/AmirK-S/a2a-to-mcp), [kanywst/a2acode](https://github.com/kanywst/a2acode); star counts and last-push dates from the GitHub API on 2026-09-12.
- Tailscale: the [Serve KB](https://tailscale.com/kb/1312/serve), [CLI reference](https://tailscale.com/kb/1080/cli), [app capabilities](https://tailscale.com/docs/features/access-control/grants/grants-app-capabilities), [Aperture docs](https://tailscale.com/docs/aperture/what-is-aperture), [aperture-cli](https://github.com/tailscale/aperture-cli), [tsidp](https://github.com/tailscale/tsidp), and `ipn/ipnlocal/serve.go` and `net/tsaddr/tsaddr.go` in [tailscale/tailscale](https://github.com/tailscale/tailscale).
- The [MCP 2026-07-28 release post](https://blog.modelcontextprotocol.io/posts/2026-07-28/) for the tasks extension.

## Results

### What A2A is, in one screen

From spec 1.0 ([source](https://github.com/a2aproject/A2A/blob/main/docs/specification.md)):

- Two roles. A client sends work; a server (the "remote agent") does it. Any process can be both.
- Discovery is a JSON file, the agent card, at `https://{host}/.well-known/agent-card.json`. It lists the agent's name, `skills[]` with descriptions and example prompts, `supportedInterfaces[]` (URL plus binding, in preference order), `capabilities` (`streaming`, `pushNotifications`, `extendedAgentCard`), and `securitySchemes`. Cards can be JWS-signed.
- Eleven operations: SendMessage, SendStreamingMessage, GetTask, ListTasks, CancelTask, SubscribeToTask, four for push-notification configs, and GetExtendedAgentCard.
- Three bindings that must be functionally equivalent: JSON-RPC over HTTP, gRPC, and HTTP+JSON/REST. A client picks the first one in `supportedInterfaces` it understands. Every 1.0 request carries an `A2A-Version: 1.0` header.
- A `Message` has a role and `parts[]`. A part is text, a file (inline bytes or a URL, with media type), or structured JSON `data`.
- SendMessage returns either a direct `Message` (for trivial exchanges) or a `Task`. A task has a server-generated `id`, a `contextId` that groups related tasks into one conversation, a `status.state`, a `history[]` of messages, and `artifacts[]`. Send with `return_immediately: false` (the default) and the call blocks until the task ends or pauses; send with `true` and you poll, subscribe, or take webhooks.
- Task states: `SUBMITTED`, `WORKING`, `INPUT_REQUIRED`, `AUTH_REQUIRED`, and the terminal `COMPLETED`, `FAILED`, `CANCELED`, `REJECTED`. `INPUT_REQUIRED` is the interesting one: the server parks the task and the client continues it by sending another message with the same `taskId`.
- Three ways to watch progress: poll GetTask, stream (SSE on the HTTP bindings, `TaskStatusUpdateEvent` and `TaskArtifactUpdateEvent` in order, multiple subscribers allowed), or register a webhook and let the server POST to you.
- Auth is "handled at the protocol layer, not within A2A semantics". The card can declare `apiKey`, `http` (bearer, basic), `oauth2` (auth code with PKCE, client credentials, device code), `openIdConnect`, or `mutualTLS`. Production deployments MUST use TLS.
- Extensions: an agent can declare URI-named extensions in its card and clients opt in with an `A2A-Extensions` header.

The 0.3 to 1.0 jump was breaking. Operation names changed (`message/send` became `SendMessage`), enum values went from `input-required` to `TASK_STATE_INPUT_REQUIRED`, the `kind` discriminator fields were removed, and `a2a.proto` became the normative source ([whats-new-v1](https://github.com/a2aproject/A2A/blob/main/docs/whats-new-v1.md)). Any blog post or bridge from 2025 targets the old wire format. Check the version before trusting anything.

Official SDKs: Python (`a2a-sdk`), Go, JS (`@a2a-js/sdk`), Java, .NET, Rust ([README](https://github.com/a2aproject/A2A#readme)). The Python one implements all three bindings both directions at 1.0 with a 0.3 compat mode. Sample servers exist for ADK, LangGraph, CrewAI, AG2, Semantic Kernel, LlamaIndex, BeeAI, Marvin, and Azure AI Foundry ([a2a-samples](https://github.com/a2aproject/a2a-samples/tree/main/samples/python/agents)). Google's ADK ships `to_a2a()` (in `google.adk.a2a.utils.agent_to_a2a`) to serve any ADK agent and a `RemoteA2aAgent` class to call one as a sub-agent. [a2a-inspector](https://github.com/a2aproject/a2a-inspector) is a local web UI that fetches a card, validates it, and shows raw JSON-RPC traffic. Use it before pointing a real client at a new agent.

### A2A next to MCP

The A2A project's own framing ([a2a-and-mcp](https://github.com/a2aproject/A2A/blob/main/docs/topics/a2a-and-mcp.md)): "MCP is vertical. It deepens a single agent." "A2A is horizontal. It connects agents across that boundary." An agent uses MCP for its tools and A2A to delegate to peers. The practical distinction is whether the thing on the other end has state, takes multiple turns, and may ask you a question before finishing.

That line moved in July 2026. MCP 2026-07-28 shipped the `io.modelcontextprotocol/tasks` extension: a tool call can return a task handle, the client polls `tasks/get`, and the server can enter `input_required` and get an answer through `tasks/update` ([release post](https://blog.modelcontextprotocol.io/posts/2026-07-28/)). That is most of A2A's task model inside MCP. What MCP still lacks is the peer-level pieces: an agent card for discovery, skills described in prose for another model to read, artifacts as first-class outputs, and multiple bindings. Whether those matter depends on whether anything other than Claude Code will ever call the agent.

### Where Claude Code fits

Claude Code has no A2A client and no A2A server. What it has instead:

**Cross-session messaging** ([docs](https://code.claude.com/docs/en/cross-session-messaging)). `ListAgents` and `SendMessage` reach your other Claude Code sessions. On the same machine, delivery is over a Unix socket. To a session on another of your machines it goes "through Anthropic servers, arriving over that machine's Remote Control connection." It needs v2.1.224 or later, a claude.ai sign-in (an API key or Bedrock/Vertex login can't see other-machine sessions), Remote Control running on the target, and the target listed. Messages are plain text; the receiving Claude is told the message came from another session and cannot be used to approve permissions. A `claude -p` worker binds an inbox socket and can take messages unattended with `crossSessionInbound: accept`. `isolatePeerMachines: true` forces an approval before anything leaves the machine. For a homelab on Tailscale the notable property is that this route does not use the tailnet at all.

**Agent teams** ([docs](https://code.claude.com/docs/en/agent-teams)). Mailboxes are JSON files under `~/.claude/teams/{team}/inboxes/`, "One team per session", and spawning needs an interactive session. Teams are single-machine. A team on the host cannot have a teammate on the laptop without some other transport.

**Channels** ([docs](https://code.claude.com/docs/en/channels)). An MCP server that pushes events into a running session, started with `claude --channels plugin:...`. Research preview; a channel you write yourself needs `--dangerously-load-development-channels`. This is the one built-in way an outside process can poke a session without going through Anthropic's servers, and it works in `-p`. A tailnet-only A2A-to-channel shim is possible but nobody has written one.

**Three A2A wrappers**, none from Anthropic:

| Project | Direction | Stack | State (2026-09-12) |
|---|---|---|---|
| [ericabouaf/claude-a2a](https://github.com/ericabouaf/claude-a2a) | Serve Claude Code as an A2A 1.0 agent | TypeScript, `@a2a-js/sdk` 1.x, Claude Agent SDK `query()` | 12 stars, pushed 2026-09-01, "not production ready" |
| [kanywst/a2acode](https://github.com/kanywst/a2acode) | Serve any ACP coding agent (Claude Code via `@zed-industries/claude-agent-acp`, Codex, Gemini CLI) as A2A 1.0 | Python 3.13, ships a GHCR image and `--auth-token-file` | 5 stars, pushed 2026-09-12 |
| [AmirK-S/a2a-to-mcp](https://github.com/AmirK-S/a2a-to-mcp) | Call A2A 1.0.1 agents from Claude Code as four MCP tools | TypeScript, MCP 2026-07-28 with the tasks extension | 1 star, pushed 2026-09-06, no auth either side |

claude-a2a's mapping is the one to study because it shows what the protocol can carry. A2A `contextId` maps to a Claude session id, persisted so the conversation survives a restart. When Claude calls `AskUserQuestion` or hits a permission prompt the wrapper parks the task in `TASK_STATE_INPUT_REQUIRED` with the question as a text part and the options as a JSON part; the caller answers by sending another message on the same `taskId`. CancelTask calls `query.interrupt()`. Files Claude creates come back as artifacts. Its README also has a `tailscale serve` section and a blunt warning: "Anyone who gets through reaches a Claude Code session running with `permissionMode` `acceptEdits` in the configured `cwd`. Treat access as equivalent to a shell on that directory." a2acode goes further on structure: tool calls become `working` status updates, diffs become named artifacts, and cost and turn counts ride on the completion.

a2a-to-mcp is the calling side. It exposes `a2a_discover`, `a2a_send_message`, `a2a_get_task`, `a2a_cancel_task`; you add it to `.mcp.json` as an HTTP server on `127.0.0.1:8931`. It notes that in `claude -p` "there is nobody to answer an elicitation, so Claude Code cancels it and the bridge cancels the A2A task." So `input-required` round trips only work from an interactive session on the calling side.

Wire topology for the prompt's example, team host calling the laptop:

```
team host                                              laptop
---------                                              ------
Claude Code --MCP--> a2a-to-mcp (127.0.0.1:8931)
                        |
                        | A2A JSON-RPC, A2A-Version: 1.0
                        v
              https://laptop.<tailnet>.ts.net  --> tailscale serve --> claude-a2a (127.0.0.1:3008)
                                                    (TLS, identity headers)        |
                                                                                   v
                                                                          Claude Agent SDK query()
                                                                          cwd = the Obsidian vault
```

The reverse direction is the same picture mirrored. Note that A2A itself carries no identity in this setup. Tailscale does all of it at the edge.

### Patterns the protocol supports

These are the shapes A2A was built for, sourced to the spec sections that define them. Not all of them need Claude Code on both ends.

1. **One remote agent as a callable service.** The laptop publishes a card; anything on the tailnet that can read a card can send it work. This is the Obsidian case. (Spec 8, 3.1.1.)
2. **Fan-out from an orchestrator.** A coordinator on the team host sends tasks to several remote agents with `return_immediately: true` and subscribes to each. ADK's `RemoteA2aAgent` is the off-the-shelf orchestrator; a Claude Code session with a2a-to-mcp is the DIY one. (Spec 3.2.1 blocking vs non-blocking, 3.5.)
3. **Long jobs with the caller disconnected.** Register a webhook with CreatePushNotificationConfig; the server POSTs status changes. On a two-machine homelab this means the caller runs its own HTTP listener, so a second `tailscale serve`. Streaming avoids that and reconnecting to a task with SubscribeToTask is allowed, so streaming is the better default here. (Spec 3.5, 4.3, 13.2.)
4. **Human or agent in the loop.** `INPUT_REQUIRED` lets the remote agent stop and ask. With claude-a2a that is literally Claude's `AskUserQuestion` and its permission prompts surfacing to the caller. (Spec 3.4.3.)
5. **Files as results.** Artifacts carry file parts either inline or by URL, so "write the summary into the vault and hand me the file" is a single task. (Spec 6.7.)
6. **A conversation across tasks.** Reuse `contextId` and the remote agent keeps its session; claude-a2a maps this to a resumed Claude session. (Spec 3.4.1.)
7. **A directory of agents.** The spec names registries as a discovery mechanism but defines none. On a tailnet, MagicDNS is the registry: one card per host at a predictable name. (Spec 8.2.)
8. **Mixed vendors.** The reason A2A exists at all. An ADK or LangGraph agent on the host and a Claude Code agent on the laptop can call each other without either knowing what the other is built on. If everything is Claude Code, this benefit is zero today and an option for later.

### Tailscale as the auth layer

The spec's security schemes are apiKey, http, oauth2, openIdConnect, and mutualTLS. Tailnet identity is not one of them, so an agent card cannot express "any node on my tailnet". You either declare no scheme and document that the network is the perimeter, or point an `openIdConnectSecurityScheme` at [tsidp](https://github.com/tailscale/tsidp), Tailscale's experimental OIDC provider that mints tokens from tailnet identity and implements the MCP authorization spec.

What `tailscale serve` gives you, from the [KB](https://tailscale.com/kb/1312/serve) and [serve.go](https://github.com/tailscale/tailscale/blob/main/ipn/ipnlocal/serve.go):

- TLS termination with a cert for `machine.<tailnet>.ts.net` (HTTPS certs must be enabled on the tailnet). The A2A spec's MUST-use-TLS is satisfied for free.
- Reverse proxy to a loopback port, so the agent never listens on a network interface. The KB: "it's best practice to only have the service listen on localhost."
- `X-Forwarded-For` set to the caller's tailnet address, always.
- `Tailscale-User-Login`, `Tailscale-User-Name`, `Tailscale-User-Profile-Pic` for tailnet traffic, never for Funnel.
- `Tailscale-App-Capabilities` when a grant gives the caller an `app` capability and the serve config accepts it.
- Tailnet ACLs apply to the port like any other service.

The tagged-node gotcha. `addTailscaleIdentityHeaders` in serve.go returns early with the comment "2023-06-14: Not setting identity headers for tagged nodes." A homelab "server" host is often tagged (`tag:server`) rather than owned by a user. claude-a2a's `allowedLogins` option answers 403 to any request without a `Tailscale-User-Login` header, so with a tagged caller it locks the tagged host out the moment you set it. Two fixes, neither implemented by any wrapper today:

- Run `tailscale whois --json <X-Forwarded-For>` in the backend. The [CLI reference](https://tailscale.com/kb/1080/cli) says whois returns the node, its tags, and its capability grants, for tagged devices too.
- Write a grant with `src: ["tag:agents"]` and an `app` capability, and read `Tailscale-App-Capabilities`. `addAppCapabilitiesHeader` has no tagged check; it looks up `PeerCaps` by source address.

Until one of those is patched in, the honest setup for a tagged caller is: leave `allowedLogins` unset and let the ACL decide which nodes can reach the port at all. The port is only reachable via serve, serve only accepts tailnet traffic, and the ACL names the sources. That is a real perimeter, just not one the agent can see.

Push notifications have a second tailnet quirk. `a2a-python`'s optional `validate_push_notification_url` resolves the webhook host and rejects any address that is private, loopback, link-local, multicast, reserved, or unspecified, per Python's `ipaddress` classification. Tailscale assigns every node an address in both `100.64.0.0/10` and `fd7a:115c:a1e0::/48` ([tsaddr.go](https://github.com/tailscale/tailscale/blob/main/net/tsaddr/tsaddr.go)). On Python 3.14, `100.101.102.103` reports `is_private=False` and passes; `fd7a:115c:a1e0::1` reports `is_private=True` and fails. The validator rejects if any resolved address fails, so a MagicDNS name that resolves to the ULA address as well would be refused. The validator's default on the request handler is `None`, off, so this only bites someone who turns it on. If you do, register webhooks by bare 100.x IP.

### Aperture, and where it sits

[Aperture](https://tailscale.com/docs/aperture/what-is-aperture) is Tailscale's LLM API gateway: a reverse proxy in front of OpenAI, Anthropic, Gemini, and OpenAI-compatible providers that "uses Tailscale's identity layer to automatically identify every user and device" and "injects provider API keys from its server configuration on behalf of the user." It also has connectors that "proxy connections to external MCP servers and HTTP APIs." [aperture-cli](https://github.com/tailscale/aperture-cli) launches Claude Code, Codex, Gemini CLI, OpenCode, Copilot CLI, and Cowork pointed at `http://ai`.

So Aperture is on the model-provider side of every agent, not between agents. It is relevant to this setup in one way: an A2A server on any host, wrapping any framework, can get its model credentials from the tailnet instead of from an env var, and usage per host shows up in one place. One caveat from the Remote Control docs: a custom `ANTHROPIC_BASE_URL` disables Remote Control, which disables cross-machine cross-session messaging. If you route Claude Code through Aperture, the built-in messaging column in the table above goes away and A2A or MCP over the tailnet are what is left.

## Analysis

**When A2A is the wrong tool.** One agent, one caller, both Claude Code, calls that finish in one turn: an MCP server behind `tailscale serve` is fewer moving parts and Claude Code's HTTP MCP client handles it. Text handoffs between your own sessions: cross-session messaging already exists, if you accept the route through Anthropic. A2A becomes the right tool when the remote side is a real agent (multi-turn, may ask back, produces files), when the caller and callee are on different frameworks, or when more than one caller will use the same agent and you want a card they can all read.

**The wrappers are the risk, not the protocol.** Spec 1.0 has been stable since March 2026 and the SDKs track it. The Claude Code adapters are small, recent, and honest about it. claude-a2a's README documents its own stream-ordering workarounds in the JS SDK. Expect to read source and possibly patch. The fix for the tagged-node case is maybe twenty lines in either wrapper.

**Auth is entirely Tailscale's job in this design.** That is fine for a homelab and it is what claude-a2a assumes. It also means the A2A layer is unauthenticated and the loopback bind is load-bearing. A wrapper started with `--host 0.0.0.0` on a machine with a second interface is an open shell.

**Permission modes decide what "reachable" means.** claude-a2a defaults to `acceptEdits` and bridges any prompt that mode does not auto-allow to `input-required`. a2acode surfaces every permission request to the caller as `input-required`, including commands, and its `--auth-token-file` bearer gate is for the wire, not for permissions. Either way, an A2A caller that can reach the agent and answer "yes" can edit the vault. Scope the `cwd`, use `allowedTools`, and treat the ACL as the permission system.

**Watch the MCP side.** With tasks in MCP 2026-07-28 and Claude Code negotiating that version, the gap A2A fills has narrowed to discovery, artifacts, and cross-vendor peers. If the homelab stays all-Claude, an MCP server with tasks may end up being the whole answer.

## Files

- `README.md`: this report.
- `notes.md`: the work log, including sources read, dead ends, and the raw findings the report condenses.
- `_summary.md`: one-paragraph summary for the repo index, written by the summarizer subagent.

## Original Prompt

> I'm interested in A2A uses inside of my homelab for allowing agents on other machines to talk to each other. For example, I might like an agent on my laptop that interacts with my obsidian agent to be reachable from another host where I run teams of agents and could enable them to interact with the obsidian agent through that. Or vise versa. I'm running tailscale and it's aperature product and I use claude code almost exclusively. I don't know much about the space of things that you can do with A2A, so don't be overly specific to my use cases listed here, they're just examples and I don't know what I don't know.
