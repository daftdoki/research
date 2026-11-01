---
type: Working Note
title: "Task uv-migration: claude-code notes"
summary: Open threads and next steps for moving homelab CI from pip to uv; promote findings, then let expire.
uuid: b81a6c07-5e2d-4f0c-a1d9-6c3e2f8b7d45
topics: [uv]
scope: {space: 'project:homelab', project: homelab, agent: claude-code, task: uv-migration}
created: '2026-10-31T11:00:00Z'
updated: '2026-10-31T11:40:00Z'
status: draft
conditions: [provisional]
stale_after: '2026-11-14T00:00:00Z'
generated: {by: agent:claude-code@nas#s-5e01, at: '2026-10-31T11:40:00Z'}
promote_to: [uv-pip-needs-a-venv]
---
- [x] Replaced pip in the CI image.
- [ ] Lockfile drift on the py3.12 runner (unconfirmed; do not promote yet).
- Finding: `uv pip install` needs a venv; proposed to commons as [[uv-pip-needs-a-venv]].
