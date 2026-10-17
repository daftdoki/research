# A Shared Wiki for Many Agent Harnesses

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Which wiki or knowledge-base systems can several agent harnesses use at once? The harnesses in scope are Claude Code, Hermes Agent, Codex CLI, Gemini CLI, OpenCode, OpenClaw and others. The goal is one shared wiki plus wikis scoped to a project, a task or a single agent. A secondary question is whether one of these could replace the [iirc](https://github.com/daftdoki/dokidlc-iirc) memory plugin. It doesn't have to match all of iirc's features. ([original prompt](#original-prompt))

## Answer

**No product does all of this yet.** Two are close, from opposite directions, and everything serious in this space has settled on the same design: **markdown files in git as the source of truth, with a search index beside them that can be rebuilt.**

1. **[ai-memory](https://github.com/akitaonrails/ai-memory)** (MIT, Rust, v3.1.0 released 2026-10-16) is the turnkey choice.
   - **Storage:** a git-backed markdown wiki on one server you run. The SQLite index can be rebuilt from the files.
   - **Harnesses:** first-party hooks or MCP integration for about 40 harnesses, Claude Code, Codex, Gemini CLI, OpenCode, OpenClaw and Hermes among them.
   - **Scopes:** `workspace/project` scopes plus a reserved `_global` project for shared knowledge and a private `_profile.<user>` project. Projects can be set to `restricted` with per-user grants.
   - **Concurrency and handoffs:** one writer process handles all writes. Agents pass work to each other through handoffs, each claimed exactly once.
   - **What you give up:** iirc's trust model. A page does not cite `file@sha` and has no check command that marks it suspect. Memory is captured mostly from session hooks, not curated by the agent.
2. **[KiwiFS](https://github.com/kiwifs/kiwifs)** (BSL 1.1, Go) is the substrate to build on if you want to keep iirc's ideas.
   - **Storage:** one server holding several isolated **spaces**, each with its own git repo and search index. Every write is a git commit authored by the `X-Actor` header.
   - **Concurrency:** writes are guarded by ETag/`If-Match`. Bulk writes check `if_match` per file, and isolated drafts can be merged.
   - **Access:** 62 MCP tools plus REST, WebDAV and FUSE.
   - **What you have to build:** it has no harness hooks, so you write the per-harness adapters yourself. Its licence allows internal production use but not a competing hosted service.

**Recommendation:**
- Run ai-memory for a few weeks next to iirc, with Hermes and Claude Code both pointed at it. Your real decision is whether you want memory captured from sessions automatically or written by the agent with evidence attached.
- If it's the second, keep iirc's page format and trust rules. Move the storage to a spaces server (KiwiFS, or plain git repos behind a small MCP server), then add thin adapters for Hermes and Codex.
- **Don't** use an extracted-fact memory server as the wiki itself. That rules out Mem0, Graphiti/Zep, Cognee, Honcho and Hindsight. Their LLM rewrites what agents send into facts or graph edges that nobody can open and edit like a page. At most, use one as a derived index alongside the wiki.

**Follow-up: open licences and Karpathy's pattern.** KiwiFS has been under the BSL since its first commit, so there is no open version to fork. The closest OSI-licensed match is **[SilverBullet](https://github.com/silverbulletmd/silverbullet)** (MIT). It has multiple spaces with permissions for each account, git history attributed per account, and `If-Match` writes. It lacks an MCP server, and you would write one. Building from scratch with MIT/Apache parts is about the same effort:
- one git repo per space,
- [qmd](https://github.com/tobi/qmd) for search,
- a fork of `llm-wiki-mcp` for the MCP layer.

Karpathy's LLM Wiki works across many agents with four changes:
- generate `index.md` instead of having agents edit it,
- have the server write the `log.md` entries,
- keep one schema file per space,
- check `If-Match` on every page write.

See [the follow-up section](#follow-up-open-licence-alternatives-to-kiwifs-and-karpathys-pattern).

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. **Took inventory of iirc** from its README, `docs/HOW-IT-WORKS.md` and `docs/USAGE.md`. This was the baseline for "what replacing it would mean".
2. **Ran three surveys in parallel**, reading primary docs, repos and papers:
   - Markdown-native wikis: Karpathy's LLM Wiki pattern and its implementations, Basic Memory, qmd, memoryfield, Obsidian, SilverBullet, KiwiFS, and self-hosted wiki apps.
   - How each harness can be wired to an external store: MCP, hooks, skills, instruction files, and memory-provider plugin APIs.
   - Server-side agent memory systems and how they handle scoping, access control and concurrent writes.
3. **Checked the two front-runners myself** by shallow-cloning ai-memory and KiwiFS into a scratch directory and reading their docs and source. This corrected one survey claim: KiwiFS *does* have optimistic concurrency, in `internal/pipeline/pipeline.go`.

Nothing was installed or run. Every claim comes from documentation or source code.

## Results

### What iirc does today

iirc already has shared and project scopes. A project store lives in `.iirc/` inside each repo, and any number of remote stores are separate git repos. One search covers all of them. Its limits for this goal:

- **Claude Code only.** It is hooks, a skill and a hooks module that draws its UI.
- **Concurrency through git.** Each store has a lock and is committed per write; a rejected push is rebased once.
- **No per-agent or per-task scope.** The only scoping is which store a page goes to.

### Candidates against the requirements

| System | Source of truth | Many harnesses at once | Shared + scoped wikis | Concurrent writers | History | Licence | Fit |
|---|---|---|---|---|---|---|---|
| **[ai-memory](https://github.com/akitaonrails/ai-memory)** | git-backed md + rebuildable SQLite | ✓ hooks/MCP for ~40, Hermes included | ✓ workspace/project, `_global`, private profile, restricted projects with grants | single writer process, ~700 writes/s measured | git + version chain, `restore-page` | MIT | **best turnkey** |
| **[KiwiFS](https://github.com/kiwifs/kiwifs)** | md on disk, git commit per write | MCP/REST only, no hooks | ✓ isolated spaces, each its own git repo | ✓ ETag/`If-Match`, drafts with merge | git blame/diff/restore | BSL 1.1 | **best substrate** |
| [Basic Memory](https://github.com/basicmachines-co/basic-memory) | md + SQLite/Postgres index | MCP | ✓ projects, `search_all_projects`; Teams roles | overwrite flag; checksum on edit is Cloud only | Cloud history, no git | AGPL-3.0 | solid single-user |
| [SilverBullet](https://silverbullet.md/) | md files | HTTP API, community MCP only | spaces, read-write or read-only users | ✓ ETag/`If-Match` → 412 | git-backed revisions | MIT | good human UI |
| [OpenClaw memory-wiki](https://docs.openclaw.ai/concepts/memory) | compiled md vault | OpenClaw only | ✓ `vault.scope: global \| agent` | — | — | MIT | reference design |
| [Letta MemFS / shared repos](https://docs.letta.com/concepts/memfs) | git md | Letta agents only | ✓ shared repos + per-agent MemFS | git; blocks document last-writer-wins | git | Apache-2.0 | shared repos are Cloud only |
| [Docmost](https://docmost.com/docs/user-guide/mcp) / [Outline](https://docs.getoutline.com/s/guide/doc/mcp-6j9jtENNKL) | Postgres | official MCP | ✓ spaces/collections with real ACLs | realtime editing | page history | AGPL (MCP paid) / BSL | wiki for humans first |
| [qmd](https://github.com/tobi/qmd) | read-only index over md | MCP stdio/HTTP | collections | n/a | n/a | MIT | search layer only |
| [memoryfield](https://github.com/calpaterson/memoryfield-spec) | flat md field | CLI, no MCP | one field per spec | last write wins; `uuid` → 409 | none | AGPL tool | iirc's page format |
| Mem0, Graphiti, Cognee, Honcho, Hindsight | extracted facts / graph | MCP (often hosted only) | ids, groups, datasets, banks | mostly undocumented | varies | mixed | not a wiki |

### How each harness can be wired in

All of them can reach the same three things: an MCP server, `AGENTS.md`, and [Agent Skills](https://agentskills.io). With only those, the wiki is consulted only when the model decides to call a tool. iirc's main feature is pushing matching pages in front of the agent on every prompt, and that needs an adapter for each harness:

| Harness | Injection on every prompt | Pluggable memory slot |
|---|---|---|
| Claude Code | `UserPromptSubmit` → `additionalContext`. The hook can be an `http` or `mcp_tool` handler. | none (use plugins) |
| Hermes Agent | `pre_llm_call` hook → `{"context": …}`, or `MemoryProvider.prefetch()` | `MemoryProvider`, **one external provider at a time** |
| Codex CLI | `UserPromptSubmit` → `additionalContext`. Hooks must be trusted. | none (internal trait) |
| Gemini CLI | `BeforeAgent` → `additionalContext` | none |
| OpenClaw | `before_prompt_build` → `prependContext` | `registerMemoryCapability`, exclusive |
| OpenCode | plugin chat/system transform hooks; the API is changing between v1 and V2 | none |
| Cursor, Copilot | only at session start | none |

A Hermes adapter should use the `pre_llm_call` hook, not the `MemoryProvider` slot, so you can still run Honcho or another provider alongside it. ai-memory makes the same split: hooks for capture, and a community memory-provider plugin for the session lifecycle.

### Mapping your scopes

| Your scope | ai-memory | KiwiFS-based build | iirc today |
|---|---|---|---|
| shared, every agent | `_global` project; `global=true` search | a `shared` space | remote store |
| project | project, from the repo's git remote | one space per project | `.iirc/` project store |
| task | session pages + handoffs (not a wiki) | a short-lived space or a draft, merged when done | — |
| agent | `restricted` project or `_profile.<user>` | one space per agent | — |

### What replacing iirc would look like

| iirc feature | ai-memory | KiwiFS + your adapters |
|---|---|---|
| suggest pages on every prompt | ✓ bounded brief at session start, plus search | build it (hooks above) |
| suggest on a failed shell command | captures tool events; not the same suggestion | build it |
| search by meaning | FTS + entities + graph, vectors optional | FTS5 + pluggable vectors |
| page marked suspect when a cited `file@sha` changes or its check fails | ✗ (has contradiction flags and supersession instead) | carry over as frontmatter + a lint job |
| secret refusal on write | sanitises at a "typed privacy boundary" | build it, or use JSON-schema validation on write |
| pages travel with the repo in git | ✗, they live on the server | ✗, unless a project space is the repo's `.iirc/` |
| works with no network | local server | local server |

## Analysis

- **The two leaders disagree about who writes memory.** ai-memory records what happened through hooks and turns it into pages at session end. It also lets frequently used pages decay more slowly. iirc deliberately has the agent write a page only when something took more than one attempt, and never counts reads as a trust signal: the [earlier memory report](../agent-memory-systems-and-dreaming/) found that frequency is the signal a poisoned record exploits. In ai-memory, frequency affects how long a page is kept, not whether it is trusted, and its destructive aging steps are off by default. Even so, it is a different philosophy, and that, not the feature list, is the real choice.
- **Concurrency is mostly fine at your scale.** A few agents writing pages is low volume. What matters:
  - Two agents must not silently overwrite each other's page. KiwiFS and SilverBullet handle this with `If-Match`; ai-memory with its single writer. iirc's push-then-rebase-once approach would show its seams under many parallel agents.
  - Shared index files are the hotspot. Karpathy-style wikis' `index.md` and `log.md` are pages every write touches. Generate them, or give them one writer.
- **A shared wiki is an attack surface.** In [MINJA](https://arxiv.org/abs/2503.03704), an attacker plants records using nothing but queries. In a shared store, one agent hit by prompt injection poisons every agent that reads after it. The defences:
  - provenance on every write (ai-memory and KiwiFS both record the actor),
  - read-only scopes,
  - the ability to diff and revert, which git gives you.

  Graphiti's documentation states outright that a namespace "is not a security control".
- **Facts versus documents.** Letta's plain-files agent scored 74.0% on LoCoMo, against 68.5% for Mem0 ([Letta](https://www.letta.com/blog/benchmarking-ai-agent-memory)). LongMemEval's best design keeps raw values and uses extracted facts only as index keys ([arXiv 2410.10813](https://arxiv.org/abs/2410.10813)). Both support documents as the source of truth with facts as an index.
- **Caveats:**
  - Star counts and maturity come from the GitHub pages as fetched.
  - Antigravity CLI (Gemini CLI's successor for the free tier) and the OpenCode V2 plugin API were not verified.
  - ai-memory's Hermes session lifecycle depends on a community plugin.
  - ai-memory is young but very active: v3.0.1 and v3.1.0 shipped a day apart (2026-10-15 and 2026-10-16).

## Follow-up: open-licence alternatives to KiwiFS, and Karpathy's pattern

### There is no open KiwiFS to fork

KiwiFS has been under the BSL since its first commit (2026-04-23). Each release becomes Apache-2.0 four years after it ships. Of the OSI-licensed projects, none matches every part of KiwiFS's design. Three come close in different ways:

| Project (licence) | md is source of truth | Git commit per write, by agent | Spaces + per-space ACL | MCP | Write precondition | Search | Missing piece |
|---|---|---|---|---|---|---|---|
| KiwiFS (BSL 1.1), for reference | ✓ | ✓ (`X-Actor`) | ✓ | ✓ | ETag/`If-Match` | FTS5 + vectors | the licence |
| **[SilverBullet](https://github.com/silverbulletmd/silverbullet)** (MIT, v2.12.1) | ✓ | ~ batched about 30 s after edits stop, attributed to the account | ✓ multi-space by default since 2.10, per-space permissions | ✗ | ✓ `If-Match: "sha256:…"` → 412 | full-text + semantic | an MCP wrapper; a forced commit per write |
| **[OpenLore](https://github.com/aakarim/OpenLore)** (Apache-2.0) | ✓ | ✗ no git | ✓ docsets with per-identity `ro/publish/rw` grants | ✓ HTTP + stdio, also SSH/SFTP | ✓ SHA-256 compare-and-swap by default | grep/find only | git history, a search index |
| **[ai-memory](https://github.com/akitaonrails/ai-memory)** (MIT) | ✓ | ~ commits under one fixed `ai-memory` author; per-user audit kept in SQLite | ✓ restricted projects + grants | ✓ + hooks for ~40 harnesses | ✗ single writer instead | FTS + entities + graph | it's a memory system, not a wiki you organise yourself |
| [Gitea](https://gitea.com/gitea/gitea-mcp) + `gitea-mcp` (MIT) | ✓ (repos) | ✓ one Gitea user per agent | ✓ org/team/repo permissions | ✓ official | ✓ contents API needs the file's `sha` | weak | wiki links, backlinks, search |
| [sage-wiki](https://github.com/xoai/sage-wiki) (MIT) | ✓ | ~ one commit per compile | ✗ one wiki per server | ✓ | ✗ | BM25 + vectors + graph | multiple spaces, concurrency control |

Ruled out:
- Basic Memory: AGPL, no git.
- open-knowledge: GPL plus a CLA, and serves one project per server.
- lucasastorian/llmwiki: hosted mode keeps pages in Postgres, not markdown files.
- Gollum, Otter Wiki, Gitit: no API, one wiki per instance.
- Wiki.js 2: the database is the source of truth.
- Ar9av/obsidian-wiki: one tenant only.

**Closest match: SilverBullet.** It already has markdown spaces on one server, a permission for each account in each space, git history attributed to each account, strict `If-Match` writes and a good wiki UI. Two gaps:
- **No MCP server.** You'd write roughly 200 lines exposing `read`, `write` (with etag), `search`, `history` and `log_append` over its `/.fs`, `/.search` and `/.revisions` endpoints.
- **Commits are batched, not one per write.** Calling `POST /.revisions/` after each write forces one.

Attribution only works if each agent writes through the HTTP API with its own account token. SilverBullet records a change it didn't make itself, such as an agent writing the file directly, as **External**.

**Building it yourself takes about the same effort, and everything is MIT or Apache:**
- **Storage:** one git repo per space. Commit with `git commit --author` set from the agent's bearer token. Use the file's git blob SHA as its ETag, checked under a lock per repo.
- **Search:** [qmd](https://github.com/tobi/qmd), one collection per space. It already has an MCP server.
- **MCP layer:** start from [flsteven87/llm-wiki-mcp](https://github.com/flsteven87/llm-wiki-mcp) (MIT). It is alpha, but already shaped for Karpathy's pattern, with `wiki_read`, an ETag-checked `wiki_write_page`, `wiki_log_append` and `wiki_inventory`. Add a `space` argument, git commits and Streamable HTTP.
- **Human UI:** SilverBullet in *Unmanaged* revisions mode, pointed at the same folders. In that mode it reads git history but never commits.

### Fitting Karpathy's LLM Wiki to many agents

[The gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) describes three layers and three operations:
- **Layers:** `raw/`, immutable sources; `wiki/`, pages the LLM owns; and a schema file (`AGENTS.md`/`CLAUDE.md`).
- **Operations:** *ingest*, where one source may touch 10–15 pages; *query*, where good answers get filed back into the wiki; and *lint*, which looks for contradictions, stale claims and orphan pages.
- **Navigation:** `index.md` is a catalog the agent reads first. The gist says it "works surprisingly well" without embeddings at about 100 sources and hundreds of pages. `log.md` is an append-only record of what happened.

The gist assumes one person and one agent. It says nothing about simultaneous writers, scopes or trust. Running it with many agents needs four changes:

| Gist element | What breaks with many agents | Adaptation |
|---|---|---|
| `index.md`, updated on every ingest | Every ingest edits the same file, so writes collide constantly | Generate it from page frontmatter (title, summary, category) on commit or on read; agents never edit it |
| `log.md`, append-only | Simultaneous appends, and no record of who wrote what | The server appends entries with the agent's identity (llm-wiki-mcp has `wiki_log_append`), or each agent keeps its own log |
| one schema file | Different spaces need different rules | One `AGENTS.md` per space: the shared space gets strict ingest rules, an agent's own space gets loose ones |
| ingest touching 10–15 pages | Two agents reconcile the same entity page at once | `If-Match` on every page write; on a 412 the agent re-reads, merges and retries |
| `raw/` immutable | (nothing; this works well) | Shared `raw/` per space; project and task spaces link to it rather than copying |

The gist's *lint* is where iirc's trust model fits. A page that cites `file@sha` and has a `check` command is something a lint pass can mark suspect mechanically, before the LLM looks for contradictions by reading. Karpathy's pattern compiles knowledge from sources. iirc's pages record what the agent learned on the job. One wiki can hold both, as separate folders or `kind`s inside each space.

## Files

| File | Purpose |
|---|---|
| `README.md` | This report |
| `notes.md` | Work log, findings from each survey, corrections and dead ends |
| `_summary.md` | Index summary for the repository README |

## Original Prompt

> Research agent wiki solutions for multiple agent types (e.g., claude code, hermes, etc). I want a shared wiki that can be used by many agents at a time, as well as project, task, or agent specific wikis. Ideally I'd like to be able to replace my agent memory plugin (https://github.com/daftdoki/dokidlc-iirc) with it, but that is not required. That memory plugin would only be a subset of what I'd like the wiki to support, and I don't need to strictly replace all of its features.

Follow-up:

> I like the shape of kiwifs. Is there anything else like that with a more open license? ANd I also like Karpathy/s approach: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
