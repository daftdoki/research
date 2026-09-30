# Track 3: Purpose-built agent sandbox platforms and tools (as of 2026-09-29)

Scope: self-hostable/local tools and hosted platforms that exist specifically to isolate AI agents or agent-generated code. Each entry lists isolation tech, egress controls, secrets, persistence, startup claims, API shape, self-host, license, and observability. Every claim has an inline source. Summaries came from WebFetch of primary pages (vendor docs, GitHub READMEs, vendor blogs). Latency figures are vendor claims and were not measured.

---

## Quick comparison matrix

| Platform | Isolation | Egress control | Secrets kept out of sandbox? | Snapshots/persistence | Self-host | License | Observability highlight |
|---|---|---|---|---|---|---|---|
| E2B | Firecracker microVM | allow/deny IP/CIDR/domain (SNI/Host) | Yes (egress-proxy injection) | pause/resume with memory, snapshots, fork | Yes (Embed single-node eval; GCP Terraform; BYOC enterprise) | Apache-2.0 | OTel metrics+lifecycle logs (Enterprise), logs API, lifecycle webhooks |
| Daytona | Container, VM, or GPU sandbox classes | block-all, CIDR (10), domain (100) | Not documented | snapshots; VM class adds pause/fork | Old AGPL code only; went closed-source in June 2026 | AGPL-3.0 (last OSS v0.190.0) → proprietary | OTel traces/logs/metrics from sandboxes (experimental), audit logs |
| microsandbox | libkrun microVM | host/port allowlist | Yes (placeholder substitution) | snap create/restore, fork | Yes (embedded, no daemon) | Apache-2.0 | `msb metrics`, `msb inspect` |
| BoxLite | KVM/HVF microVM + seccomp/sandbox-exec | allowlist | Yes | persistent state, QCOW2 | Yes (library) | Apache-2.0 | per-box metrics |
| Arrakis | cloud-hypervisor microVM | TAP/bridge, port-forward | n/a | snapshot/restore (backtracking) | Yes | AGPL-3.0 | minimal |
| OpenSandbox (Alibaba) | Docker/K8s/gVisor/Kata/Firecracker | egress controls | Yes (credential vault) | n/d | Yes | Apache-2.0 | n/d |
| container-use (Dagger) | container + git branch | not documented | not documented | git branches | Yes (local) | Apache-2.0 | command history/logs, git diff review |
| Docker Sandboxes (`sbx`) | microVM per sandbox, own Docker daemon | deny-by-default host proxy | Yes (host proxy header injection) | persistent until removed | Local (free) + Docker cloud | proprietary product | `sbx policy log` network log |
| Docker MCP Gateway | container per MCP server | `--block-network`, per-server allowHosts | `--block-secrets` scanning | n/a | Yes | MIT | `--log-calls` (default on) |
| kubernetes-sigs/agent-sandbox | RuntimeClass (gVisor/Kata) | K8s NetworkPolicy | K8s secrets | PVC, pause; warm pools | Yes (any K8s) | Apache-2.0 | controller metrics, K8s lifecycle events |
| Anthropic sandbox-runtime (`srt`) | bubblewrap+seccomp (Linux), Seatbelt (macOS), user+WFP (Windows alpha) | domain allowlist via HTTP/SOCKS proxy | n/a | none | local | Apache-2.0 | violation store, per-command attribution |
| Leash (StrongDM) | container + monitor sidecar, Cedar | Cedar policies | n/d | n/a | local | Apache-2.0 | Control UI, fs+net+MCP audit |
| Coder (+ boundary) | workspace (container/VM) + process-level firewall | domain/method/path allowlist | AI Gateway centralizes auth | workspace volumes | Yes | AGPL core; Premium gov.; boundary MIT | AI Gateway prompt/tool audit, boundary request logs |
| Modal Sandboxes | gVisor (default) or VM | block_network, CIDR, domain (beta, SNI) | Modal Secrets (env), not proxy | FS/dir snapshots; memory snapshots alpha | No | proprietary | stdout/stderr streaming, dashboard |
| Cloudflare Sandbox SDK | Container in its own VM | enableInternet, allowedHosts/deniedHosts, outbound Worker handlers (TLS intercept) | Yes (Worker injects headers) | R2/S3 mounts; backups n/d | No (SDK OSS) | SDK Apache-2.0 (repo) | log streaming; Workers observability |
| Vercel Sandbox | Firecracker microVM | allow-all/deny-all/user policy; SNI; live updates | Yes (credential brokering via `transform`) | persistent by default, snapshots, drives (beta) | No | SDK OSS; service proprietary | Dashboard Observability>Sandboxes, `forwardURL` proxy logging |
| Fly.io Sprites | Firecracker (per Fly docs.rs/marketing) | DNS-based allowlist | Connectors | live checkpoints ~300ms, CoW | No | proprietary | little documented |
| Northflank | Kata+Cloud Hypervisor, else gVisor | n/d in fetched pages | secrets injection | persistent volumes | BYOC | proprietary | logs + metrics |
| Runloop | microVM | hostname allowlist, gateways | Yes (Agent Gateway tokens) | snapshot/suspend/resume | VPC (n/d) | proprietary | 28-day execution logs, Axons event streams |
| Morph Cloud | VM ("Infinibranch") | n/d | n/d | snapshot/branch/restore <250ms | No | proprietary | n/d |
| Blaxel | Firecracker microVM | proxy, egress IP, iptables opt-in | n/d | standby w/ memory, <25ms resume | No | proprietary | log streaming |
| Together Code Sandbox / CodeSandbox SDK | Firecracker microVM | n/d | n/d | memory snapshot, hibernate/resume, clone | No | proprietary | setup-step callbacks |
| OpenAI hosted shell / code interpreter | hosted container | off by default; org + request allowlist | Yes (domain secrets via auth sidecar) | container expires after 20 min idle | No | proprietary | none beyond response items |
| Anthropic code execution tool | sandboxed container | no internet at all | n/a | reuse up to 30 days (checkpoint after ~5 min idle) | No | proprietary | response blocks |
| Claude Managed Agents | container per session; or self-hosted sandboxes | unrestricted / limited + allowed_hosts | vaults (n/d here) | per-session | Self-hosted sandbox workers | proprietary (beta) | session events; worker stats |
| Google Agent Engine Code Execution | managed sandbox | no network | n/a | state up to 14 days | No | proprietary | n/d |
| GKE Agent Sandbox | gVisor (+Kata) | default-deny NetworkPolicy | K8s | Pod Snapshots | GKE (OSS core = agent-sandbox) | Apache-2.0 core | K8s events |

n/d = not documented in the pages fetched.

---

## Part A: Self-hostable / local

### 1. E2B (open-source runtime + E2B Cloud)
- **What**: The open-source backend that runs E2B Cloud. The repo was `e2b-dev/infra`. The current README is served from `e2b-dev/runtime`. Written in Go. https://github.com/e2b-dev/infra , https://raw.githubusercontent.com/e2b-dev/infra/main/README.md
- **Isolation**: "One Firecracker microVM per sandbox, in its own cgroup and network namespace, with a per-sandbox nftables egress firewall." Memory is copy-on-write and loaded lazily through `userfaultfd`. Templates are "pre-booted VMs stored in object storage". https://github.com/e2b-dev/infra
- **Egress**: `allowOut`/`denyOut` lists accept IPs, CIDRs, and domains. Allow beats deny. Domain filtering works only on HTTP port 80 (Host header) and TLS port 443 (SNI). Domains go only in the allow list, and you must deny everything else. 8.8.8.8 is allowed automatically for DNS. A blocked TCP connection can still appear to succeed. https://docs.e2b.dev/network/internet-access.md
- **Secrets**: stored secrets are referenced in network rules. "The egress proxy injects the real value into matching outbound HTTPS requests outside the sandbox." https://docs.e2b.dev/secrets.md
- **Persistence**: pause/resume keeps the filesystem and memory, including running processes. Pausing takes about 4 s per GiB of RAM and resuming about 1 s. Paused sandboxes are kept indefinitely. Maximum continuous runtime is 24 h on Pro and 1 h on Hobby, and the counter resets on resume. https://docs.e2b.dev/sandbox/persistence.md . The docs also list snapshots, fork, and filesystem-only snapshots: https://docs.e2b.dev/llms.txt
- **Startup**: the ~150 ms boot figure is widely repeated, but I found it only in secondary sources and a docs PR (https://github.com/e2b-dev/docs/pull/49/files). The e2b.dev homepage as fetched did not state a number: https://e2b.dev/
- **API**: Python and JS/TS SDKs, CLI, MCP server. https://docs.e2b.dev/
- **Self-host**: *E2B Embed* runs the whole stack on one Linux+KVM host with Docker Compose (`docker compose up -d --wait`). It is "an evaluation package, not a production deployment pattern". The same package also ships as Terraform for GCP and as Kubernetes manifests. https://raw.githubusercontent.com/e2b-dev/infra/main/README.md . BYOC covers AWS, GCP, and Azure and is Enterprise-only. E2B manages it inside the customer account, and only anonymized CPU/memory metrics leave the account. https://docs.e2b.dev/byoc.md
- **License**: Apache-2.0. https://github.com/e2b-dev/infra
- **Observability**:
  - OTel export (OTLP HTTP/protobuf) is Enterprise-only. It sends 9 metrics (`e2b.sandbox.cpu.used`, ram, disk, team created/running) and lifecycle logs (start/stop), best effort. It exports no command traces. https://docs.e2b.dev/sandbox/otel-telemetry-export.md
  - Self-hosted infra ships OTel to ClickHouse for "sandbox lifecycle events, host stats, and metrics". https://github.com/e2b-dev/infra
  - Also available: sandbox logs API (`get-sandbox-logs-v2`), a metrics API, lifecycle events API and webhooks, and filesystem watch. https://docs.e2b.dev/llms.txt

### 2. Daytona (now closed source) + Nightona fork
- **Status**: "As of June 2026, Daytona's core development has moved to a private codebase". The repo is "no longer maintained". https://github.com/daytonaio/daytona . The announcement is dated June 11, 2026. The stated reason is that AI can now scan OSS for exploitable isolation flaws. SDKs and new work move to github.com/daytona. https://daytona.io/dotfiles/updates/daytona-is-going-closed-source
- **License**: the last OSS release was v0.190.0 under AGPL-3.0. Community fork **Nightona** continues from v0.190.0 under AGPL-3.0. It is still bootstrapping: its packages and images are not yet published. https://cdn.jsdelivr.net/gh/nightona-co/nightona@main/README.md
- **Isolation**: three sandbox classes. *Container* has "dedicated namespaces and enforced resource limits". *VM* is a "full virtual machine with its own kernel" and supports pause/resume, fork, and hot snapshots. *GPU* is a container with exclusive GPU allocation. The docs do not name the hypervisor. https://www.daytona.io/docs/en/isolation.md
- **Egress**: `networkBlockAll`. CIDR allowlist of up to 10 IPv4 entries. Domain allowlist of up to 100 entries with `*.` wildcards. On Tier 1–2 plans the org policy forces restricted network access and sandboxes cannot override it. https://www.daytona.io/docs/en/network-limits/
- **Startup**: "under 90ms from code to execution". https://github.com/daytonaio/daytona
- **API**: SDKs for Python, TS, Ruby, Go, and Java, plus REST and CLI. https://github.com/daytonaio/daytona
- **Observability**:
  - Experimental OTel collection covers traces, logs, and metrics from inside sandboxes (CPU, memory, filesystem, HTTP spans), plus SDK tracing. You configure it in Dashboard → Settings → Experimental. https://www.daytona.io/docs/en/experimental/otel-collection
  - The README lists webhooks, log streaming, and audit logs. https://github.com/daytonaio/daytona

### 3. microsandbox
- **Repo**: now at `superradcompany/microsandbox`. The old `zerocore-ai/microsandbox` redirects there. https://github.com/superradcompany/microsandbox
- **Isolation**: libkrun microVMs. VMs spawn as child processes: "no setup server. No long-running daemon." https://github.com/zerocore-ai/microsandbox
- **Startup**: "average boot times under 100 milliseconds" on M1. Same source.
- **Egress/secrets**: a host/port allowlist (`network: allow:`). "Unexploitable secret keys that never enter the VM" works by placeholder substitution at a proxy. https://github.com/superradcompany/microsandbox
- **Persistence**: `msb snap create --full` and `msb snap restore`, forking, and volumes. Same source.
- **SDKs**: TS, Rust, Python, Go. **License**: Apache-2.0. **Status**: "beta software… expect breaking changes". About 8.5k stars. YC-backed. Used by Vercel's Eve. https://github.com/zerocore-ai/microsandbox , https://github.com/superradcompany/microsandbox
- **Observability**: `msb metrics` shows live CPU, memory, and network. `msb inspect` and `msb ps` are also available. There is no OTel or audit trail documented.

### 4. BoxLite (added: notable 2025–26 OSS)
- **What**: an embeddable micro-VM runtime for OCI images: "a hardware-virtualized VM per box (KVM / Hypervisor.framework)" plus seccomp on Linux or sandbox-exec on macOS. It runs as a library or a REST service. https://github.com/boxlite-ai/boxlite
- **Features**: egress allowlist, secret injection without exposing values, persistent state, QCOW2 disks, per-box metrics (CPU, memory, network, boot time). SDKs for Python, Node, Go, Rust, C. Apache-2.0, about 2.4k stars. Open-sourced 2025-12-07 per https://jimmysong.io/ai/boxlite . Used by Databricks Omnigent, AgentScope, and deer-flow (per README).

### 5. Arrakis
- **Isolation**: a cloud-hypervisor microVM per sandbox with an overlayfs rootfs. https://github.com/abshkbh/arrakis
- **Snapshots**: snapshot-and-restore for backtracking, including MCTS-style agents. Same source.
- **Network**: TAP device on a Linux bridge, port forwarding, SSH. Same source.
- **API**: `py-arrakis` SDK and an MCP server. **License**: AGPL-3.0, with a commercial license available. About 884 stars. The contribution guide is still "coming soon". Observability is minimal and undocumented. Same source.

### 6. OpenSandbox (Alibaba) (added)
- **What**: a general-purpose sandbox platform that works locally or on a cluster. Runtimes: Docker, Kubernetes, gVisor, Kata, Firecracker. It has an ingress gateway, egress controls, and a "credential vault for secure secret injection without exposing real credentials". SDKs for Python, Java/Kotlin, TS, .NET, Go, plus the `osb` CLI and an MCP server. Apache-2.0, about 15.6k stars. https://github.com/alibaba/OpenSandbox

### 7. container-use (Dagger)
- **Isolation**: "Each agent gets a fresh container in its own git branch." It is an MCP server powered by Dagger. https://github.com/dagger/container-use
- **Observability**: "See complete command history and logs of what agents actually did". You can drop into an agent's terminal, and `git checkout <branch>` lets you review its diff. Same source.
- **Egress/secrets**: not documented in the README. **License**: Apache-2.0. **Status**: "early development", experimental badge. Same source.

### 8. Docker Sandboxes (`sbx`)
- **Isolation**: microVMs, not containers. "Each sandbox gets its own Docker daemon, filesystem, and network." https://docs.docker.com/ai/sandboxes/architecture/ , https://docs.docker.com/ai/sandboxes/get-started/
- **Egress**: "outbound TCP traffic is proxied through the host and governed by a deny-by-default policy." UDP, ICMP, and sandbox-to-sandbox traffic are blocked by default. `sbx policy ls` lists rules. Docker warns that the default allowlist contains broad wildcards such as `*.googleapis.com`. https://docs.docker.com/ai/sandboxes/security/
- **Secrets**: "API keys are injected into HTTP headers by the host-side proxy. Credential values never enter the VM." The agent sees sentinel placeholders. https://docs.docker.com/ai/sandboxes/security/ , https://docs.docker.com/ai/sandboxes/architecture/
- **Filesystem/persistence**: the workspace is shared via virtiofs passthrough. Images, packages, and agent state persist until the sandbox is removed. https://docs.docker.com/ai/sandboxes/architecture/
- **Deployment**: local (free CLI and compute) or Docker-managed cloud (pay-as-you-go). Org-wide network, filesystem, and MCP policy governance needs a paid subscription. https://docs.docker.com/ai/sandboxes/
- **Observability**: `sbx policy log [SANDBOX] --json --type network|filesystem` shows allowed and blocked hosts, the matching rule, proxy type, and count. "sbx policy log records network traffic only; filesystem mount decisions aren't available in the log yet." https://docs.docker.com/reference/cli/sbx/policy/log/ , https://docs.docker.com/ai/sandboxes/governance/monitor-and-enforce/monitoring.md . Running `sbx` with no arguments opens an interactive dashboard. https://docs.docker.com/ai/sandboxes/get-started/
- **CLI**: `sbx run --name x claude`, `sbx ls`, `sbx stop/rm`. Same source.

### 9. Docker MCP Gateway / MCP Toolkit
- **Isolation**: each MCP server runs as a Docker container "with restricted privileges, network access, and resource usage". https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/
- **Security flags** (https://raw.githubusercontent.com/docker/mcp-gateway/main/docs/security.md):
  - "Network egress is not globally denied by default". Servers can request `disableNetwork` or `allowHosts`, and the gateway can run with `--block-network`.
  - `--block-secrets` is on by default and scans tool arguments and responses for secret-like values.
  - `--verify-signatures` is on by default for Docker MCP images.
  - CPU and memory limits apply, and operators can add interceptors.
- **Observability**: `--log-calls` is on by default, but it records "the tool name and argument shape metadata only". The README advertises "Built-in logging and call tracing". I found no OTel detail. **License**: MIT. https://github.com/docker/mcp-gateway

### 10. OpenHands runtime/sandbox
- **Modes**: V1 offers Docker sandbox (the default; "runs the agent server inside a Docker container"), Process sandbox ("no container isolation"), and Remote sandbox. They are selected with `RUNTIME=docker|process|remote`. https://docs.openhands.dev/openhands/usage/runtimes/overview . An Apptainer sandbox exists for HPC. https://docs.openhands.dev/llms.txt
- **Mounts**: "Anything mounted read-write into `/workspace` can be modified by the agent." https://docs.openhands.dev/openhands/usage/sandboxes/docker.md
- **Observability**: the SDK emits OTel traces of agent steps, tool calls, LLM calls (via LiteLLM), browser sessions, and conversation lifecycle. It is configured through `OTEL_EXPORTER_OTLP_TRACES_*`, and Laminar provides browser session replay. https://docs.openhands.dev/sdk/guides/observability.md . The SDK has a typed event framework (https://docs.openhands.dev/sdk/arch/events.md) and a security analyzer with confirmation mode (https://docs.openhands.dev/sdk/guides/security.md). License: MIT core (I did not re-verify this in this pass).

### 11. SWE-agent / SWE-ReX
- **Deployments**: local, Docker, AWS remote, Modal, Fargate. Daytona support is WIP. It manages interactive shell sessions (ipython, gdb), detects completion and exit codes, and runs massively in parallel. MIT. Observability is not a focus. https://github.com/SWE-agent/SWE-ReX

### 12. kubernetes-sigs/agent-sandbox
- **CRDs**: `Sandbox` (stateful singleton with stable identity and persistent storage), `SandboxTemplate`, `SandboxClaim`, `SandboxWarmPool`. There is an optional Sandbox Router for HTTP. Isolation is delegated to RuntimeClass (gVisor, Kata). SDKs: Go and Python (`k8s-agent-sandbox`). Apache-2.0. API version v1beta1. https://github.com/kubernetes-sigs/agent-sandbox
- **Releases**: v1.0.2, v1.0.3, and v1.0.4 came out in September. The fetched summary said "2024", which is almost certainly a mis-rendering of 2026, since the project started in 2025. Recent additions: K8s lifecycle Events for sandbox transitions, scoped-token v2 (Ed25519), TLS controls, and enterprise warm-pool blueprints. https://github.com/kubernetes-sigs/agent-sandbox/releases
- **Observability**: controller metrics and Kubernetes Events. Beyond that you use the cluster's own stack.

### 13. Coder workspaces (+ Agent Firewall / boundary, AI Gateway)
- Coder Agents: "the agent loop runs in the Coder control plane on your infrastructure rather than inside the workspace". https://coder.com/docs/ai-coder
- **AI Governance** (Premium, v2.30+):
  - The *AI Gateway* provides "audit trails of prompts, token usage, and tool invocations", centralized auth, and MCP administration.
  - The *Agent Firewall* provides "process-level policies that restrict which domains agents can reach". https://coder.com/docs/ai-coder/ai-governance.md
- **OSS enforcement tool `coder/boundary`**: Linux only, MIT. It uses network namespaces and iptables with a transparent HTTP/HTTPS proxy that performs TLS interception. The nsjail backend is the default and landjail is the alternative. Rules are an allowlist of `domain=`, `method=`, and `path=`, default deny. "All requests logged to stderr". In Coder workspaces the logs forward to the workspace agent. https://github.com/coder/boundary

### 14. DevPod (loft-sh)
- Client-only, devcontainer.json-based environments on Docker, K8s, SSH, or cloud VMs through providers. MPL-2.0. The README showed no deprecation notice. https://github.com/loft-sh/devpod . It is a dev-environment tool, not an agent sandbox: it has no egress policy or audit features. See the dead-ends section for its maintenance status.

### 15. VibeKit (superagent-ai)
- A "safety layer" for coding agents. It runs them in local Docker sandboxes with "built-in redaction of secrets and API keys" and "real-time logging, tracing, and metrics", and works offline. Supports Claude Code, Gemini CLI, Codex, Grok CLI, and OpenCode. MIT, about 1.9k stars. https://github.com/superagent-ai/vibekit

### 16. Sandboxed MCP code-exec servers
- **mcp-run-python (Pydantic)**: **archived 2026-01-30**. It ran Pyodide/WASM in Deno. The maintainers warned that "Python code running in pyodide can run arbitrary javascript". MIT. https://github.com/pydantic/mcp-run-python
- **Monty (Pydantic, the successor)**: a Python-subset interpreter written in Rust. Filesystem, env, and network are disabled, and the host exposes only explicit functions. Startup is "<1 ms from a running pool". MIT, about 8.5k stars. Used in Pydantic AI Code Mode. https://github.com/pydantic/monty
- **Arrakis MCP** and **container-use** are MCP servers too (see above).

### 17. Anthropic sandbox-runtime (`srt`) used standalone
- **OS mechanisms**: Linux uses bubblewrap, a seccomp-BPF filter that blocks Unix-socket creation, and bind mounts. macOS uses dynamically generated `sandbox-exec` Seatbelt profiles. Windows (alpha) uses a dedicated `srt-sandbox` user, WFP egress rules, and NTFS ACLs. https://github.com/anthropic-experimental/sandbox-runtime
- **Network**: deny by default. HTTP(S) goes through a proxy and other TCP through SOCKS5, both with domain allowlists.
- **Filesystem**: reads are allowed except for denied paths. Writes are allow-only. Some sensitive paths (shell configs, git hooks) are always protected.
- **CLI**: `srt [--settings f] <cmd>`, with `--control-fd` for live policy updates. The library API is `SandboxManager`.
- **Observability**: `SandboxViolationStore` attributes violations per `commandId`. macOS reads the system sandbox violation log.
- **Status**: "research preview", Apache-2.0. Documented limitations: domain fronting and DNS bypass are possible, and a "weaker mode for Docker compatibility" exists.

### 18. Leash (StrongDM)
- **Architecture**: two containers. The agent container bind-mounts the current directory. A monitor container observes syscalls and enforces Cedar policies. It "captures every filesystem access and network connection" and "inspects, records, and enforces MCP tool calls". https://github.com/strongdm/leash
- **Control UI**: localhost:18080, with telemetry and an audit trail.
- **Platforms and agents**: macOS (plus an experimental native mode) and Linux/WSL, on Docker, Podman, or OrbStack. Supports Claude, Codex, Gemini, Qwen, OpenCode.
- **License/size**: Apache-2.0, about 591 stars.

---

## Part B: Hosted

### 19. E2B Cloud
See §1. Enterprise features: BYOC, OTel export. https://docs.e2b.dev/byoc.md

### 20. Modal Sandboxes
- **Isolation**: gVisor by default ("gVisor… provides strong isolation"). There is an optional VM runtime with a full Linux kernel for Docker, FUSE, or cgroups. https://modal.com/docs/guide/sandboxes
- **Lifecycle**: default timeout 5 min, maximum 24 h. Idle timeouts, readiness probes, named and tagged sandboxes. SDKs for Python, JS/TS, Go. Same source.
- **Egress**: `block_network`, `outbound_cidr_allowlist`, and `outbound_domain_allowlist` (beta, TLS 443 SNI only). The CIDR and domain lists are additive. Inbound control via `inbound_cidr_allowlist`. Connect Tokens add a verified `X-Verified-User-Data` header. https://modal.com/docs/guide/sandbox-networking
- **Secrets**: Modal Secrets are delivered as env vars, and OIDC is supported. I found no egress-proxy injection. https://modal.com/docs/guide/sandboxes
- **Snapshots**: filesystem snapshots (diff vs. image, forkable, 30-day retention), directory snapshots, and memory snapshots (alpha, by request, 7-day expiry). https://modal.com/docs/guide/sandbox-snapshots
- **Startup/scale**: tested at "up to 1000 Sandboxes per second". https://modal.com/blog/sandbox-launch . Modal markets sub-second cold starts: https://modal.com/resources/code-sandbox
- **Observability**: stdout/stderr streaming, the dashboard, and exit codes. I found no audit or OTel for sandboxes in the pages fetched.

### 21. Cloudflare Sandbox SDK / Containers
- **Isolation**: "Each container instance runs inside its own VM". Cold starts are "often… 1-3 second range". https://developers.cloudflare.com/containers/platform-details/architecture/ . Containers is GA on Workers Paid. https://developers.cloudflare.com/containers/ . Sandbox docs: "Each sandbox runs in a separate VM". https://developers.cloudflare.com/sandbox/concepts/security/
- **API**: `exec`, `readFile`/`writeFile`, a code interpreter (`createCodeContext`/`runCode`), preview URLs, `watch()`, WebSocket terminals, and R2/S3/GCS mounts. SDK 1.0 is in preview on `@cloudflare/sandbox@next`. https://developers.cloudflare.com/sandbox/
- **Egress + secrets**: `enableInternet=false`, `allowedHosts`/`deniedHosts` globs. `outbound` and `outboundByHost` handlers run as trusted Worker code outside the sandbox, with HTTPS interception on by default, and can inject credentials per `ctx.containerId`. Policy can change at runtime. https://developers.cloudflare.com/sandbox/guides/outbound-traffic/
- **Observability**: log and command-output streaming. Outbound handlers are a natural place to add request audit logging. I found no dedicated sandbox audit trail.

### 22. Vercel Sandbox
- **Isolation**: a Firecracker microVM with a dedicated kernel per sandbox. Allows `sudo`, Docker inside the sandbox, VPN, and FUSE. GA. https://vercel.com/docs/sandbox/concepts , https://vercel.com/docs/vercel-sandbox
- **Persistence**: persistent by default (the filesystem is snapshotted automatically on stop and restored on resume). Explicit snapshots, Drives (beta), and a default timeout of 5 min per session. https://vercel.com/docs/sandbox/concepts
- **Egress**: `allow-all` (the default), `deny-all` (blocks DNS too), or a user-defined policy. User-defined policies take domain allowlists (SNI, no TLS termination unless a rule applies), CIDR allow/deny, and a Postgres TLS special case, and can be **updated live** on a running sandbox. The docs openly note that **domain fronting** is possible and that `subnets.allow` leaves DNS unrestricted, which permits DNS exfiltration. https://vercel.com/docs/sandbox/concepts/firewall
- **Secrets**: "Credentials brokering… The secrets never enter the sandbox", done through `transform` header injection with a per-sandbox CA for TLS termination. `forwardURL` routes a domain to your own proxy "for logging, debugging, or transformation" and passes a signed OIDC token with team, project, and sandbox claims. Same source.
- **API**: `@vercel/sandbox` (JS), `vercel.sandbox` (Python), and the `sandbox` CLI. Authenticates with OIDC or access tokens.
- **Observability**: Dashboard → Observability → Sandboxes, streamed command logs (`cmd.logs()`), tags. `forwardURL` gives per-request egress audit. https://vercel.com/docs/sandbox/concepts

### 23. Fly.io Machines / Sprites
- **Machines**: "fast-launching VMs with a simple REST API". They boot "well under a second" once created, and creation takes "low double digit seconds". The docs page does not name Firecracker. https://docs.fly.io/machines/overview/
- **Sprites** (launched about 2026-01-09): persistent Linux VMs for agents with tiered NVMe plus object storage, idle hibernation, and wake on HTTP request.
  - "Live checkpoints… keeps running while the snapshot is captured". Restore is copy-on-write. https://fly.io/sprites
  - About 300 ms checkpoints, and the last 5 are exposed as files. https://simonwillison.net/2026/Jan/9/sprites-dev/
  - Described as "powered by Firecracker" in the Rust SDK docs: https://docs.rs/sprites
- **Sprites egress**: "a DNS-based allowlist". Wildcards, live reload, raw-IP and private ranges blocked, and denied lookups get DNS REFUSED. https://docs.fly.io/sprites/concepts/networking/
- **Sprites secrets**: "Connectors" make outbound calls to GitHub, OpenRouter, or Slack for the agent. https://fly.io/sprites
- **Sprites SDKs/pricing**: JS, Go, Python, Elixir, REST at api.sprites.dev, and CLI (`sprite create/exec/console`). Priced per usage-hour. Same source.
- **Observability**: little documented.

### 24. Northflank
- **Isolation**: microVMs for CPU and gVisor for GPU on Northflank cloud. "boot in under a second". BYOC on AWS, GCP, Azure, and more. JS and Python SDKs using exec sessions. The docs mention logs, metrics, secrets injection, and persistent storage. https://northflank.com/docs/v1/application/sandboxes
- **Runtime detail**: "Kata Containers with Cloud Hypervisor" where nested virtualization is available, and gVisor otherwise. https://northflank.com/blog/how-to-sandbox-ai-agents

### 25. Runloop
- **Isolation/startup**: Devboxes use "virtual machine technology" (https://docs.runloop.ai/devboxes/overview). Marketing describes an isolated micro-VM, sub-second to under 2 s boot, and 30k+ concurrent devboxes. https://runloop.ai/product/sandboxes
- **Egress**: `allow_all`, `allowed_hostnames` (wildcards), `allow_devbox_to_devbox`, `allow_agent_gateway`, `allow_mcp_gateway`. Changes are eventually consistent. https://docs.runloop.ai/docs/network-policies
- **Secrets**: the Agent Gateway keeps real keys on Runloop servers, and the devbox gets a devbox-bound gateway token. https://docs.runloop.ai/docs/devboxes/ai-gateways . MCP Hub: https://docs.runloop.ai/docs/devboxes/mcp-hub
- **Persistence**: snapshots, suspend/resume, blueprints. https://docs.runloop.ai/docs/devboxes/snapshots
- **Observability**: execution logs (stdout/stderr per command, streamed or retrievable, **retained 28 days** even after shutdown, `devbox.logs()`). https://docs.runloop.ai/docs/devboxes/execution-logs . **Axons** are event streams "for recording and observing agent interactions" with a SQL interface. https://docs.runloop.ai/ , https://docs.runloop.ai/docs/axons/sql . SOC2.

### 26. Morph Cloud
- "Infinibranch" is claimed to "snapshot, branch, and restore entire computational environments in under 250ms". OCI-compatible, supports docker-in-docker. SDKs: Python `morphcloud`, TS, CLI. Offers Devboxes, VM primitives, pause/resume, and SSH. https://cloud.morph.so/docs/developers , https://cloud.morph.so/docs/documentation/overview . Hypervisor, egress, and observability are not documented in the pages fetched.

### 27. Blaxel
- **Isolation**: "Every sandbox is an individual microVM built on Firecracker". https://blaxel.ai/platform/sandboxes
- **Standby**: resumes in under 25 ms with memory, processes, and filesystem intact. It goes to standby after about 15 s idle, and standby is indefinite at zero compute cost. The writable layer is tmpfs over an EROFS base. https://docs.blaxel.ai/Sandboxes/Overview
- **Network/API**: proxy egress with optional egress IP binding, and iptables opt-in at creation. TS and Python SDKs, and a built-in MCP server per sandbox. Log streaming. Same source.

### 28. Together Code Sandbox / CodeSandbox SDK
- CodeSandbox is now a Together company, and the product is migrating to the Together platform. It uses Firecracker microVMs with memory snapshotting. Spin-up is "under three seconds" and "resume/clone VMs from a snapshot in three seconds". SDK is `@codesandbox/sdk`. Priced per credit. Network controls are not documented. https://docs.together.ai/docs/together-code-sandbox . Hibernate/resume in 500 ms P95 per https://together.ai/sandbox (search snippet).

### 29. OpenAI code interpreter / hosted shell containers
- **Code interpreter**: containers are created automatically or explicitly via `/v1/containers`. Memory tiers are 1, 4, 16, or 64 GB. Containers expire after 20 min idle and cannot be revived. https://developers.openai.com/api/docs/guides/tools-code-interpreter
- **Hosted shell tool**: Debian 12 containers. "Hosted containers don't have outbound network access" by default. To enable it, an org admin sets an allowlist and the request sets `network_policy`. **Domain secrets**: "The model and runtime see placeholder names… The auth-translation sidecar applies raw secret values only for approved destinations." Skills mount into the container. https://developers.openai.com/api/docs/guides/tools-shell.md
- **Observability**: only the response output items. OpenAI advises you to "log tool activity for auditing" yourself. Same source.

### 30. Anthropic code execution tool / Claude Managed Agents
- **Code execution tool**: GA, and not ZDR-eligible. A sandboxed container with 5 GiB RAM, 5 GiB disk, and 1 CPU. "Internet access: Completely disabled". Containers can be reused and expire 30 days after creation. They are checkpointed after about 5 min idle. https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool
- **Managed Agents** (beta header `managed-agents-2026-04-01`):
  - Each session gets "a fresh Linux container".
  - Networking is `unrestricted` (the default, with a safety blocklist) or `limited`, which uses `allowed_hosts` plus the `allow_package_managers` and `allow_mcp_servers` flags.
  - The docs warn that access is "granted per host, not per operation", so exfiltration is possible to any allowed host.
  - Packages can be preinstalled. Environments are not versioned.
  - https://platform.claude.com/docs/en/managed-agents/environments
- **Self-hosted sandboxes**: orchestration stays with Anthropic, and tool execution runs on your infrastructure. An environment worker polls a work queue. Provider guides exist for AWS Lambda MicroVMs, Blaxel, Cloudflare, Daytona, E2B, Fly.io, GKE Agent Sandbox, Modal, Namespace, Superserve, and Vercel. Worker health: `ant beta:environments:work stats`. https://platform.claude.com/docs/en/managed-agents/self-hosted-sandboxes

### 31. Google
- **Agent Engine Code Execution** (Vertex AI / Agent Platform): a managed sandbox with sub-second create and execute, a limited filesystem, and **no network access**. State lasts up to 14 days (configurable TTL). https://docs.cloud.google.com/agent-builder/agent-engine/code-execution/overview (details via search snippet; the fetched page was a hub).
- **GKE Agent Sandbox**: previewed at KubeCon NA in November 2025 (https://siliconangle.com/2025/11/11/google-debuts-new-open-source-ai-tools-gke-pod-snapshots/). **GA on May 20, 2026**. It runs gVisor natively, with Kata pluggable, and "default-deny Kubernetes network policy". Pod Snapshots handle suspend and resume. Warm pools allocate 300 sandboxes/s per cluster, with "90% of allocations complete in 200 milliseconds". The same announcement introduced the **Agent Substrate** OSS project. https://cloud.google.com/blog/products/containers-kubernetes/bringing-you-agent-sandbox-on-gke-and-agent-substrate

---

## Cross-cutting observations (for synthesis)
1. **Credential brokering is now standard across platforms.** In E2B, Vercel, Cloudflare, Docker Sandboxes, microsandbox, BoxLite, OpenSandbox, OpenAI hosted shell, and Runloop, secrets stay outside the sandbox and are injected at an egress proxy or sidecar. The main platforms that still pass env-var secrets are Modal and plain containers.
2. **Domain egress filtering is mostly SNI-based.** Vercel openly documents the domain-fronting and DNS-exfiltration caveats. E2B notes that blocked TCP connections can look successful. Anthropic srt also lists domain fronting as a limitation. Sprites instead filters at DNS.
3. **Observability is uneven.** Only a few platforms offer:
   - OTel export: Daytona (experimental), E2B (Enterprise, metrics and lifecycle only), OpenHands (agent-level traces).
   - Durable per-command logs: Runloop (28 days).
   - Network allow/deny logs: Docker `sbx policy log`, coder/boundary.
   - Fs+net+MCP audit: Leash.

   **No platform found offers full session replay or filesystem diff natively.** Approximations: container-use (git branch diff), OpenHands with Laminar (browser replay), E2B (filesystem watch), Cloudflare (`watch()`).
4. **Isolation tiers**:
   - Firecracker: E2B, Vercel, Blaxel, CodeSandbox, Sprites.
   - libkrun: microsandbox, and possibly BoxLite.
   - cloud-hypervisor: Arrakis, Northflank/Kata.
   - gVisor: Modal, GKE, Northflank GPU.
   - Plain containers: container-use, OpenHands default, VibeKit, Leash, Daytona container class.
   - OS-level: srt, coder/boundary.
5. **Licensing risk**: Daytona moved from AGPL to closed source in June 2026, so self-hosters are left with the Nightona fork or migration. mcp-run-python was archived in January 2026.

## Dead ends / uncertain
- **DevPod maintenance status**: the README showed no deprecation notice (https://github.com/loft-sh/devpod). I could not confirm community reports that Loft reduced investment, because the search returned junk. Treat it as uncertain.
- **Daytona hypervisor** for the VM class is not named in its docs. Container-class runtime details (Sysbox or other) are unverified.
- **Fly Sprites isolation**: Fly's own marketing page did not name Firecracker. The attribution comes from the Rust SDK docs (docs.rs/sprites) and third parties. Fly Machines docs also do not name Firecracker on the overview page, though it is widely known.
- **E2B "~150 ms" boot**: not stated on the current homepage fetch. It comes from secondary sources and an old docs PR.
- **kubernetes-sigs/agent-sandbox release dates**: the fetch reported "September 2024" for v1.0.2–v1.0.4. That is inconsistent with the project's 2025 start and presumably means September 2026. Verify before citing.
- **Morph Cloud** hypervisor, egress, and observability: not found. The Infinibranch blog page returned only its title.
- **CodeSandbox SDK docs** (codesandbox.io/docs/sdk) returned 403. I used Together docs instead.
- **Cloudflare Sandbox SDK license**: I assumed Apache-2.0 from the GitHub repo (github.com/cloudflare/sandbox-sdk) but did not verify it.
- **Google Agent Engine Code Execution**: the details (14-day TTL, no network) come from a search snippet of the official page. The direct fetch landed on a hub page.
- **OpenHands license and runtime internals**: I did not re-verify them in this pass. The V1 docs call them "sandbox" while the config knob is still `RUNTIME`.
- **Docker Sandboxes hypervisor per host OS** and supported host OS list: the agents page returned 404, and the architecture page does not state them.
- **Docker MCP Gateway OTel**: not documented in the security doc.
- **Arrakis**: last-activity date unknown, and the project appears low-velocity.
- Items I found no evidence for, and so skipped as separate products: a distinct "Anthropic managed agent sandbox" beyond Managed Agents and the code execution tool (covered above), and a standalone Google "agent sandbox" product beyond Agent Engine Code Execution and GKE Agent Sandbox.
