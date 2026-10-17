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

## Pass 1 results: markdown / file-native wikis

- No mature product covers "many harnesses writing one shared wiki concurrently + scoped sub-wikis + real conflict handling". Each covers part of it.
- Karpathy LLM Wiki gist (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f, 2026-04-04): pattern only (raw/ + wiki/ + schema file, index.md, append-only log.md; ingest/query/lint). Silent on multi-agent concurrency; index.md and log.md are the implicit hotspots.
- Basic Memory (AGPL-3.0, ~4.3k stars, v0.23): md + frontmatter + [[relations]], SQLite/Postgres index, ~20 MCP tools, multiple projects selectable per tool call, search_all_projects, Teams workspaces with roles. Hybrid FTS+vector. Overwrite guard = `overwrite=true` flag; `expected_checksum` on edit documented for Cloud. No git.
- qmd (MIT, ~30k stars): read-only search index (BM25 + vectors + rerank) over md dirs; CLI, MCP stdio and HTTP. Natural search layer for any md store.
- memoryfield spec/tool: single field per spec, last-write-wins PUT, uuid mismatch -> 409, If-Match optional. Tool is CLI only (no MCP), AGPL. ~42 stars.
- SilverBullet (MIT): HTTP /.fs API with sha256 ETag + If-Match -> 412; git-backed revisions; no official MCP.
- Obsidian Local REST API plugin: REST + built-in MCP; needs the desktop app running; one vault per app. Not server-friendly.
- KiwiFS (BSL 1.1, ~720 stars): md on disk, every write a git commit, multiple isolated workspaces each with own git repo + index, MCP + REST + NFS/S3/WebDAV/FUSE, scoped tokens/OIDC, X-Actor -> git author. No documented conflict handling. Closest file-native fit, but young + BSL.
- akitaonrails/ai-memory (MIT, ~9.6k stars): git-backed md wiki + derived SQLite (FTS5, entities, vectors); Rust MCP/HTTP server + lifecycle hooks for 20+ harnesses incl. Claude Code, Codex, Gemini CLI, OpenCode, Hermes; per-project shared knowledge, personal handoffs, cross-project profile; per-user tokens/OIDC; single SQLite writer. Closest to "cross-harness memory with hooks".
- Ar9av/obsidian-wiki (MIT): LLM-wiki skills symlinked into many agents; lock + atomic single writer for shared files (index/log).
- lucasastorian/llmwiki (Apache-2.0): MCP with create/list_knowledge_bases -> multiple wikis by slug.
- flsteven87/llm-wiki-mcp (1 star): good design reference: ETag -> WikiConflictError, temp+fsync+rename, O_APPEND log.
- inkeep/open-knowledge (GPL-3.0): md folders, MCP + CLI, `ok init` wires several harnesses.
- Serena memories: `.serena/memories/` + `global/` prefix, read-only patterns. claude-mem: SQLite/Chroma observations, not a wiki (and promotes a token — be careful).
- Server wikis: Docmost has official MCP that enforces space permissions but needs paid licence; Outline (BSL) official MCP over HTTP, collections. Wiki.js/BookStack/MediaWiki only community MCPs. MediaWiki has the best revision/edit-conflict model (base revision) and a ProfessionalWiki MCP. None store md in git natively.
- Dead ends: no DokuWiki MCP (search returns Dokku); several docs URLs 404'd (Wiki.js git storage, BookStack roles, Outline permissions); Hermes built-in llm-wiki skill seen only in third-party sources; "git-backed shared wiki for agents" searches mostly returned agent-to-agent bridges, not stores.

## Pass 3 results: server-side memory systems

- None of the extracted-fact servers is a wiki: Mem0, Graphiti/Zep, Cognee, Honcho, Supermemory, Hindsight, MemOS have an LLM rewrite input into facts/edges/"conclusions" that humans can't open and edit as a page.
- Mem0: OpenMemory MCP was sunset (issue mem0ai/mem0#4923, 2026-04-22). OSS `server/` (Postgres+pgvector) has no MCP; official MCP hosted only. Scopes user_id/agent_id/run_id/app_id, no per-scope ACL. Surprise: facts attributed to speaker, so AND(user, agent) matches nothing.
- Graphiti (Apache-2.0): bi-temporal graph, `group_id` = separate FalkorDB graph per group; search takes a list of group_ids. MCP server "experimental", its search tools expose no group param, no HTTP auth. Docs: group_id "is not a security control". Needs a structured-output LLM to ingest. Zep CE deprecated.
- Letta: moved from shared memory blocks to MemFS (git-backed md + frontmatter per agent) and shared memory repositories (org git repos). Shared repos are Letta Cloud only. Letta documents block concurrency: insert safe, replace mostly safe, rethink = last-writer-wins. Letta independently converged on git+markdown.
- Cognee (Apache-2.0, v1.6.1): datasets with real per-dataset read/write/delete/share ACL for users/tenants/roles. MCP in API mode = one token = one user per instance.
- Supermemory: namespace-scoped and read-only keys, but closed server binary, hosted-only MCP.
- Honcho (AGPL): workspaces > peers > sessions; models users/agents, not docs.
- Hindsight (MIT, 2026): memory banks, one MCP endpoint per bank (/mcp/{bank_id}/). Good scope mapping, opaque facts.
- agentmemory (rohitg00, Apache-2.0): shared/private namespaces, native plugins for Claude Code, Codex, Hermes; weak auth.
- MCP reference memory server: JSONL, now has a lock file; single machine; whole-file rewrites; no scoping.
- ByteRover/Cipher archived, Elastic License.
- Evidence: Letta's filesystem agent 74.0% LoCoMo vs Mem0 68.5% (https://www.letta.com/blog/benchmarking-ai-agent-memory); arXiv 2603.04814 long context beats Mem0 fact memory on recall; LongMemEval (2410.10813) best design keeps raw values, facts as index keys; arXiv 2606.24775 "no single architecture dominates". -> documents as source of truth, facts/graph as derived index.
- Poisoning: MINJA (2503.03704) plants records via queries alone; MemoryGraft (2512.16962). Shared store = one prompt-injected agent poisons all readers. Collaborative Memory (2505.18279) proposes private/shared tiers + immutable provenance + read/write policies.
- Dead ends: old OpenMemory and Letta filesystem URLs 404; Letta self-hosted MemFS status contradictory; Nowledge Mem license not found; an often-quoted "verbatim beats extracted by 15.9 points" claim had no source.

## Own verification of the two front-runners (cloned to scratchpad, read source/docs)

### akitaonrails/ai-memory (MIT, Rust, v3.1.0 released 2026-10-16)
- README: "source of truth is a git-backed wiki of ordinary .md files"; DB is a derived index rebuildable from files. Zero LLM calls by default; optional LLM consolidation and opt-in "dream".
- Support matrix lists 40-ish harnesses. Hermes = "Supported" via `install-hooks --agent hermes` (pre/post tool hooks into ~/.hermes/config.yaml) + community `ai-memory-hermes-plugin` memory provider owns session lifecycle; Hermes ignores session-start hook stdout so handoffs recovered via MCP.
- Identity coordinate is workspace/project (3-tuple). `projects.access_mode` open|restricted with grants; per-user tokens/OIDC; audit log. Reserved projects: `_global` (shared), `_profile`, `_profile.<user>` (private), `scratch`. Cross-project links `[[_global:path.md]]`, `global=true` search over pages across projects.
- `[auto_scope]` per_actor default (since v1.39) so two harnesses in different repos don't overwrite each other's "current project" pointer. They documented the bug it fixed: unscoped `memory_write_page` could land in the wrong project.
- Single-writer actor owns the SQLite write connection (~700 writes/s measured).
- Typed claim-once handoffs between agents.
- Memory aging: episodic tier decays; access count *slows* decay (access-weighted retention). Note: iirc's design deliberately ignores read frequency as a trust signal (poisoning). In ai-memory frequency affects retention, not trust; the destructive parts (compaction, dedup) are off by default.
- No file@sha "suspect" mechanism found; it has contradiction flagging and supersession chains instead.
- Gaps vs the user's "task" and "agent" scoped wikis: scoping is workspace/project/user; task ≈ session/handoff; per-agent wiki would be a project or a restricted project.

### KiwiFS (BSL 1.1 with an additional use grant allowing internal production use; Go; last commit 2026-10-14)
- Correction to pass 1: KiwiFS DOES have optimistic concurrency. GET returns an ETag; PUT honours If-Match (checked inside the write mutex, `ErrConflict`, internal/pipeline/pipeline.go); bulk writes take per-file `if_match`; refactor apply returns 409 on a stale plan; frontmatter field ownership 409s; isolated draft workspaces with merge (`internal/draft`).
- Multi-space: one server, isolated workspaces each with own git repo + index. Every write = atomic git commit; X-Actor header becomes git author.
- docs/MEMORY.md: conventions for episodic vs semantic memory (`memory_kind`, `memory_status`, `derived-from`, `merged-from`), no built-in LLM consolidation.
- No hooks/harness adapters: integration is MCP/REST/FUSE only. It's a wiki substrate, not a memory product.

## Pass 2 results: harness integration surfaces

- Common surface reaching every harness: one MCP server (stdio + Streamable HTTP), AGENTS.md, Agent Skills (agentskills.io lists Claude Code, Codex, Gemini CLI, OpenCode, Cursor, Copilot/VS Code, Hermes, OpenClaw). On that surface recall happens only when the model chooses to call a tool.
- Per-prompt automatic injection (the thing iirc's UserPromptSubmit hook does) is available in: Claude Code (UserPromptSubmit additionalContext; handler types include http and mcp_tool), Codex CLI (UserPromptSubmit/SessionStart additionalContext; hooks must be trusted), Gemini CLI (BeforeAgent additionalContext), Hermes (MemoryProvider.prefetch, or pre_llm_call plugin/shell hook returning {"context":...}; appended to the user message as <memory-context>), OpenClaw (before_prompt_build prependContext), OpenCode (plugin chat/system transform hooks; v1 vs V2 API in flux). Cursor and Copilot: session-start injection only.
- Hermes: MemoryProvider ABC (agent/memory_provider.py) with prefetch, sync_turn, on_pre_compress, on_memory_write, on_delegation, get_tool_schemas...; ONLY ONE external provider active. Built-in MEMORY.md 2,200 chars + USER.md 1,375 chars. Using pre_llm_call instead avoids taking the slot.
- OpenClaw ships a bundled memory-wiki plugin with `vault.scope: global | agent` -> per-agent wikis; tools wiki_search/wiki_get/wiki_apply. Good reference design.
- Codex has opt-in memories in ~/.codex/memories (internal MemoriesBackend trait, not pluggable).
- Anthropic Managed Agents memory stores: workspace stores mounted at /mnt/memory/<slug>/, read_only or read_write, up to 8 per session, versions, content_sha256 precondition. Closest Anthropic-native model of shared+scoped wiki but only for Managed Agents.
- Write-back on compaction possible in Claude Code, Codex, Gemini, Hermes, OpenCode, OpenClaw.
- Dead ends: developers.openai.com/codex now 308s to learn.chatgpt.com; Cursor memories page empty; Antigravity CLI (Gemini CLI successor for free tier) only from third-party sources; OpenCode plugin file moved in V2 layout.

## Synthesis

- Every serious file-native system converged on the same shape: markdown files in git as the source of truth, a rebuildable index beside it (ai-memory, KiwiFS, Letta MemFS, Basic Memory, iirc itself).
- Two realistic paths: adopt ai-memory (turnkey, cross-harness hooks incl. Hermes, scopes = workspace/project/_global/private, ACLs), or build on a wiki substrate (KiwiFS spaces + If-Match) with thin per-harness adapters carrying iirc's trust model.
- Extracted-fact servers are the wrong source of truth for a wiki; at most a derived index.

## Follow-up: open-licence KiwiFS alternatives + Karpathy pattern

- User likes KiwiFS's shape but wants a more open licence, and likes Karpathy's LLM Wiki approach.
- Read the gist in full (cloned gist to scratchpad, llm-wiki.md, ~1,900 words). Points relevant to multi-agent use:
  - Three layers: raw/ (immutable sources, the source of truth), wiki/ (LLM owns entirely), schema (CLAUDE.md/AGENTS.md) co-evolved with the human.
  - Ops: ingest (one source may touch 10-15 pages), query (file good answers back as pages), lint (contradictions, stale claims, orphans, missing pages).
  - index.md (catalog, updated every ingest, read first on query; "works surprisingly well at ~100 sources, ~hundreds of pages" without embeddings) and log.md (append-only, `## [date] op | title` prefix).
  - qmd suggested once search is needed. "The wiki is just a git repo of markdown files."
  - Written for one human + one agent. Says nothing about concurrent writers, scopes, or trust. Multi-agent adaptations needed: index.md and log.md become write hotspots (every ingest touches index.md) -> generate index.md from frontmatter and make log append-only per agent or server-appended; one schema file per space; raw/ stays immutable which suits a shared space well.
  - Fit with iirc: iirc's pages are "what the agent learned"; Karpathy's are "compiled knowledge from sources". iirc's refs/check trust model is a natural "lint" input; Karpathy's lint is contradiction/staleness by reading.
