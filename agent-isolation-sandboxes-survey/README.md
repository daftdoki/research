# Agent Isolation and Sandboxing: A Survey from Homelab to Medium Deployments

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

What techniques and products exist for isolating AI agents (coding agents and tool-using LLM agents) and the code they run? The survey covers the range from a single person running a handful of agents on a homelab box up to small and medium multi-user deployments. For each, how do they compare on **capabilities**, **security guarantees**, and **observability**? See the [Original Prompt](#original-prompt).

Research date: 2026-09-29.

## Answer / Summary

Isolation for agents is best read as a **ladder of boundaries** plus **three cross-cutting controls** that matter as much as the boundary itself.

**The ladder** (weakest to strongest boundary, roughly cheapest to most expensive):

| Tier | Examples | What actually stops the agent |
|---|---|---|
| 0. Policy only | Permission prompts, allow/deny rules, hooks, auto-review classifiers | The agent harness's own parser. Vendors say it is **not a security boundary** |
| 1. OS process sandbox | Claude Code / `srt` (bubblewrap, Seatbelt), Codex CLI (bwrap+seccomp, Seatbelt), Cursor (Landlock+seccomp), landrun, nsjail, systemd-run | Kernel access controls on a **shared kernel** |
| 2. Container | Rootless Docker/Podman, devcontainer + firewall, Sysbox, Incus system containers | Namespaces + seccomp + LSM on a **shared kernel** |
| 3. User-space kernel | gVisor (`runsc`) | A Go re-implementation of Linux sits between the agent and the host kernel. **No KVM needed** |
| 4. Hardware VM | Firecracker, Kata, Cloud Hypervisor, libkrun (microsandbox, smolvm), Apple `container`, Docker Sandboxes, Lima, Proxmox/libvirt VMs | A separate guest kernel behind KVM/HVF |
| (side branch) Language sandbox | Wasmtime/WASI, V8 isolates (Workers), Pydantic Monty | Nothing is reachable unless the host passes it in. **Cannot run a real toolchain** |

**The three cross-cutting controls:**

1. **Network egress.** Prompt injection turns any agent with private data, untrusted input and an outbound channel into an exfiltration tool: Willison's "lethal trifecta". A filesystem sandbox does not close that. Egress control must be default-deny, and it should sit **outside** the agent process.
2. **Credentials.** The agent should hold placeholders only. A proxy outside the sandbox swaps in real secrets per destination. This is now standard on most hosted platforms and in Claude Code, Docker Sandboxes, microsandbox and others.
3. **Observability.** The stronger the boundary, the less the host's kernel telemetry sees. The useful audit points then move to the **egress proxy**, the **agent/tool layer** (OTel, hooks, transcripts) and the **filesystem sync boundary**.

**Main conclusions:**

- **Most real escapes in 2025–2026 were policy-layer bugs, not kernel or VM breaks.** Allowlist parsing, workspace config that the host later executes (hooks, `.git/config`, `.vscode` tasks), writable-root confusion, SOCKS hostname parsing, and an exposed Docker socket account for them. A stronger boundary helps only if the *host-side* harness also stays out of reach.
- **Every built-in coding-agent sandbox shares the host kernel.** Anthropic's own docs point to a VM for untrusted repos.
- **A new class of "sandbox + policy" agent runtimes appeared in 2026. NVIDIA OpenShell is the most complete.**
  - It does not add a new boundary. Landlock and seccomp run inside a container, a Kubernetes pod, or an opt-in libkrun microVM.
  - It does integrate the pieces: per-binary egress and HTTP rules, credential placeholders, a policy prover, and OCSF audit events for a SIEM.
  - It is very young: 0.1.0 is four days old and breaking, and early versions had a 9.9 sandbox-escape CVE.
  - Governance toolkits such as Microsoft's Agent Governance Toolkit and Cisco DefenseClaw are policy and logging layers that sit on top of a sandbox, not replacements for one.
- **Homelab, one user:**
  - Run the agent's built-in sandbox with network allowlisting.
  - Put the whole agent in a disposable VM or microVM (Lima/Apple `container`/OrbStack-isolated on a Mac; Docker Sandboxes, Incus VM or a Proxmox VM on Linux).
  - Give it scoped, short-lived tokens, and put it on a tailnet tag with no access to the rest of the lab.
- **Small team:** a per-agent microVM or gVisor sandbox (self-hosted E2B, microsandbox, OpenSandbox, Coder with `boundary`) or a hosted service. Add a TLS-intercepting egress proxy that injects credentials and logs requests, and agent OTel into Langfuse/Phoenix.
- **Medium:** Kubernetes with `kubernetes-sigs/agent-sandbox` (or GKE Agent Sandbox) on gVisor or Kata RuntimeClasses. Add Cilium FQDN policy or an egress-proxy tier, GitHub App/Vault short-lived credentials, gVisor runtime monitoring into Falco, and a single OTLP pipeline keyed on session ID.
- **Observability is the weakest part of the ecosystem.** No platform surveyed offers native session replay or filesystem diffs. OTel export is rare and often enterprise-only or experimental. You will assemble it yourself.

For additional and more detailed information see the [research notes](notes.md) and the five source-annotated findings files in [`findings/`](findings/).

## Methodology

- The survey was split into four tracks, each researched against primary sources: official docs, READMEs, source files, GitHub security advisories, kernel docs and papers. Every claim in the findings files carries an inline URL.
  1. [OS primitives and coding-agent built-in sandboxes](findings/01-os-primitives-and-agent-sandboxes.md)
  2. [Stronger isolation runtimes](findings/02-isolation-runtimes.md): gVisor, Kata, Firecracker, Cloud Hypervisor, libkrun, macOS options, Sysbox, Incus, full VMs, Wasm/isolates
  3. [Purpose-built agent sandbox platforms](findings/03-agent-sandbox-platforms.md): 31 self-hosted and hosted offerings
  4. [Egress, credentials, runtime and agent observability, escape history](findings/04-egress-credentials-observability.md)
  5. [Agent runtimes that bundle a sandbox with a policy layer](findings/05-agent-runtimes-openshell-and-peers.md): NVIDIA OpenShell/NemoClaw, OpenClaw, NanoClaw, IronClaw, OneCLI, Microsoft AGT, Cisco DefenseClaw, Pipelock, agentsh, agentgateway, AWS AgentCore, Azure dynamic sessions. Added as a follow-up question.
- Nothing was installed or benchmarked. Startup and overhead figures are vendor or paper claims and are labelled as such.
- Items with only secondary sources are marked *(secondary)* or *(unverified)* in the tables below.

## Results

### 1. Threat model: what you are isolating against

The same word "sandbox" covers three different protections:

| Goal | Threat | Main control |
|---|---|---|
| Protect the **host** from the agent | `rm -rf ~`, a malicious dependency, a kernel exploit | FS/process/VM boundary (the ladder) |
| Protect **data the agent legitimately holds** | Prompt injection makes the agent send repo contents, env secrets or tokens out | Egress control and credential brokering |
| Protect **other systems** the agent can reach | Lateral movement into the NAS, Home Assistant, cloud metadata, a k8s API | Network segmentation, blocking private/metadata IPs, scoped tokens |

- **The lethal trifecta.** An agent with private data, exposure to untrusted content, and the ability to communicate externally can be made to exfiltrate ([Willison](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)). Meta's "Agents Rule of Two" says an autonomous session should hold at most two of those three ([Meta AI](https://ai.meta.com/blog/practical-ai-agent-security/)).
- **Egress is usually the leg you can cut.** A coding agent has to read the repo and read untrusted content (issues, docs, dependencies), so the outbound channel is typically the only leg that can be removed.
- **Allowlists leak through dual-use domains.** Real exfiltrations went through *allowed* domains: `api.anthropic.com/v1/files` with an attacker's API key ([Willison on Cowork](https://simonwillison.net/2026/Jan/14/claude-cowork-exfiltrates-files/)), GitHub via the GitHub MCP server ([Willison](https://simonwillison.net/2025/May/26/github-mcp-exploited/)), and broad default allowlists ([Codex internet access](https://simonwillison.net/2025/Jun/3/codex-agent-internet-access/)).

### 2. The isolation ladder in detail

#### 2.1 Master comparison

| Technique | Kernel shared with host? | Needs KVM/HW virt | Startup / overhead (claimed) | Egress control | Resource limits | Host-side observability of the workload | Setup effort |
|---|---|---|---|---|---|---|---|
| Permission rules / hooks | n/a | no | none | none (intent only) | no | Rich *semantic* logs (tool decisions, OTel); nothing kernel-enforced | trivial |
| bubblewrap / `srt` / Codex (Linux) | yes | no | ~ms | via host proxy + netns | no | **None built in** (EPERM; use strace) | low |
| Seatbelt (`sandbox-exec`, macOS) | yes | no | ~ms | localhost proxy port only | no | **Unified log** violations (`log stream`) | low |
| Landlock (landrun, Cursor) | yes | no | ~µs | TCP *port* rules (ABI 4, 6.7+) | no | **Native audit records since 6.15** (ABI 7) | low |
| systemd-run / unit sandboxing | yes | no | ~ms | netns or IP ACLs | **yes** | journald, `SystemCallLog=` | low–medium |
| nsjail | yes | no | ~ms | netns / macvlan | **yes** | log file | medium |
| Rootless Docker / Podman | yes | no | ~100 ms | `--network none` or custom | yes (cgroup v2) | Full host eBPF (Falco/Tetragon) | medium |
| Devcontainer + iptables firewall | yes | no | container | IP allowlist from DNS at start | yes | Silent unless LOG rules added | medium |
| Sysbox / Docker ECI | yes (userns always on) | no | container | as container | yes | Full host eBPF | medium |
| Incus/LXD system container | yes | no | container | bridge/ACLs | yes | Full host eBPF | medium |
| gVisor (`runsc`) | **no** (Sentry user-space kernel) | **no** (systrap default) | +~100–200 ms, ~3–20 MB (older figures) | netstack + your policy | yes | Host eBPF sees Sentry only; **gVisor Runtime Monitoring → Falco** | medium |
| Kata Containers | no (guest kernel) | yes | ~150–300 ms *(secondary)* | CNI/NetworkPolicy | yes | kata-monitor Prometheus, OTel over vsock; host eBPF blind to guest | high |
| Firecracker | no | yes | ≤125 ms to init, ≤5 MiB VMM overhead (spec) | TAP + your firewall | yes (rate limiters, cgroups) | VMM JSON metrics/logs only; guest needs its own agent | high |
| libkrun (microsandbox, smolvm, `krun`) | no, **but VMM and guest share one security context** | yes (KVM/HVF) | <100–200 ms (vendor) | TSI or passt; tool-level allowlists | yes | Tool metrics only | low–medium |
| Apple `container` (macOS 26) | no (VM per container) | Apple silicon | "sub-second" | vmnet | yes | macOS unified logging | low |
| Full VM (Proxmox, libvirt, Lima, UTM) | no | yes | seconds, 100+ MB | host firewall / bridge | yes | libvirt domstats; guest agent for inside data | low–medium |
| Wasm/WASI, V8 isolates, Monty | n/a (in-process) | no | µs–ms | only granted capabilities | yes | Whatever host functions log | low (but restricted coverage) |

Sources: [findings 01](findings/01-os-primitives-and-agent-sandboxes.md) §6 and [findings 02](findings/02-isolation-runtimes.md) §0, which link gVisor [perf](https://gvisor.dev/docs/architecture_guide/performance/) and [platforms](https://gvisor.dev/docs/architecture_guide/platforms/), Firecracker [SPECIFICATION.md](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md), the [libkrun README](https://github.com/containers/libkrun), [Landlock kernel docs](https://docs.kernel.org/admin-guide/LSM/landlock.html), and others.

#### 2.2 Tier 0: permission and approval systems

- **Not a boundary, by the vendors' own account.**
  - Claude Code: Bash rules are "not a security boundary around the program". They match command text only and miss `sh -c`, absolute paths and scripts.
  - Claude Code: the auto-mode classifier "is a per-action control, not an isolation boundary" ([permissions](https://code.claude.com/docs/en/permissions.md), [sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).
- **Real bypasses were argument-parsing bugs.** Examples: `sed`, `rg` and `echo` parsing bypasses in Claude Code (CVE-2025-64755, -58764, -54795); Codex "GitPwned", where `git show --output`/`--ext-diff` gave RCE ([Pillar](https://www.pillar.security/blog/gitpwned-allowlist-to-rce)); and the Gemini CLI `grep ...; env | curl` allowlist abuse *(secondary)*.
- **Value: this layer produces the best *intent* logs.** Examples are `codex.tool_decision` and `claude_code.tool_decision` OTel events, and the PreToolUse hook payloads carrying `tool_use_id`.

#### 2.3 Tier 1: OS process sandboxes (what the agents ship)

| Agent | macOS | Linux | Network default | Domain filtering | Violations visible via |
|---|---|---|---|---|---|
| **Claude Code** (`srt`) | Seatbelt | bubblewrap + socat + optional seccomp (blocks AF_UNIX) | No domains pre-allowed; prompts on first use | Host HTTP+SOCKS5 proxy; optional `tlsTerminate` + credential `mask` | Command result names denied path/host; `SandboxViolationStore`; macOS log; Linux: strace only |
| **Codex CLI** | Seatbelt | **bwrap + seccomp** (Landlock mode now rejected) | Off in `workspace-write` | Opt-in `network_proxy`; does not cover MCP/web search | `--log-denials` (macOS), OTel `codex.tool_decision` |
| **Cursor** | Seatbelt | **Landlock + seccomp** (kernel ≥6.2), bwrap fallback | Blocked; `sandbox.json` allowlist | Documented as allowlist; mechanism on Linux not documented | Constraint named in tool output |
| **Gemini CLI** | Seatbelt profiles (default `permissive-open` = read anything, open network) | Docker/Podman, **gVisor**, LXC | Depends on profile | `*-proxied` profiles | `DEBUG=1` only |

Sources: [Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing), [srt README](https://github.com/anthropic-experimental/sandbox-runtime), [Codex linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md), [Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md), [Gemini CLI sandbox.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/sandbox.md).

**Security guarantees and gaps:**

- **Shared kernel.** A kernel LPE is a sandbox escape. GhostLock (CVE-2026-43499, July 2026) gave a reliable LPE with a container-escape variant *(secondary)*. Unprivileged user namespaces, which bubblewrap needs, are themselves attack surface: Ubuntu cites Google data that 44% of the exploits Google saw needed them ([Ubuntu](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces)).
- **Only the shell is sandboxed.** In Claude Code, MCP servers and hooks "run unconstrained on the host" unless you wrap the whole `claude` process ([sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).
- **Hostname-only filtering.** No tool terminates TLS by default, so domain fronting works and broad domains are exfil paths. Anthropic, Vercel and Docker all document this.
- **Config-as-code escapes.** Examples:
  - CVE-2026-25725: sandboxed code created a missing `.claude/settings.json` containing a `SessionStart` hook that ran unsandboxed on the next launch.
  - CVE-2026-55607: git worktree plus fsmonitor escape from Seatbelt.
  - Cursor CVE-2026-48124 (hook config).
  - Pillar's July 2026 cross-vendor "week of sandbox escapes": Docker socket reachable, venv interpreter executed by the host IDE extension ([Pillar](https://www.pillar.security/blog/the-week-of-sandbox-escapes)).
- **Proxy bugs.** `srt` CVE-2025-66479 left the network unenforced when the allowlist was empty. There was also a SOCKS5 null-byte hostname bypass with no CVE; its fixed version differs between sources ([The Register](https://www.theregister.com/a/5243662)).

**Low-level building blocks, for DIY or homelab use:**

- **Landlock** is unprivileged and stackable. It gained TCP port rules in ABI 4 (6.7) and native audit records in ABI 7 (6.15). Newer ABIs add UDP and pathname Unix sockets (kernel versions unverified). It has no IP or domain rules ([landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html), [kernel docs](https://docs.kernel.org/userspace-api/landlock.html)).
- **seccomp** is "not a sandbox", per the kernel doc. It shrinks the syscall surface but cannot see pointer arguments such as paths. ERRNO denials are silent unless the filter sets the LOG flag ([seccomp_filter](https://docs.kernel.org/userspace-api/seccomp_filter.html)).
- **systemd-run** is the most under-used homelab option. `ProtectSystem=strict`, `PrivateNetwork=`, `IPAddressAllow=`, `SystemCallFilter=`, `MemoryMax=` and `SystemCallLog=` give FS, network, syscall and cgroup limits with journald logs in one command ([systemd.exec](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml)).
- **firejail** is a SUID binary with a root-LPE history (CVE-2022-31214), which is why bubblewrap-based designs avoid it.

#### 2.4 Tier 2: containers

- **Rootless Docker/Podman.** When a runc escape happens (CVE-2024-21626 "Leaky Vessels", or the 2025 trio CVE-2025-31133/52565/52881), the attacker lands as an unprivileged user. The runc advisories themselves name userns with host root unmapped as the mitigation ([GHSA-9493-h29p-rfm2](https://github.com/opencontainers/runc/security/advisories/GHSA-9493-h29p-rfm2)).
- **Devcontainer + firewall** (Anthropic's reference). The script sets default-DROP with an ipset built from GitHub `/meta` and a DNS lookup at start. Reading the [script](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) shows gaps:
  - UDP/53 is allowed to *any* host, which leaves a DNS-tunnel channel.
  - TCP/22 is allowed to any host.
  - The host /24 is allowed.
  - It is IPv4 only.
  - IPs are resolved once at start.

  Anthropic's own doc says that with `--dangerously-skip-permissions` a devcontainer does not stop a malicious project from exfiltrating anything inside it, including Claude credentials ([devcontainer doc](https://code.claude.com/docs/en/devcontainer)).
- **Sysbox / Docker ECI.** This is the right way to give an agent `docker build` without handing it `/var/run/docker.sock`, which "effectively grants access to the host system" ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing); [Sysbox](https://github.com/nestybox/sysbox)).
- **GPU containers.** The NVIDIA Container Toolkit had two host-root escapes reachable from a crafted image: CVE-2024-0132 and "NVIDIAScape" CVE-2025-23266, the latter a three-line Dockerfile using `LD_PRELOAD` ([Wiz](https://www.wiz.io/blog/nvidia-ai-vulnerability-cve-2025-23266-nvidiascape)). This matters for homelabs that co-host local LLMs.
- **Observability is the strength here.** The kernel is shared, so Falco, Tetragon, Tracee and auditd see every syscall. Tetragon can also enforce in-kernel ([Tetragon enforcement](https://tetragon.io/docs/concepts/enforcement/)).

#### 2.5 Tier 3: gVisor

- **Architecture.** The Sentry, a memory-safe Go application kernel, handles the workload's syscalls. A Gofer mediates file access, and the Sentry is itself seccomp-confined ([gVisor security model](https://gvisor.dev/docs/architecture_guide/security/)).
- **Runs without KVM.** The systrap platform needs no virtualization. That makes gVisor the only strong boundary that runs inside an ordinary cloud VM or Proxmox guest without nested virt ([platforms](https://gvisor.dev/docs/architecture_guide/platforms/)).
- **Track record.** gVisor claims its architecture blocked 96% of the high-impact Linux kernel CVEs it tracks ([track record](https://gvisor.dev/security-track-record/)). Its own escape history is short: the 2018 Project Zero Gofer race, plus one very recent CUSE-device CVE that is unverified (see findings 02).
- **Costs.** Syscall- and I/O-heavy workloads are slow. Compatibility is partial: io_uring off, no nested KVM. GPU via nvproxy inherits NVIDIA driver bugs ([GPU guide](https://gvisor.dev/docs/user_guide/gpu/)).
- **Observability.**
  - Host eBPF sees only the Sentry.
  - gVisor's **Runtime Monitoring** streams syscalls and events over a UDS, and Falco consumes it natively, so "all the Falco rules and tooling work" ([gVisor blog](https://gvisor.dev/blog/2022/08/01/threat-detection/), [Falco](https://falco.org/docs/event-sources/gvisor)).
  - `runsc --strace` and a Prometheus metric server exist. The metric server covers gVisor internals, not the workload ([observability](https://gvisor.dev/docs/user_guide/observability/)).
- **Where it is used.** Modal, GKE Agent Sandbox, Northflank (GPU), and Gemini CLI's strongest mode.

#### 2.6 Tier 4: hardware virtualization

- **Firecracker.** A minimal Rust VMM, about 50k LoC versus more than 1M for QEMU ([NSDI'20](https://www.usenix.org/conference/nsdi20/presentation/agache)). It adds per-thread seccomp and a jailer. Its advisory list is short: a 2019 vsock heap bug, CVE-2026-5747 in the *opt-in* PCI transport, and a 2026 jailer symlink bug ([AWS bulletin](https://aws.amazon.com/security/security-bulletins/2026-015-aws)). Snapshot-cloned pools duplicate RNG state and secrets; VMGenID reseeds the kernel only ([snapshot docs](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshot-support.md)). Used by E2B, Vercel, Blaxel, CodeSandbox/Together, and Fly Sprites (per SDK docs).
- **Kata Containers.** A VM per pod via a RuntimeClass, backed by QEMU, Cloud Hypervisor, Firecracker or Dragonball. Its 2026 advisories are almost all in host-side glue: a default-enabled `virtio_fs_extra_args` annotation allowing a VM escape (CVE-2026-44210), guest-to-host via virtio-fs (CVE-2026-47243), and annotation-driven host bind mounts ([Kata advisories](https://github.com/kata-containers/kata-containers/security/advisories)). **Restrict pod annotations.** Observability: kata-monitor exposes Prometheus metrics, and runtime and agent spans reach OTel through a vsock trace forwarder ([tracing.md](https://github.com/kata-containers/kata-containers/blob/main/docs/tracing.md)).
- **libkrun family** (microsandbox, smolvm, `podman --runtime=krun`). Fast and easy on both macOS and Linux. The [README](https://github.com/containers/libkrun) warns that "both the guest and the VMM pertain to the same security context". The libkrun process must be sandboxed by the host, and TSI networking gives the guest the VMM's network context.
- **macOS options.**
  - **Apple `container`** gives "each container the isolation properties of a full VM" ([technical overview](https://github.com/apple/container/blob/main/docs/technical-overview.md)).
  - **OrbStack's isolated machines "aren't a full security boundary"** because they share one kernel ([OrbStack](https://docs.orbstack.dev/machines/isolated)).
  - **Lima** has agent-specific `--mount-only .:w` and `--sync` modes that let you review changes before they reach the host ([Lima AI docs](https://lima-vm.io/docs/examples/ai/)).
- **Full VMs** (Proxmox, libvirt). The largest TCB (QEMU; VENOM is the classic escape), but the easiest to reason about in a homelab. Proxmox itself recommends VMs over containers for untrusted users ([Proxmox wiki](https://pve.proxmox.com/wiki/Linux_Container)).
- **Observability.** Hardware VMs are opaque to host eBPF. You get VMM metrics, the serial console, or whatever an in-guest agent exports. Guest agents are themselves a guest-to-host channel: an Incus advisory let a malicious `incus-agent` write host files ([Incus advisories](https://github.com/lxc/incus/security/advisories)).

#### 2.7 Side branch: language-level sandboxes

- **Strong on capabilities, weak on coverage.** Wasmtime/WASI and V8 isolates expose nothing the host does not grant, and start in µs–ms. They cannot run `npm install`, compilers, arbitrary binaries or Docker. Their TCB is a JIT, and JITs have a history of escapes (Wasmtime CVE-2023-26489; V8 bugs), which is why Cloudflare layers process sandboxes on top ([Workers security model](https://developers.cloudflare.com/workers/reference/security-model/)).
- **Self-hosted `workerd` is "not a hardened sandbox"** on its own ([workerd](https://github.com/cloudflare/workerd)).
- **mcp-run-python was archived on 2026-01-30.** Pydantic said there is "no safe way to run Python within pyodide", because Python there can run arbitrary JS. Its successor is **Monty**, a Rust Python-subset interpreter with no FS, env or network ([mcp-run-python](https://github.com/pydantic/mcp-run-python), [Monty](https://github.com/pydantic/monty)).
- **Fit.** Suits "code mode" tool glue, not full coding agents.

### 3. Purpose-built agent sandbox platforms

#### 3.1 Self-hostable / local

| Tool | Isolation | Egress control | Secrets outside sandbox | Snapshots | License / status | Observability |
|---|---|---|---|---|---|---|
| E2B (open infra) | Firecracker | allow/deny IP, CIDR, domain (SNI/Host) | yes, egress-proxy injection | pause/resume w/ memory, fork | Apache-2.0; self-host = single-node "Embed" eval, GCP Terraform | Lifecycle/metrics to ClickHouse; OTel export Enterprise-only |
| microsandbox | libkrun microVM | host/port allowlist | yes (placeholders) | snap create/restore, fork | Apache-2.0, beta | `msb metrics`, `inspect` |
| BoxLite | KVM/HVF microVM + seccomp | allowlist | yes | QCOW2 persistent | Apache-2.0 | per-box metrics |
| smolvm | libkrun | network off by default, allowlists | credential substitution | packed images | Apache-2.0 | n/d |
| Alibaba OpenSandbox | Docker/K8s/gVisor/Kata/Firecracker | egress controls | credential vault | n/d | Apache-2.0 | n/d |
| Arrakis | Cloud Hypervisor | TAP/bridge | n/a | snapshot/restore (backtracking) | AGPL-3.0, low velocity | minimal |
| Docker Sandboxes (`sbx`) | microVM + own Docker daemon | **deny-by-default** host proxy (TCP only) | yes, header injection | persistent until removed | proprietary; free locally | **`sbx policy log`** (network allow/deny log) |
| Docker MCP Gateway | container per MCP server (1 CPU/2 GB) | `--block-network`, per-server allowHosts | `--block-secrets` scanning | n/a | MIT | `--log-calls` (tool name + arg shape) |
| container-use (Dagger) | container + git branch per agent | not documented | not documented | git branches | Apache-2.0, early | Command history, **git diff review** |
| Leash (StrongDM) | container + monitor sidecar, Cedar policies | Cedar | n/d | n/a | Apache-2.0 | **FS + network + MCP audit trail**, local UI |
| Coder + `coder/boundary` | workspace (container/VM) + per-process netns jail with TLS interception | domain/method/path allowlist | AI Gateway centralizes auth | workspace volumes | AGPL core, boundary MIT | Every request logged; AI Gateway prompt/tool audit (Premium) |
| coder/httpjail | per-process netns + nftables + TLS proxy | JS/shell rules, default deny | n/a | n/a | experimental | Request logs; **no FS isolation** |
| OpenHands | Docker (default), process, remote | not built in | n/a | n/a | MIT core | **OTel traces** of agent steps/tool calls |
| kubernetes-sigs/agent-sandbox | RuntimeClass (gVisor/Kata) | NetworkPolicy | K8s secrets | PVC, pause, **warm pools** | Apache-2.0, v1beta1 | K8s Events + controller metrics |
| Anthropic `srt` standalone | bwrap/Seatbelt (+Windows alpha) | domain allowlist proxy | via Claude Code `mask` | none | Apache-2.0, research preview | violation store |
| VibeKit | local Docker | n/d | secret redaction | n/a | MIT | logging/tracing claimed |
| **Daytona** | container / VM / GPU classes | block-all, CIDR, domain | n/d | snapshots, VM fork | **Went closed source 2026-06-11**; last AGPL v0.190.0; community fork *Nightona* | Experimental OTel, audit logs |

Details and sources: [findings 03](findings/03-agent-sandbox-platforms.md) Part A.

#### 3.2 Hosted

| Service | Isolation | Egress | Secrets outside sandbox | Notable |
|---|---|---|---|---|
| E2B Cloud | Firecracker | allow/deny lists; blocked TCP can *look* successful | yes | BYOC (Enterprise) |
| Modal Sandboxes | **gVisor** (VM runtime optional) | block, CIDR, domain (SNI, beta) | **no**: env-var secrets | 1000 sandboxes/s launch claim; memory snapshots alpha |
| Vercel Sandbox | Firecracker | deny-all / user policy, live-updatable; **documents domain fronting and DNS exfil** as gaps | yes (`transform` brokering) | `forwardURL` to your own logging proxy with OIDC claims |
| Cloudflare Sandbox SDK | container in its own VM | allowed/denied hosts; **outbound Worker handlers with TLS interception** | yes | programmable egress = programmable audit |
| Fly.io Sprites | Firecracker (per SDK docs) | **DNS-based** allowlist | Connectors | ~300 ms live checkpoints |
| Northflank | Kata+Cloud Hypervisor, else gVisor | n/d | secret injection | BYOC |
| Runloop | microVM | hostname allowlist + gateways | yes (Agent Gateway) | **28-day per-command logs**, Axons event streams |
| Blaxel | Firecracker | proxy / egress IP | n/d | <25 ms resume from standby |
| Together / CodeSandbox | Firecracker | n/d | n/d | memory snapshots, clone |
| Morph Cloud | VM ("Infinibranch") | n/d | n/d | <250 ms snapshot/branch claims |
| GKE Agent Sandbox | gVisor (+Kata) | default-deny NetworkPolicy | K8s | GA 2026-05-20; 90% of allocations in 200 ms from warm pools |
| OpenAI hosted shell | container | off by default; org + request allowlist | yes (auth sidecar) | "log tool activity for auditing" yourself |
| Anthropic code execution tool | container | **no internet at all** | n/a | 5 GiB / 1 CPU |
| Claude Managed Agents | container per session, or **self-hosted sandbox workers** on E2B/Modal/Vercel/GKE and others | unrestricted or `allowed_hosts` ("per host, not per operation") | vaults | orchestration hosted, execution yours |
| Google Agent Engine Code Execution | managed sandbox | no network | n/a | 14-day state *(from search snippet)* |

Details and sources: [findings 03](findings/03-agent-sandbox-platforms.md) Part B.

#### 3.3 Agent runtimes that bundle a sandbox with a policy layer: NVIDIA OpenShell and peers

This group arrived with the 2026 wave of always-on "claw" personal agents (OpenClaw and its descendants). These projects put an existing isolation boundary under a declarative policy that covers the agent's files, processes, network and credentials. Full detail: [findings 05](findings/05-agent-runtimes-openshell-and-peers.md).

**NVIDIA OpenShell** ([repo](https://github.com/NVIDIA/OpenShell), Apache-2.0) was announced with NemoClaw at GTC on 2026-03-16 ([press release](https://investor.nvidia.com/news/press-release-details/2026/NVIDIA-Announces-NemoClaw-for-the-OpenClaw-Community/default.aspx)).

- **Split trust.**
  - A trusted **supervisor** outside the boundary makes every decision: it checks policy, holds credentials, resolves DNS and opens upstream connections.
  - Inside the boundary, the agent runs as one non-root user with no capabilities. **Landlock** confines its files, and **seccomp user-notification** hands every connect and DNS lookup to the supervisor.
  - If the supervisor channel drops, the agent is frozen ([architecture](https://docs.nvidia.com/openshell/latest/about/architecture.md)).
- **The outer fence depends on the backend.**
  - Docker/Podman: container with networking off.
  - Kubernetes: pod plus NetworkPolicy; a Kata RuntimeClass can be enabled by an operator.
  - **libkrun microVM** with no network device: the only hardware boundary, and it is "never auto-detected" ([runtimes](https://docs.nvidia.com/openshell/latest/how-it-works/sandboxes/runtimes.md)).
  - Every backend needs Linux 6.2+ for Landlock ABI 3.
- **Policy.**
  - YAML, evaluated with OPA, deny by default.
  - Network rules are keyed on host, port **and the calling binary**, with optional HTTP method/path rules.
  - Filesystem and process sections are fixed at creation; network sections hot-reload.
  - An admin **global policy** overrides everything.
  - An optional **advisor** lets the agent *propose* new network rules only. An SMT **policy prover** blocks auto-approval of anything that adds credentialed reach or metadata access ([policies](https://docs.nvidia.com/openshell/latest/how-it-works/policies/overview.md), [prover](https://docs.nvidia.com/openshell/latest/how-it-works/policies/prover.md)).
- **Egress and credentials.**
  - TLS is terminated by default with a per-sandbox CA.
  - Provider profiles bind a credential to hosts, paths and binaries; the agent sees a placeholder.
  - Metadata-IP and DNS-rebinding protection are built in ([best practices](https://docs.nvidia.com/openshell/latest/security/best-practices.md)).
  - The "privacy router" (`inference.local`) from the launch pitch was **removed in 0.1.0** ([upgrade guide](https://docs.nvidia.com/openshell/latest/upgrade/0-1-0.md)).
- **Observability: the best in this group.**
  - Every network, HTTP, process, filesystem-policy and config decision is an **OCSF v1.8.0** event with allow/deny, pid/binary and the matching policy.
  - Events stream to a CLI or TUI and export as OCSF JSONL for Splunk, Security Lake or CrowdStrike ([logging](https://docs.nvidia.com/openshell/latest/observability/logging.md)).
  - Gaps: no OpenTelemetry export is documented; the gateway buffer is in-memory only and drops events rather than blocking ([accessing logs](https://docs.nvidia.com/openshell/latest/observability/accessing-logs.md)).
  - The full logs sit inside the sandbox, so ship them off-box *(my inference)*.
- **Maturity.**
  - 0.1.0 shipped 2026-09-25 with **no in-place upgrade** from 0.0.x ([PyPI](https://pypi.org/pypi/openshell/json)).
  - Six CVEs were published 2026-08-25 for versions ≤0.0.33, including a 9.9 sandbox escape (CVE-2026-65093) and an L7-policy path-traversal bypass (CVE-2026-65092) ([CVE.org](https://cveawg.mitre.org/api/cve/CVE-2026-65093)).

**NVIDIA NemoClaw** ([repo](https://github.com/NVIDIA/NemoClaw), Apache-2.0, "alpha") is a reference stack that runs **the whole agent** inside OpenShell.

- Supported agents: OpenClaw, Hermes and LangChain Deep Agents.
- Hardening over plain OpenShell: stricter policies, compilers and netcat stripped from the image, read-only system dirs, host-secret filtering, and digest-verified blueprints ([ecosystem](https://docs.nvidia.com/nemoclaw/latest/about/ecosystem.md)).
- Tested on DGX Spark.
- It still **pins OpenShell 0.0.116** ([blueprint.yaml](https://raw.githubusercontent.com/NVIDIA/NemoClaw/main/nemoclaw-blueprint/blueprint.yaml)), so expect a migration.

**Peers**, grouped by what actually provides isolation:

| Project | Real boundary | Policy layer | Egress / credentials | Observability | License / status |
|---|---|---|---|---|---|
| **NVIDIA OpenShell** | Landlock+seccomp in container / pod / libkrun microVM | YAML + OPA, per-binary L7 rules, SMT prover, admin global policy | TLS MITM, placeholder creds per host/path/binary | **OCSF events → SIEM**; no OTel | Apache-2.0, 0.1.2 (4 days old) |
| NVIDIA NemoClaw | OpenShell 0.0.116 (containers) | Stricter blueprint policies | Host-secret filtering, providers | Inherits OpenShell | Apache-2.0, alpha |
| OpenClaw built-in | **Tools only**, off by default (Docker `network:none`, cap-drop ALL); gateway stays on host | JSON5 modes/scopes; `tools.elevated` escape hatch | n/a | `openclaw sandbox explain` | MIT; "not a perfect security boundary" ([docs](https://docs.openclaw.ai/gateway/sandboxing.md)) |
| NanoClaw | Docker container per agent group | Code + config | Credential gateway (OneCLI Agent Vault) | Minimal | MIT |
| IronClaw (NEAR AI) | WASM for tools; Docker for jobs | Capability grants, endpoint allowlist | Host-boundary injection + leak scanning | Tool-execution audit log, web UI | MIT/Apache-2.0 |
| OneCLI | Docker per person (other backends planned) | Workspace policy + grants | Rust MITM gateway, Bitwarden/1Password | Dashboard | Apache-2.0 |
| Microsoft Agent Governance Toolkit | **None**: "policy engine and agents share the same process boundary" ([README](https://github.com/microsoft/agent-governance-toolkit)) | YAML / OPA / Cedar per tool call | Identity (SPIFFE/mTLS), MCP gateway | Merkle tamper-evident audit log | MIT, public preview |
| Cisco DefenseClaw | None; designed to sit **on top of OpenShell** | Scan skills/MCP/code before run; hooks in log/block/HITL modes | Go gateway | **Splunk, OTLP, JSONL**, mandatory local SQLite | Apache-2.0 |
| Pipelock | Optional Landlock + netns (+seccomp), macOS Seatbelt | YAML strict/balanced/audit | DLP/SSRF/MCP-scanning proxy | Signed action receipts, Prometheus | Apache-2.0 source, paid binaries |
| agentsh | seccomp-notify / Landlock / FUSE / eBPF under the agent | allow/deny/approve/redirect/soft-delete | Service rules, DNS redirect | Structured audit events | Apache-2.0 |
| agentgateway (LF) | None (proxy) | CEL RBAC over MCP/A2A/LLM | OAuth/JWT | **OpenTelemetry**, UI | Apache-2.0 |
| AWS AgentCore Runtime | **microVM per session**, memory sanitized after | IAM | IAM | CloudWatch, OTel-compatible | hosted, GA |
| Azure Container Apps dynamic sessions | **Hyper-V** per session | Pool config, Entra RBAC | Egress blocked by default | Azure Monitor | hosted, GA |

**What this means for the ladder:**

- OpenShell is not a new isolation tier. On its default backends it is a tier-1 process sandbox inside a tier-2 container, and only the `vm` driver reaches tier 4 (with libkrun's shared-security-context caveat).
- What is new is the **integration**. It is the only self-hostable project found that combines, in one piece:
  - a kernel-enforced boundary;
  - per-binary egress and L7 policy;
  - credential placeholders;
  - a policy prover;
  - SIEM-grade decision logs.
- The governance toolkits (Microsoft AGT, DefenseClaw, agentgateway, the MCP gateways) are **tier-0 policy plus observation layers**. They complement a sandbox and do not replace one; AGT's README says so.

### 4. Network egress control

| Approach | Granularity | Stops domain fronting? | Stops DNS exfil? | Logs | Fits |
|---|---|---|---|---|---|
| `--network none` / `PrivateNetwork=` / netns | all or nothing | yes | yes | n/a | offline tasks |
| iptables/ipset from DNS at start (devcontainer) | IP | no | only if UDP/53 is locked down (it isn't in the reference) | only with LOG rules | single container |
| Landlock ABI 4+ / systemd `IPAddressAllow=` | TCP port / IP prefix | no | partial | audit / journald | homelab host services |
| Hostname/SNI proxy (srt, Codex proxy, Squid peek-splice, Smokescreen, E2B/Modal/Vercel SNI rules) | domain | **no** | depends | per-connection host | default for most tools |
| DNS allowlist (Fly Sprites, Cilium `toFQDNs`) | domain → IP | no | yes for resolver path | DNS logs / Hubble | Kubernetes |
| **TLS-intercepting proxy** (mitmproxy, Squid bump, httpjail, `coder/boundary`, Claude `tlsTerminate`, Cloudflare outbound handlers) | method / path / header | **yes** | yes if the proxy is the only path | **full request log** | small–medium teams |
| Kubernetes NetworkPolicy (vanilla) | L3/L4 only; no FQDN, no logging | no | no | none | only as a "can reach proxy only" fence |
| Tailscale ACLs (`tag:agent`) | tailnet peers, deny-by-default | n/a (not internet egress) | n/a | Tailscale logs | keeping homelab agents off the NAS / HA |

Key points:

- Put the enforcing proxy **outside the agent's process and trust domain**. In-process allowlists had parser bugs: CVE-2025-66479 and the SOCKS5 null byte.
- Block private, link-local and metadata IPs at the proxy (Smokescreen does this by default).
- Envoy warns its dynamic forward proxy is "subject to confused deputy attacks" without RBAC ([Envoy](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/dynamic_forward_proxy_filter)).

Sources: [findings 04](findings/04-egress-credentials-observability.md) §2.

### 5. Credential handling

- **Placeholder plus injection at the egress proxy.**
  - Claude Code `mask` (needs `tlsTerminate`; re-signs AWS SigV4; ignored if set from repo config so a malicious repo cannot redirect credentials) ([sandboxing](https://code.claude.com/docs/en/sandboxing)).
  - Docker Sandboxes, E2B, Vercel, Cloudflare, microsandbox, Deno Sandbox, OpenAI hosted shell and Runloop do the same.
  - Fly's open-source [tokenizer](https://github.com/superfly/tokenizer) binds each sealed secret to allowed destination hosts. Without that binding, a compromised client could send the secret to an echo service.
- **Short-lived, scoped credentials.**
  - GitHub App installation tokens expire in 1 hour and can be narrowed to specific repos and permissions ([GitHub](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)).
  - Vault dynamic secrets are issued per consumer with a TTL ([Vault](https://developer.hashicorp.com/vault/docs/secrets/databases)).
- **Residual risk.** Injection prevents *theft* of the secret but not *misuse through* it: the agent can still push to a public repo with the injected token. Pair it with narrow scopes and request-level policy.

### 6. Observability

#### 6.1 Where you can observe, by layer

| Layer | What it tells you | Tools | Survives strong isolation? |
|---|---|---|---|
| Agent / intent | prompts, tool calls, approval decisions, cost | Claude Code OTel (`claude_code.tool_decision`, `tool_result`; beta traces), Codex `[otel]` (`codex.tool_decision`), OpenHands OTel, hooks (`PreToolUse` with `tool_use_id`), JSONL transcripts; OTel GenAI semconv (`invoke_agent`, `execute_tool`, still *Development* status) → Langfuse / Phoenix | yes (runs outside or reports out) |
| Tool gateway | MCP calls | Docker MCP Gateway `--log-calls`, Leash, Coder AI Gateway, agentgateway (OTel), DefenseClaw (Splunk/OTLP) | yes |
| Policy runtime | every allow/deny decision with binary, destination and matching rule | **NVIDIA OpenShell OCSF events** (NET/HTTP/PROC/CONFIG) → JSONL for a SIEM | yes (supervisor sits outside the boundary) |
| Egress proxy | every outbound connection or request | Smokescreen, mitmproxy, `coder/boundary`, `sbx policy log`, Vercel `forwardURL`, Cloudflare outbound handlers | **yes: the best single chokepoint** |
| Sandbox policy | denied FS/network actions | Seatbelt unified log, `srt` violation store, Landlock audit (6.15+), seccomp `LOG`, AppArmor/SELinux audit | inside process sandboxes only |
| Host kernel (eBPF/audit) | every syscall, exec, file, socket | Falco (detect; Talon to respond), Tetragon (detect **and enforce**), Tracee, auditd, osquery | shared-kernel only; gVisor via Runtime Monitoring; **blind inside VMs** |
| VMM / runtime | resource use, lifecycle | Firecracker metrics FIFO, kata-monitor, gVisor metric server, libvirt domstats, E2B lifecycle events | yes but no workload detail |
| Filesystem result | what changed | container-use git branches, Lima `--sync`, E2B/Cloudflare file watch | yes |

**The observability inversion:**

| Boundary | Host kernel telemetry sees the agent's syscalls? |
|---|---|
| process sandbox / runc / Sysbox / LXC | yes, fully |
| gVisor | only via gVisor's own monitoring stream |
| Kata / Firecracker / full VM | no. You need an in-guest sensor, which the agent can attack, or you rely on the proxy and agent telemetry |

Under Confidential Containers the host is *deliberately* locked out. This follows from the architecture; no primary source states it for Kata specifically, so it is marked inference in [findings 04](findings/04-egress-credentials-observability.md) §4.1.

**Correlation.** A research system, AgentSight, uses eBPF SSL uprobes to join decrypted LLM traffic with kernel events at under 3% overhead ([arXiv 2508.02736](https://arxiv.org/abs/2508.02736)). The practical recipe:

1. Label each sandbox (container label, cgroup, VM name, proxy client identity) with the agent's `session.id`.
2. Log `tool_use_id` in a PreToolUse hook.
3. Join proxy, eBPF and agent spans in one OTLP collector.

#### 6.2 Platform observability reality check

- **Nothing native.** None of the surveyed platforms offers session replay or filesystem diff. The closest are container-use (review the agent's git branch), OpenHands + Laminar (browser replay), and E2B/Cloudflare file watch.
- **OTel export is rare.** Daytona has it (experimental), E2B only in Enterprise and only for metrics and lifecycle, and OpenHands (agent traces).
- **Best built-in audit trails:**
  - Runloop: 28-day command logs.
  - Docker `sbx policy log`: network only; "filesystem mount decisions aren't available in the log yet" ([Docker](https://docs.docker.com/reference/cli/sbx/policy/log/)).
  - Leash: FS + network + MCP.
  - `coder/boundary`: every request.

### 7. Escape and bypass history (why the tiers matter)

| Layer | Examples | Lesson |
|---|---|---|
| Agent policy / harness | Claude Code CVE-2025-54794, -54795, -58764, -64755, CVE-2026-25725, -55607; Codex CVE-2025-59532, GitPwned; Gemini CLI allowlist abuse; Cursor CVE-2026-48124; Pillar July 2026 cross-vendor set | **The most frequent failure.** Anything the host later executes (hooks, `.git/config`, IDE tasks, venvs) is attack surface: keep it read-only or run the whole harness inside the boundary |
| Sandbox + policy runtime | NVIDIA OpenShell ≤0.0.33: CVE-2026-65093 sandbox escape (9.9), CVE-2026-65092 L7 policy path-traversal bypass | New integrated runtimes carry fresh bugs; track versions closely |
| Agent network proxy | srt CVE-2025-66479 (empty allowlist = no enforcement); SOCKS5 null byte *(secondary)* | Add a second, independent egress control below the agent |
| Container runtime | runc CVE-2024-21626; CVE-2025-31133 / 52565 / 52881 (LSM bypass) | Rootless / userns; never let the agent build or run images against the host daemon |
| GPU toolkit | NVIDIA CVE-2024-0132, CVE-2025-23266 | Crafted images escape; keep untrusted agents off GPU hosts or use CDI mode and patched toolkits |
| Host kernel | GhostLock CVE-2026-43499 *(secondary)* | Shared-kernel tiers inherit every kernel LPE |
| gVisor | 2018 Gofer race; recent CUSE CVE *(unverified)* | Tiny history; the design deflects most kernel bugs |
| Kata / Cloud Hypervisor | 2020 Unit 42 pair; 2026 annotation / virtio-fs escapes; CH QCOW backing-file exfil | Host-side glue is the weak point; lock down annotations |
| Firecracker | 2019 vsock; CVE-2026-5747 (opt-in PCI) | Keep the device model minimal and stay on defaults |
| Wasm | Wasmtime CVE-2023-26489 (Cranelift) | The JIT is the TCB; layer an OS sandbox on top |

Sources: [findings 04](findings/04-egress-credentials-observability.md) §6 and [findings 02](findings/02-isolation-runtimes.md).

## Analysis: recommended setups by scale

### Homelab: one user, a handful of agents

**Option A, lowest effort (laptop or desktop):**

- Turn on the agent's built-in sandbox with `failIfUnavailable` / `allowUnsandboxedCommands:false` (Claude Code) or `workspace-write` with network off (Codex).
- Explicitly deny reads of `~/.ssh`, `~/.aws` and similar.
- Enable OTel into a local Langfuse or Phoenix container for an audit trail.
- **Guarantee:** protects against accidents and naive injection. It does not protect against a kernel exploit or a harness bug.

**Option B, recommended default: a disposable VM per project, or per agent group.**

- **Mac:** Apple `container` or Lima with `--mount-only .:w`, or `--sync` for review-before-apply. OrbStack isolated machines are acceptable for convenience, but by their own docs they are not a full boundary.
- **Linux:** an Incus VM, a Proxmox VM from a template, or Docker Sandboxes (`sbx run claude`). The Docker docs I read do not say which hypervisor or host OSes it supports, so check that first.
- **Network:**
  - Run the agent with its built-in sandbox *inside* the VM.
  - Add a host-side egress control on the VM's bridge: nftables default-deny plus a Squid peek-splice or mitmproxy allowlist that logs.
  - Put the VM on the tailnet as `tag:agent` with no grants to other nodes.
- **Credentials:** fine-grained or GitHub App tokens for one repo. Never mount the Docker socket. Use Sysbox or the VM's own Docker instead.
- **Observability:**
  - Agent OTel, proxy logs and the VM's git diff are enough.
  - If you want kernel visibility, run the agent in a container under gVisor inside the VM. That needs no nested virtualisation, and Falco can consume its stream.

**Option B′, an always-on "claw" or an integrated policy runtime:**

- NemoClaw on OpenShell is the most complete packaged option for OpenClaw/Hermes. It is alpha and pinned to OpenShell 0.0.116, so run it on a dedicated box or VM.
- For coding agents, OpenShell 0.1.x with the `vm` (libkrun) driver on a KVM host gives a microVM plus per-binary egress policy, credential placeholders and OCSF logs in one tool.
- Ship the OCSF JSONL off the box, and expect breaking changes.
- Avoid OpenClaw's own sandbox as the only layer. It is off by default, covers tools only, and leaves the gateway on the host.

**Option C, many short-lived runs:** microsandbox, smolvm or single-node E2B Embed on a KVM host. Remember libkrun's shared-security-context caveat, and that E2B calls Embed an evaluation package.

### Small team: 2–20 people, tens of concurrent agents

- **Boundary:** a microVM or gVisor per agent session. Self-host options are E2B, OpenSandbox, Coder workspaces on Kata/Sysbox, or Docker Sandboxes on each developer machine. Hosted options are Vercel, Cloudflare, E2B, Modal, Runloop and similar; prefer those that keep secrets out of the sandbox.
- **Egress:** a central TLS-intercepting allowlist proxy (mitmproxy, Smokescreen, `coder/boundary`, or Cloudflare/Vercel programmable egress) with per-session identity. Log every request. Block metadata and private ranges.
- **Credentials:** placeholder injection at the proxy; a GitHub App with 1-hour tokens; Vault for databases and cloud.
- **Integrated option:** a shared OpenShell gateway with an admin **global policy**, run through the prover in CI, gives one policy and audit plane across agents. Cisco DefenseClaw adds pre-run scanning of skills and MCP servers on top. Weigh this against OpenShell's youth.
- **Governance:** managed settings for the agent harness (`allowManagedHooksOnly`, admin-pinned sandbox config). Run MCP servers through a gateway (Docker MCP Gateway, Leash) so tool calls are logged and contained.
- **Observability:** agent OTel → Langfuse/Phoenix; proxy logs → the same backend or Loki; join on `session.id`.

### Medium: many teams, hundreds of sandboxes, Kubernetes

- **Orchestration:** `kubernetes-sigs/agent-sandbox` (Sandbox CRD, warm pools) or GKE Agent Sandbox, using a gVisor RuntimeClass by default and Kata for workloads needing full kernel compatibility or GPUs through QEMU. **Restrict Kata annotations.**
- **Network:**
  - Default-deny NetworkPolicy that allows only the egress proxy tier.
  - Cilium `toFQDNs` or the proxy for domain rules; vanilla NetworkPolicy has no FQDN or logging.
  - A TLS-intercepting proxy for path-level rules on dual-use domains like GitHub.
- **Runtime detection:**
  - gVisor Runtime Monitoring → Falco for workload syscalls.
  - Host Falco/Tetragon on nodes to catch runsc/VMM anomalies, i.e. escape attempts.
  - Tetragon for in-kernel enforcement on any shared-kernel pods.
- **Observability pipeline:** a single OTel collector ingesting agent spans (GenAI semconv), proxy logs, Falco events and K8s Events, keyed on a sandbox label derived from the agent session. Retain command logs; Runloop's 28-day retention is a useful benchmark.
- **Hosted alternative:** Claude Managed Agents with self-hosted sandbox workers on GKE Agent Sandbox, E2B or others. The orchestration is hosted while execution and its logs stay on your infrastructure.

### Trade-offs and caveats

- **Strength vs visibility.** Moving from a container to a VM removes host eBPF visibility. Plan the proxy and agent telemetry as primary audit sources before moving up the ladder.
- **Strength vs compatibility.**
  - gVisor breaks some syscall-heavy and I/O-heavy tools.
  - Kata lacks Podman support and checkpointing.
  - Wasm cannot run a toolchain.
  - Nested virtualisation is needed for Firecracker/Kata inside cloud VMs. EC2 added it for C8i/M8i/R8i in February 2026.
- **The boundary does not fix the trifecta.** A perfect VM with an allowlist containing `github.com` and a write-scoped token can still leak the repo. Scope credentials and inspect requests.
- **Integration vs maturity.** OpenShell-style runtimes remove a lot of glue work, but they are months old. A 0.1.0 breaking release with no upgrade path, and a batch of critical CVEs in August 2026, argue for pinning versions and keeping an independent egress control underneath.
- **Licensing and project churn.** Daytona went closed source in June 2026; mcp-run-python was archived; many 2025–26 tools are beta or pre-1.0. Prefer primitives with long histories (gVisor, Firecracker, Kata, bubblewrap) for anything you'll maintain.
- **Unverified items.** The gVisor CUSE CVE, Claude Code's SOCKS5 null-byte fix version, Landlock ABI 8+ kernel versions, E2B's ~150 ms boot figure and Kata/Cloud Hypervisor boot numbers have only secondary sources. They are flagged in the findings files.

## Files

- `README.md`: this report.
- `notes.md`: work log, including dead ends and assumptions that turned out wrong.
- `_summary.md`: index summary for the repo root README.
- `findings/01-os-primitives-and-agent-sandboxes.md`: namespaces, seccomp, Landlock ABI table, cgroups, LSMs, bubblewrap, firejail, nsjail, minijail, systemd, landrun, Seatbelt, Claude Code/Codex/Gemini/Cursor sandboxes, containers, devcontainers.
- `findings/02-isolation-runtimes.md`: gVisor, Kata/CoCo, Firecracker, Cloud Hypervisor, libkrun/smolvm/Hyperlight, macOS options, Sysbox/ECI, Incus, full VMs, Wasm/isolates, unikernels; observability inside vs outside.
- `findings/03-agent-sandbox-platforms.md`: 31 self-hosted and hosted agent sandbox platforms with a comparison matrix.
- `findings/04-egress-credentials-observability.md`: threat model, egress controls, credential brokering, Falco/Tetragon/gVisor monitoring, agent OTel, escape CVE history.
- `findings/05-agent-runtimes-openshell-and-peers.md`: NVIDIA OpenShell and NemoClaw in depth (architecture, policy model, prover, OCSF logging, CVEs), claw-style runtimes, governance toolkits and agent firewalls, AWS AgentCore and Azure dynamic sessions.

## Original Prompt

> Do a broad survey of agent isolation techniques and sandboxes from simple solutions for a single user running a handful of agents in a homelab to more complex systems suitable for small and medium sized deployments. Go broad and contrast capabilities and security guarantees as well as observability properties.
