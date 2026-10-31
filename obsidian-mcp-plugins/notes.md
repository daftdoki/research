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
