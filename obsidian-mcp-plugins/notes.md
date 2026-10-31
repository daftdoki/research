# Obsidian MCP plugins for a Karpathy "LLM Wiki" agent architecture — Notes

## Goal

Find Obsidian MCP servers/plugins that are popular, highly rated, actively maintained, with good code quality; semantic search a plus. Rank them for building the LLM Wiki pattern (raw sources -> LLM-maintained wiki -> schema; ingest/query/lint ops; index.md + log.md).

## Requirements derived from the gist

Read the raw gist (curl gist.githubusercontent.com/.../raw; `gh api gists/...` returned 502).
- Ingest touches 10-15 pages per source -> needs reliable create/edit/patch (section/frontmatter-level ideally), batch-ish writes.
- Query -> search (gist itself recommends qmd: hybrid BM25+vector+rerank, CLI + MCP) and read.
- Lint -> backlinks / orphans / unresolved links / frontmatter (Dataview) -> graph-aware tools valuable.
- Wiki is a git repo of markdown; Obsidian is the viewer. So filesystem-direct tools are valid; Obsidian-running isn't strictly required.

## Work log

### Discovery angles (2026-10-31)
1. GitHub search `obsidian mcp` sorted by stars (top 60). Noise: PDFMathTranslate (has an Obsidian integration, irrelevant), many "second brain" frameworks that bundle their own MCP.
2. Obsidian community plugin registry (`community-plugins.json` + `community-plugin-stats.json` from obsidianmd/obsidian-releases): 9,750 plugins, 65 mention MCP. Download counts give a popularity signal GitHub stars miss. Local REST API = 827,837 downloads; istefox mcp connector = 55,711; Nexus = 14,052; Vault as MCP = 12,948.
3. Alternate GitHub queries: "obsidian mcp semantic search", "obsidian vault mcp embeddings", "mcp server markdown vault hybrid search", "llm wiki obsidian mcp", "smart connections mcp". Surfaced the semantic-search long tail (flowing-abyss/obsidian-hybrid-search, pvliesdonk/markdown-vault-mcp, smart-connections-mcp bridges, engraph, turbovault).
4. Directories/reviews: Glama "best obsidian" (Oct 26 2026 ranking), ChatForest review (Mar-Aug 2026 audits). Glama surfaced aliasunder/vault-cortex and NoteDiscovery that GitHub search missed.
5. Web search for Obsidian 1.12 official CLI: no official Obsidian MCP; several thin CLI wrappers exist (single-tool `obsidian_exec`) - low popularity, not shortlisted.

Findings during discovery:
- jacksteamdev/obsidian-mcp-tools (830 stars, the old "semantic search via Smart Connections" option) was ARCHIVED May 2026. istefox/obsidian-mcp-connector is the community continuation (registry id `mcp-tools-istefox`).
- MarkusPfundstein/mcp-obsidian is the most-starred pure MCP server (4.5k) but only 4 commits in 90 days, 107 open issues, no GitHub release; ChatForest flags long dormancy.
- smithery-ai/mcp-obsidian is gone (404).
- Local REST API (coddingtonbear) now ships a built-in MCP endpoint (v4+), currently 5.5.2.
- skridlevsky/graphthulhu returned 404 from the API (moved/deleted) - dropped.

### Metrics
`repo_metrics.sh` pulls stars, push date, commits in last 90 days, contributors, latest release, CI workflow count, and test-file count from the GitHub API. Output saved as `metrics-2026-10-31.tsv`. Test-file count is a crude regex over the tree (counts files in tests/ dirs and *.test.* files) - signal, not proof.

### Deep dives
Split 17 repos across three parallel read-only auditors (gh api: README, tree, open issues, package.json/pyproject/Cargo.toml/tsconfig, CI files, key source). Groups: in-Obsidian plugins; external servers; semantic-search engines. Spot-checked the claims the ranking leans on myself:
- TurboVault README does list `generate_index`, `append_log_entry`, `graph_report`, `find_stale_notes`, `analyze_grounding`; vector plugin README confirms `vector_search_*` tools, Potion (model2vec static) embeddings, hnsw + bm25, "0.x".
- istefox README lists `find_orphaned_notes`, `find_broken_links`, `search_vault_smart`, MiniLM/EmbeddingGemma, headless mode.
- obsidian-hybrid-search README has the nDCG@5 table: 0.733 vs qmd 0.659 (self-reported, not reproduced).
- markdown-vault-mcp: code search finds orphan logic in `managers/link.py` and `docs/reference/tools/graph.md`.
- vault-cortex: no stdio mode in README (only mention is an mcp-remote stdio *bridge* for Claude Desktop) -> Docker HTTP only.

Surprises / dead ends:
- aaronsb's plugin is named "Semantic Notes Vault MCP" but has no embeddings; source calls "semantic" a deprecated alias that "never meant vector similarity".
- Smart Connections (1.26M downloads, the obvious "semantic search for Obsidian") has no MCP of its own, and the leading bridge (msdanyg) is broken against SC 4.7.x storage (issue #11). Dropped.
- MarkusPfundstein/mcp-obsidian: open path-traversal issue #150 and patch broken against Local REST API 5.x (#166/#158). Most stars, last place.
- cyanheads has ~1k tests but they don't run in CI (only CodeQL workflow).
- qmd: heaviest (~2.2 GB GGUF models), no file watcher, open reranker/latency bugs (#1088, #1031, #1053). Still the most sophisticated pipeline.
- Ar9av/obsidian-wiki (3.6k stars) is a skills framework for exactly the Karpathy pattern, delegating semantic search to qmd. Not an MCP server in the same sense -> listed as workflow layer, not ranked.

### Scoring
`scores.csv` (1-5 per criterion, my judgement from the metrics + audits) -> `rank.py` -> `ranking.md`. Weights: wiki fit .25, semantic .20, maintenance .20, quality .20, popularity .15.
Sensitivity: popularity-heavy weights put Local REST API first; semantic-heavy puts obsidian-hybrid-search first. istefox MCP Connector is #1 or #2 under all three weightings.

Key realisation for the architecture: Claude Code already reads/edits plain markdown natively, and the wiki is a git repo. The MCP layer earns its context cost only for (a) search beyond index.md, (b) link graph / lint queries, (c) link-safe renames. So prefer one write+graph server plus one search server over many overlapping ones.

### Follow-up: can istefox MCP Connector use a GPU or an embedding API? (2026-10-31)
- GPU: yes, but only through WebGPU and only automatically. `embedder.ts` probes `navigator.gpu.requestAdapter()` once. If an adapter is found it uses onnxruntime-web's WebGPU execution provider, otherwise single-thread WASM on the CPU. I found no CUDA, no native ONNX runtime and no user-facing device setting.
- CHANGELOG: EmbeddingGemma's WebGPU vectors ranked notes almost at random (1 of 7 test queries found the expected note, against 7 of 7 on WASM), so Gemma is now forced onto WASM. Issue #665 (Gemma on WebGPU writes corrupted vectors, M4) is still open. MiniLM and multilingual-e5 still use WebGPU when it is available.
- Headless mode: CPU-only MiniLM q8. README says "any GPU backend" is not available there.
- API embeddings: none. The semantic-search code has no OpenAI, Ollama or base-URL setting. The only other provider is Smart Connections, and Smart Connections moved all API-based models (cloud and local) into its paid Smart Chat Pro plugin (SC README). So an API route through it would need that paid plugin and would also depend on the istefox-to-Smart Connections bridge, which has had bugs (#99, #430).
- Alternatives that do support APIs: obsidian-hybrid-search (any OpenAI-compatible endpoint, so Ollama, LM Studio, OpenAI or OpenRouter, which also covers a GPU served by Ollama or LM Studio) and markdown-vault-mcp (FastEmbed, Ollama, OpenAI-compatible, Voyage).

## Expansion: designing our own LLM wiki (2026-10-31)

New request: multi-agent, multi-git-project wiki; cross-cutting topics (e.g. coding notes by language/tool) shared by all agents but general enough for any subject, like Wikipedia; formats (OKF, memoryfield as used by daftdoki/dokidlc-iirc); agent working memory as well as long-term knowledge; verification, source, accuracy and freshness semantics; how agents retrieve, search, publish and organise; centralised, reachable over the network, with a human UI. Off-the-shelf, open source, build-your-own or a mix.

Prior work in this repo to build on rather than redo:
- `multi-agent-shared-wiki/`: ai-memory (turnkey, MIT), KiwiFS (BSL substrate), SilverBullet (MIT, no MCP), a DIY stack (git per space + qmd + llm-wiki-mcp fork), and four changes Karpathy's pattern needs for many agents (generated index, log written by the server, schema per space, If-Match).
- `agent-memory-systems-and-dreaming/`: consolidation ("dreaming"), HaluMem shows memory-update correctness is the field's weak spot, frequency must not be a trust signal, copy-on-write consolidation.
- iirc (read README + HOW-IT-WORKS): memoryfield pages in `.iirc/`; frontmatter is title, summary, topics, kind, check, uuid, created, updated; cites `file@sha`; a page goes suspect when a cited file changes or its `check` fails; age is only a glance note; remote shared stores are git repos; hooks suggest pages on each prompt and failed command. The local `.memory/` pages in this repo show the format.

Plan: five parallel researchers. (A) page formats: OKF, memoryfield and others. (B) verification, provenance and freshness semantics. (C) organization, taxonomy, scoping, publishing workflow. (D) retrieval effectiveness and working memory. (E) platforms: network server, human UI, MCP.

### Expansion results (five researchers + my spot checks)
- **Formats.** OKF is Google Cloud's Open Knowledge Format: GoogleCloudPlatform/open-knowledge-format, SPEC.md "Version 0.2", Apache-2.0, 1,208★, created 2026-08-11, last push 2026-08-21, one maintainer. Only `type` is required. Provenance is `sources[]` with claims cited by `[^id]` footnotes. `generated{by,at}` and `verified[{by,at}]` give a trust tier that is derived, not stored (unverified, machine-confirmed, human-reviewed). Lifecycle is `status` (draft/stable/deprecated) plus `stale_after`. `index.md` and `log.md` are reserved names, matching Karpathy. Already OKF-native or import/export: ai-memory (14.7k★), markdown-vault-mcp, llm-wiki-compiler, Ar9av/obsidian-wiki, OpenClaw memory-wiki, Basic Memory sources.
  - **Catch I spotted in SPEC §5.1:** OKF's `sources[].usage_count` is a popularity signal, so our profile must ignore it for trust. The prior memory report found frequency is the signal poisoning exploits.
  - memoryfield v0.3 is flat with no types, links or provenance, and its `status` is a list. That collides with OKF's scalar `status`, so the memoryfield vocabulary moves to `conditions`. iirc's scalar `verified` becomes OKF's list.
- **Verification.** Model built from Wikipedia (verifiability, perennial-sources tiers, {{as of}}, pending changes, talk pages), Wikidata ranks and qualifiers, PROV-O names and W3C TextQuoteSelector. Claim-checking research: FActScore, SAFE, VeriScore, ALCE. ALCE found the best models lack full citation support 50% of the time, so an independent verifier is needed. FARMA beats consistency-based poisoning defences, so agreement between pages is not trust.
- **Organization.** Wikipedia's subpage history shows strict hierarchy failed. Flat page namespace, SKOS topic pages with broader/narrower, most-specific-topic rule, roll-up done by the hub generator. Repo per space because read permission is per repo. Draft/AfC for new shared pages, talk pages, a librarian bot under a bot-approval policy (Wikipedia BAG, Wikidata bots). Project identity by root commit SHA plus remote aliases (my design).
  - Nice convergence: memoryfield's flat directory rule and Wikipedia's flat mainspace agree.
- **Retrieval and working memory.** iirc's SEARCH-QUALITY data: only 31/74 prompts had a relevant page, so the push hook must default to silence. Anthropic Contextual Retrieval: -67% retrieval failures with contextual embeddings + BM25 + rerank. Cursor: semantic search +12.5%. Tool Search: Opus 4.5 79.5% to 88.1%. Working memory stays task-scoped (plan/progress/notes/handoff/board) with a TTL and an explicit `propose` to promote. Minimal tool set of 8 `wiki_*` tools.
- **Platforms.** No single OSS product covers everything. Checked myself:
  - ai-memory v3.3: web UI is read-only (docs/usage.md "The web UI is read-only").
  - KiwiFS: BSL, now has editor, graph and content health.
  - SilverBullet: still no official MCP (#1479 closed).
  - gosidian: MIT, 3★, created 2026-04, multi-project grants and OAuth. Promising but tiny.
  - Hatchdoor: AGPL, best UI, single user.
  - Forgejo/Gitea: gitea-mcp has OAuth and wiki tools; the place to review PRs.

### Building the design artifacts
- Wrote `llm-wiki-design/schema/wiki-page.schema.json`: the OKF v0.2 profile plus memoryfield/iirc fields plus design additions, with conditional rules (commons knowledge pages need sources and volatility; Working Notes need task and stale_after; Topics get SKOS fields; Redirects need a target).
- Wrote six example pages: Ada Lovelace entity, no-knead bread recipe, uv topic hub, uv coding finding, Karpathy source page, task working note.
- Dead end: the heredoc batch hung for 120 s. The cause was a trailing bare `ls` (the alias hang already in `.memory/bash-ls-alias-hangs-and-loop-path.md`). The files had been written; the shell just never returned.
- `validate_pages.py`, run with `uv run --no-project --with jsonschema --with pyyaml` (ephemeral environment, nothing installed into the project). The first run failed the topic page "uv" because of a 3-character minimum on titles in my schema; fixed by setting the minimum to 1. After the fix all six pass.
- Added `examples/invalid/unsourced-commons-finding.md`, which fails on all 5 planted errors: unquoted date, `status: verified` (not an OKF lifecycle value), missing sources, missing volatility, and a footnote with no source.
- Platform decision: the recommended target is the assembled stack plus a gateway we write, because every turnkey option misses identity mapped to git authors, the write gate, or working-memory tools. ai-memory and KiwiFS are offered as two-week pilots; both are OKF-compatible, so the content carries over.
