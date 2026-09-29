# Agent isolation & sandboxes survey — Notes

## Goal

Broad survey of agent isolation/sandboxing from homelab to small/medium deployments; contrast capabilities, security guarantees, observability.

## Work log

- Split the survey into four research tracks, each delegated to a subagent that reads primary docs and records sources:
  1. OS-level primitives and the sandboxes built into coding agents (bubblewrap, Landlock, seccomp, Seatbelt, Claude Code / Codex / Gemini CLI sandboxes, rootless containers).
  2. Stronger isolation runtimes (gVisor, Kata, Firecracker, Cloud Hypervisor, libkrun, Apple Containerization, WASM, Sysbox, Incus).
  3. Agent sandbox platforms, self-hostable and hosted (E2B, Daytona, microsandbox, container-use, Docker Sandboxes, k8s agent-sandbox, Modal, Cloudflare, Vercel, etc.).
  4. Cross-cutting controls: egress filtering, credential brokering, runtime security/observability (Falco, Tetragon, auditd), LLM tracing, recent escape CVEs.
- Track 4 (controls/observability) came back. Key lessons:
  - Several exfiltration attacks went through *allowed* domains: api.anthropic.com Files API, GitHub via the GitHub MCP server, and Codex's broad default allowlist. So an allowlist alone is not the whole answer.
  - I had assumed Anthropic's reference devcontainer firewall was strict default-deny. Reading init-firewall.sh shows it allows UDP/53 and TCP/22 to any host plus the host /24, and resolves domains once at start.
  - Most published agent-sandbox escapes are bugs in the agent's own policy layer (config/hook injection, allowlist parsing, Docker socket exposure), not kernel or hypervisor breaks.
  - Host eBPF tools (Falco, Tetragon) lose visibility inside microVM guests; gVisor exports its own runtime-monitoring stream that Falco can consume.
  - Items that only have secondary sources are marked uncertain: SOCKS5 null-byte bypass, Cursor "DuneSlide", Docker MCP Gateway flag names, gVisor CVE-2025-2713.
- Track 3 (platforms) came back: 31 platforms or tools covered. What surprised me:
  - Daytona went closed source on 2026-06-11. v0.190.0 was the last AGPL release, and a community fork called Nightona is continuing from it. I had assumed it was a stable OSS self-host option.
  - Pydantic's mcp-run-python was archived on 2026-01-30. Its successor is Monty, an MIT-licensed Python interpreter written in Rust. That changes the "WASM code-exec MCP" recommendation.
  - Keeping credentials out of the sandbox, via an egress proxy that swaps in the real secret, is now standard on hosted platforms. Modal is the notable exception: it still uses environment variables.
  - Observability is thin across platforms. None offers native session replay or filesystem diffs. OTel export exists in only a few places, some experimental and some enterprise-only.
  - Needs checking: E2B's ~150 ms startup is from secondary sources only. Morph's internals are undocumented. The agent-sandbox release dates look off.
- Track 2 (runtimes) came back. What changed my framing:
  - gVisor needs no KVM (systrap has been the default since 2023), so it is the only strong boundary that works inside an ordinary cloud VM or Proxmox guest without nested virtualisation.
  - libkrun's README says the guest and the VMM share one security context. microVM tools built on it need host-side sandboxing of the VMM process, so "microVM" does not automatically mean "VM-grade boundary".
  - OrbStack's own docs say isolated machines "aren't a full security boundary" because they share one kernel. Apple `container` runs a real VM per container.
  - Kata's 2026 advisories are mostly in host-side glue (pod annotations, virtiofsd, hotplug), not KVM.
  - Observability inverts with boundary strength: host eBPF sees everything for runc/Sysbox/LXC, gVisor needs its own runtime-monitoring stream, and VMs are opaque without an in-guest agent.
  - Leaving out gVisor "CVE-2026-96812" as a headline. It was published four days ago and I could find no vendor advisory or NVD analysis, only an OpenCVE entry plus a matching commit. I'll mention it only as unverified.
