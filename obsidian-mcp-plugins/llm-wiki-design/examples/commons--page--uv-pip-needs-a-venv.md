---
type: Finding
title: uv pip install fails outside a virtual environment
summary: uv pip refuses to install into the system interpreter unless a venv exists or --system is passed; create one with uv venv.
uuid: 7c1d0f3e-2b8a-4b8e-8f61-0d9a3c5e7a21
topics: [uv]
scope: {space: commons}
created: '2026-10-31T10:05:00Z'
updated: '2026-10-31T10:05:00Z'
status: stable
volatility: versioned
applies_to: {uv: '>=0.4'}
as_of: '2026-10'
check: uv --version >/dev/null
generated: {by: agent:codex@nas#s-0b19, at: '2026-10-31T10:05:00Z'}
verified:
  - {by: agent:verifier/opus-5.5, at: '2026-10-31T10:40:00Z', rev: 4be21d0, method: entailment}
sources:
  - id: uv-envs
    resource: https://docs.astral.sh/uv/pip/environments/
    title: uv docs, Using Python environments
    tier: T1
    retrieved: '2026-10-31'
    hash: sha256:87f867efa2d4fc16a145cf85fe22d3643c3b3bd83b7197c82db9520ecf8ce9e1
    quote: {exact: "uv will require a virtual environment", prefix: "", suffix: ""}
  - id: seen-homelab
    resource: project:homelab/ci/Dockerfile
    revision: 61b6f00
    tier: T1
---
`uv pip install PKG` fails when no virtual environment is active or discoverable.[^uv-envs]
Fix: `uv venv && uv pip install PKG`, or `uv pip install --system PKG` in a container image.[^seen-homelab]

[^uv-envs]: uv docs, Python environments (quote is illustrative in this example).
[^seen-homelab]: Observed in project homelab, ci/Dockerfile at 61b6f00.
