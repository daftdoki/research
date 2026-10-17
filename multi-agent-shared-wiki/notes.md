# Multi-agent shared wiki — Notes

## Goal

Find wiki/knowledge-base solutions usable by many agent harnesses (Claude Code, Hermes, Codex, etc.) at once, supporting a shared wiki plus project/task/agent-scoped wikis, and judge whether one could replace dokidlc-iirc.

## Work log

- Branch already `claude/zen-meitner-nf8wjy`; stayed on it.
- Found a sibling report `agent-memory-systems-and-dreaming/` (memory benchmarks, dreaming). Will cite rather than repeat it.
- Cloned dokidlc-iirc (scratchpad, not committed) and read README, docs/HOW-IT-WORKS.md, docs/USAGE.md. Feature inventory:
  - Pages = markdown in `.iirc/` using Cal Paterson's memoryfield format (frontmatter: title, summary, topics, kind, refs, check, verified).
  - Search by meaning (embedding via ollama/OpenAI-compatible/CPU), string fallback; vectors in machine cache, rebuilt per clone.
  - Hooks inject suggestions on each prompt and each failed shell command; a suggestion gate with per-model thresholds; local usage logs to tune.
  - Trust: refs cite `file@sha`; page goes "suspect" when a cited file changes or `check` command fails; age only adds a "glance" note. Network checks need consent.
  - Stores: one project store (`.iirc/`, committed in project repo) + N remote stores (separate git repos cloned to ~/.local/share, commit+push per write, rebase once on reject). One search spans all stores. This is already "shared + project-scoped".
  - Secret-pattern refusal on write; per-store lock; commits only the store dir.
  - Claude Code only (hooks, skill, hooks-module UI). Not usable as-is by Hermes/Codex except via the `iirc` CLI.
- Key gap for the user's goal: iirc is single-harness and git-based (concurrency = per-store lock + push/rebase), no agent/task scoping beyond store choice.
- Split the landscape into three parallel research passes: (1) markdown/file-native wikis incl. Karpathy's LLM-Wiki pattern, Basic Memory, qmd, memoryfield, Obsidian, self-hosted wiki apps; (2) how each harness (Claude Code, Hermes, Codex, Gemini CLI, OpenCode/OpenClaw, Cursor) can plug in an external wiki; (3) server-side memory systems (Mem0, Graphiti/Zep, Letta, Cognee, Honcho, ...) and their scoping/concurrency.
