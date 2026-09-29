# Agent isolation & sandboxes survey — Notes

## Goal

Broad survey of agent isolation/sandboxing from homelab to small/medium deployments; contrast capabilities, security guarantees, observability.

## Work log

- Split the survey into four research tracks, each delegated to a subagent that reads primary docs and records sources:
  1. OS-level primitives and the sandboxes built into coding agents (bubblewrap, Landlock, seccomp, Seatbelt, Claude Code / Codex / Gemini CLI sandboxes, rootless containers).
  2. Stronger isolation runtimes (gVisor, Kata, Firecracker, Cloud Hypervisor, libkrun, Apple Containerization, WASM, Sysbox, Incus).
  3. Agent sandbox platforms, self-hostable and hosted (E2B, Daytona, microsandbox, container-use, Docker Sandboxes, k8s agent-sandbox, Modal, Cloudflare, Vercel, etc.).
  4. Cross-cutting controls: egress filtering, credential brokering, runtime security/observability (Falco, Tetragon, auditd), LLM tracing, recent escape CVEs.
