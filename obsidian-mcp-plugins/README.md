# Obsidian MCP servers for a Karpathy-style "LLM Wiki" agent architecture

## Question / Goal

Which Obsidian MCP plugins and servers are popular, well rated, actively maintained and well engineered, with good semantic search as a plus? Which of them best support an agent that runs [Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)? See the [Original Prompt](#original-prompt).

In that pattern an agent ingests immutable raw sources into an LLM-owned, interlinked markdown wiki. Obsidian is the viewer. The work follows three operations:

- **Ingest:** about 10–15 page edits per source, plus updates to `index.md` and `log.md`.
- **Query:** search the wiki, then synthesise an answer and file it back as a page.
- **Lint:** find orphans, missing cross-links, contradictions and stale claims.

## Answer / Summary

**Top pick: [MCP Connector by istefox](https://github.com/istefox/obsidian-mcp-connector)**, the community continuation of the now-archived `jacksteamdev/obsidian-mcp-tools`.

- It is the only maintained server that combines all of these:
  - local on-device semantic search
  - lint tools: `find_orphaned_notes`, `find_broken_links`, backlinks and outgoing links
  - link-safe rename
  - Dataview queries
  - a headless mode that works when Obsidian is closed
- It is in the official community store with about 55.7k downloads.
- It had 437 commits in the last 90 days.
- It has about 3.7k tests, with CI that runs an MCP conformance suite.
- It ranked #1 or #2 under all three weightings I tested.

**Recommended architecture:** one write + graph server plus one strong search server. Avoid several overlapping servers. Claude Code can already edit markdown files directly, so the MCP layer only earns its context cost for three things: search beyond `index.md`, graph/lint queries, and link-safe renames.

| Role | Obsidian open ("Obsidian is the IDE") | Headless or git-centric agents |
|---|---|---|
| Write + graph + lint | **istefox MCP Connector** | **[TurboVault](https://github.com/Epistates/turbovault)** in git-backed mode: atomic batches, `generate_index`, `append_log_entry`, `graph_report`, `find_stale_notes` |
| Semantic search | Built into istefox (vector only), or add **[obsidian-hybrid-search](https://github.com/flowing-abyss/obsidian-hybrid-search)** | **obsidian-hybrid-search**: BM25 + vectors + cross-encoder rerank, wikilink-aware, file watcher |
| Alternative search | **[qmd](https://github.com/tobi/qmd)**, which Karpathy names. It has the strongest pipeline (query expansion, HyDE, LLM rerank) but needs about 2.2 GB of models, has no file watcher, and has open latency and reranker bugs | same |
| Workflow / schema | your `CLAUDE.md`; [Ar9av/obsidian-wiki](https://github.com/Ar9av/obsidian-wiki) has ready-made ingest/query/lint skills for this exact pattern | same |

Strong runners-up:

- **[markdown-vault-mcp](https://github.com/pvliesdonk/markdown-vault-mcp)**: the richest lint toolset, plus index/log generation and git history. Python, 37★.
- **[Vault Cortex](https://github.com/aliasunder/vault-cortex)**: hybrid search with rerank and full CRUD and graph tools, but Docker/HTTP only and English-only embeddings.

**Avoid:**

- **MarkusPfundstein/mcp-obsidian**, despite having the most stars (4.5k). Its path-traversal issue #150 is open, its patch tool is broken on Local REST API 5.x, and it gets few commits.
- **Smart Connections bridges.** Smart Connections has no MCP server of its own, and the leading bridge cannot read SC 4.7.x vectors.
- **jacksteamdev/obsidian-mcp-tools**, which is archived.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. **Derived requirements from the gist.** The gist asks for:
   - reliable multi-page writes, ideally section- or frontmatter-level patches
   - search that scales past `index.md` (it suggests qmd)
   - graph queries for lint: orphans, broken links, backlinks
   - frontmatter for Dataview
   - plain git-friendly files
2. **Searched for candidates from five angles:**
   - GitHub repository search: `obsidian mcp` sorted by stars, plus four variants (semantic search, embeddings, hybrid search, llm wiki, smart connections).
   - The **official Obsidian community-plugin registry** joined with its download stats (`obsidianmd/obsidian-releases`): 9,750 plugins, 65 of which mention MCP. Download counts measure popularity that GitHub stars miss.
   - MCP directories: Glama's ["best Obsidian" ranking](https://glama.ai/mcp/best/obsidian), dated 2026-10-26.
   - An independent review: [ChatForest's Obsidian MCP review](https://chatforest.com/reviews/obsidian-mcp-servers/), with audits from March to August 2026.
   - Web search for wrappers around the official Obsidian 1.12 CLI. These turned out to be small single-tool shims, so none was shortlisted.
3. **Collected metrics for 35 repos** with [`repo_metrics.sh`](repo_metrics.sh), saved as [`metrics-2026-10-31.tsv`](metrics-2026-10-31.tsv). It records stars, last push, commits in the last 90 days, contributors, latest release, CI workflows and a count of test files.
4. **Audited 17 repos in depth** using only the GitHub API (no installs). For each I read the README, the file tree, open issues, the build/type/lint config, the CI workflows and the key source for tools and search. I then checked the load-bearing claims myself, listed in [notes](notes.md).
5. **Scored** each candidate from 1 to 5 on five criteria in [`scores.csv`](scores.csv), then ranked them with [`rank.py`](rank.py) using weights that follow your priorities:
   - wiki fit 0.25
   - semantic search 0.20
   - maintenance 0.20
   - code quality 0.20
   - popularity 0.15

## Results

### Ranking (default weights, data as of 2026-10-31)

| # | Candidate | Pop | Maint | Quality | Semantic | Wiki fit | **Score** |
|---|---|---|---|---|---|---|---|
| 1 | [MCP Connector (istefox)](https://github.com/istefox/obsidian-mcp-connector) | 3 | 5 | 4.5 | 3 | 5 | **4.20** |
| 2 | [TurboVault](https://github.com/Epistates/turbovault) | 2 | 5 | 5 | 3 | 5 | **4.15** |
| 3 | [markdown-vault-mcp](https://github.com/pvliesdonk/markdown-vault-mcp) | 1.5 | 5 | 4.5 | 3.5 | 5 | **4.08** |
| 4 | [Vault Cortex](https://github.com/aliasunder/vault-cortex) | 1 | 5 | 4.5 | 4 | 4.5 | **3.98** |
| 5 | [obsidian-hybrid-search](https://github.com/flowing-abyss/obsidian-hybrid-search) | 2 | 5 | 4.5 | 5 | 2.5 | **3.83** |
| 6 | [basic-memory](https://github.com/basicmachines-co/basic-memory) | 4.5 | 5 | 4.5 | 3.5 | 2 | **3.77** |
| 7 | [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) | 5 | 5 | 4.5 | 1 | 3.5 | **3.73** |
| 8 | [Semantic Notes Vault MCP (aaronsb)](https://github.com/aaronsb/obsidian-mcp-plugin) | 3 | 5 | 4.5 | 1 | 4.5 | **3.67** |
| 9 | [qmd](https://github.com/tobi/qmd) | 5 | 4 | 3.5 | 4.5 | 2 | **3.65** |
| 10 | [cyanheads obsidian-mcp-server](https://github.com/cyanheads/obsidian-mcp-server) | 3.5 | 5 | 4 | 1.5 | 3 | **3.38** |
| 11 | [MCPVault](https://github.com/bitbonsai/mcpvault) | 4 | 5 | 4 | 1.5 | 2.5 | **3.33** |
| 12 | [Nexus](https://github.com/ProfSynapse/nexus) | 2.5 | 5 | 3.5 | 3 | 2 | **3.18** |
| 13 | [obsidian-mcp (Stavrakis)](https://github.com/StevenStavrakis/obsidian-mcp) | 3.5 | 2.5 | 4 | 1 | 2.5 | **2.65** |
| 14 | [Vault as MCP](https://github.com/ebullient/obsidian-vault-mcp) | 2 | 4 | 3.5 | 1 | 2.5 | **2.62** |
| 15 | [mcp-obsidian (Pfundstein)](https://github.com/MarkusPfundstein/mcp-obsidian) | 5 | 1.5 | 2 | 1 | 2.5 | **2.27** |

**Sensitivity.** Under popularity-heavy weights, Local REST API comes first, followed by istefox, basic-memory, qmd and TurboVault. Under semantic-heavy weights, obsidian-hybrid-search comes first, followed by istefox, markdown-vault-mcp, Vault Cortex and qmd. The istefox MCP Connector stays in the top two under every weighting.

### Raw signals for the leaders

| Repo | ★ | Store downloads | Commits (90d) | Contributors | Latest release | Open issues |
|---|---|---|---|---|---|---|
| istefox/obsidian-mcp-connector | 123 | 55,711 | 437 | 18 | 3.3.0 (10-29) | 5 |
| Epistates/turbovault | 157 | n/a (binary/crate) | 81 | 10 | v4.0.2 (10-16) | 10 |
| pvliesdonk/markdown-vault-mcp | 37 | n/a (PyPI) | 550 | 12 | v5.1.0 (10-07) | 164 (mostly self-filed tracking) |
| aliasunder/vault-cortex | 32 | n/a (Docker) | 456 | 4 | v0.55.5 (10-31) | 3 |
| flowing-abyss/obsidian-hybrid-search | 117 | n/a | 181 | 6 | v0.17.2 (10-26) | 3 |
| coddingtonbear/obsidian-local-rest-api | 3,097 | 827,837 | 48 | 25 | 5.5.2 (10-17) | 5 |
| tobi/qmd | 30,780 | n/a (npm) | 201 | 91 | v2.8.3 (08-16) | 244 |
| MarkusPfundstein/mcp-obsidian | 4,513 | n/a (PyPI) | 4 | 18 | none on GitHub | 107 |

Store downloads apply only to Obsidian plugins listed in the community store.

### Semantic search compared

| Engine | Keyword | Embeddings (default) | Fusion | Rerank | Chunking | Incremental |
|---|---|---|---|---|---|---|
| obsidian-hybrid-search | FTS5 BM25, with title/alias boosts and fuzzy matching | multilingual-e5-small (local ONNX) or any OpenAI-compatible API | weighted RRF | optional cross-encoder (gte-multilingual) | by heading | chokidar watcher |
| qmd | FTS5 BM25 | embeddinggemma-300M (local GGUF) | RRF k=60, plus LLM query expansion and HyDE | Qwen3-reranker 0.6B | ~900 tokens, prefers heading breaks | manual `qmd update/embed` |
| Vault Cortex | FTS5 | bge-small-en-v1.5 (English only) | RRF, 4 legs | ms-marco MiniLM cross-encoder | heading-aware, 450-token cap | watcher |
| markdown-vault-mcp | FTS5 | bge-small (FastEmbed), Ollama, OpenAI or Voyage | RRF with a diversity cap | none | adaptive by heading | hash-gated, watcher optional |
| TurboVault (plugin) | Tantivy BM25 | Potion static model (model2vec) | RRF with HNSW | none | per-chunk, SHA-gated | yes |
| istefox Connector | regex/literal (separate tool) | MiniLM-L6-v2, EmbeddingGemma or multilingual-E5 (local ONNX) | none (vector only) | none | n/a | debounced, hash reuse |

obsidian-hybrid-search self-reports nDCG@5 of **0.733 vs qmd's 0.659** on the Obsidian Help vault. I did not reproduce this.

### Tool coverage for ingest, query and lint

| | Section/frontmatter patch | Link-safe rename | Backlinks | Orphans | Broken links | Batch / atomic | index/log helpers | Needs Obsidian running |
|---|---|---|---|---|---|---|---|---|
| istefox Connector | ✓ | ✓ | ✓ | ✓ | ✓ | batch read | – | no (headless mode) |
| TurboVault | frontmatter; search/replace edits | ✓ (`update_backlinks`) | ✓ | count via `vault_health` | ✓ | ✓ atomic, git | ✓ | no |
| markdown-vault-mcp | edit, etag | ✓ | ✓ | ✓ | ✓ | git auto-commit | ✓ (OKF) | no |
| Vault Cortex | ✓ | ✓ | ✓ | ✓ | ✓ (prompt) | per-file mutex | – | no (Docker) |
| Local REST API | ✓ heading/block/frontmatter | ✓ | in read result | – | unresolved in read | ETag `ifMatch` | – | yes |
| aaronsb plugin | ✓ | ✓ | ✓ | ✓ | ✓ | – | – | yes |
| cyanheads | ✓ | – | via JsonLogic | – | – | – | – | yes (REST API) |
| MCPVault | string replace | ✗ breaks links | – | – | – | read only, max 10 | – | no |

## Analysis

- **Stars mislead in this space.** The most-starred pure server, MarkusPfundstein/mcp-obsidian, is close to unmaintained, has an open security bug and breaks on the current REST API. Several of the best-engineered servers have fewer than 200 stars because they are younger than the January–April 2026 rush of starred repos. For Obsidian plugins, registry download counts are a better popularity signal. That is why istefox (123★, 55.7k downloads) scores above its star count suggests.
- **"Semantic" in a name proves nothing.** aaronsb's "Semantic Notes Vault MCP" has no embeddings. Smart Connections, the default semantic plugin with 1.26M downloads, has no working MCP path today.
- **Search vs. maintenance is a real split.** The best retrievers (obsidian-hybrid-search, qmd) are read-only. The best wiki maintainers (istefox, TurboVault, markdown-vault-mcp) have average semantic search: vector-only, static embeddings, or no reranker. Pairing one of each fits Karpathy's own suggestion that a search engine is an optional add-on tool.
- **Fit to the gist's operations:**
  - **Ingest** needs safe multi-file writes. TurboVault's git-backed atomic batches and Local REST API's ETag preconditions are the strongest here. istefox relies on Obsidian's own file manager.
  - **Query** at "~hundreds of pages" works with `index.md` alone. Add obsidian-hybrid-search or qmd once you outgrow it.
  - **Lint** is where MCP adds the most: orphan and broken-link tools save the agent from parsing every file itself.
- **Bus factor.** Almost every candidate has a single primary maintainer. TurboVault (about 2), basic-memory (about 3) and qmd are the exceptions. Pin versions, and keep the wiki as plain markdown in git so you can swap servers later.
- **Caveats:**
  - Scores are my judgement, based on public metrics and code reading, not on running the tools.
  - Test counts come from grep.
  - Benchmark figures are self-reported by the projects.
  - Known issues to watch: the istefox EmbeddingGemma full rebuild can block the UI for hours (#664), so use MiniLM. TurboVault's vector plugin is 0.x and opt-in (`--plugins`). In TurboVault plain-folder mode, `move_note` does not rewrite links unless you pass `update_backlinks=true`.

## Files

| File | Purpose |
|---|---|
| `README.md` | This report |
| `notes.md` | Work log: discovery angles, dead ends, verification spot-checks |
| `repo_metrics.sh` | Pulls GitHub activity and quality signals for a list of repos (`./repo_metrics.sh owner/repo ...`) |
| `metrics-2026-10-31.tsv` | Output of `repo_metrics.sh` for 35 candidate repos |
| `scores.csv` | 1–5 scores per criterion, with a one-line justification each |
| `rank.py` | Applies the weights to `scores.csv` and prints the ranking table |
| `ranking.md` | Output of `rank.py` |
| `_summary.md` | Index summary for the repo README |

## Original Prompt

> Research obsidian mcp plugins that are popular, highly rated, actively maintained, and have good code quality. Good semantic search is a definite advantage. I want to build an architecture for agents based on https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
>
> Try different angles to find plugins, be broad when trying to locate candidates. Rank them based on my priorities and requirements.
