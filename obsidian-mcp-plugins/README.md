# Obsidian MCP servers, and a design for a shared LLM wiki for many agents

## Question / Goal

Which Obsidian MCP plugins and servers are popular, well rated, actively maintained and well engineered, with good semantic search as a plus? Which of them best support an agent that runs [Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)? See the [Original Prompt](#original-prompt).

In that pattern an agent ingests immutable raw sources into an LLM-owned, interlinked markdown wiki. Obsidian is the viewer. The work follows three operations:

- **Ingest:** about 10–15 page edits per source, plus updates to `index.md` and `log.md`.
- **Query:** search the wiki, then synthesise an answer and file it back as a page.
- **Lint:** find orphans, missing cross-links, contradictions and stale claims.

This report has two parts:

- **Part 1:** which Obsidian MCP servers and plugins are worth using for that pattern.
- **Part 2** (a follow-up request): how to build our own LLM wiki, using Karpathy as inspiration only. It must:
  - serve many agents and many git projects;
  - share cross-cutting topics, such as coding notes split by language or tool, and stay general enough for any subject, the way Wikipedia is;
  - cover agent **working memory** as well as long-term knowledge;
  - carry semantics for verification, sources, accuracy and freshness;
  - be centralized, reachable over the network, and have a human interface.

  OKF and the memoryfield format used by [iirc](https://github.com/daftdoki/dokidlc-iirc) were inputs, and other formats were on the table.

## Answer / Summary

### Part 2: a shared LLM wiki for many agents (full design in [`llm-wiki-design/DESIGN.md`](llm-wiki-design/DESIGN.md))

No single product covers the brief today. The design has seven parts.

**1. Storage**
- Markdown in git is the source of truth, with **one repo per space**: `commons`, `private`, `project-<slug>` and `agent-<id>`. Read permission is enforced per repo.
- Search indexes, link graphs, `index.md`, `log.md` and topic hubs are all generated and can be rebuilt.

**2. Page format: an OKF v0.2 profile.** OKF is Google Cloud's [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format) (Apache-2.0, about 1.2k★). Six tools already read or write it, ai-memory and markdown-vault-mcp among them.
- It provides claim-level `[^id]` footnote citations, a derived trust tier, `status` and `stale_after`, and Karpathy's `index.md`/`log.md` as reserved names.
- The profile adds memoryfield's `uuid`, iirc's `file@sha` and `check` evidence fields, and Wikipedia/Wikidata freshness ideas.
- Two key collisions are resolved: `status` (OKF's lifecycle) versus `conditions` (memoryfield's list), and the format of `verified`. OKF's popularity signal `usage_count` is ignored for trust.
- There is a JSON Schema plus a validator. Six example pages pass it, including non-technical ones, and a bad page fails it in five ways.

**3. Organization:** following Wikipedia.
- **Flat pages.** Wikipedia gave up subpage hierarchies because "articles tend to belong in more than one hierarchy".
- **Typed SKOS topic pages** (`python`, `uv`, `bread-baking`, `history-of-computing`) with `broader` and `narrower` links. A page tags only its most specific topic, and hubs roll pages up the chain.
- This is how coding notes are "split by language or tool" without folders, and it works the same way for any domain.

**4. Trust comes from evidence, never popularity**
- Each claim cites a source pinned by hash and quote, and a **different** agent checks that the source supports the claim.
- Any edit clears verification.
- A page goes suspect when a source drifts, a link rots, a `file@sha` changes, a `check` fails, or a release falls outside `applies_to`. Age alone never makes a page suspect.
- Sources are rated T1–T4 in a human-owned registry, and the wiki itself is T4, so it can never be a source for its own claims.
- Contradictions are kept as Wikidata-style ranked values, with a talk page. They are never resolved automatically.

**5. Publishing**
- Each agent has its own git identity.
- Edits use `If-Match`. New shared pages and new topics go through a draft queue.
- Sessions that read untrusted input write to pending branches.
- Disputes go on talk pages.
- One librarian bot holds the bulk rights, under a written list of approved tasks.
- Humans review through Forgejo pull requests, and browse and edit in Obsidian or a web UI.

**6. Retrieval**
- **Pull:** eight `wiki_*` MCP tools, with a trust and freshness envelope on every result, and hybrid search with contextual chunks and a reranker.
- **Push:** a strict hook that suggests at most 3 pages per prompt, tuned by replaying real prompts. iirc's own data shows most prompts have no relevant page.
- **Working memory:** `tasks/<id>/` folders (plan, progress, notes for each agent, a shared board, a handoff) with a TTL. Notes reach the wiki only through an explicit, sourced `wiki_propose`.

**7. Platform**
- **Recommended target, assembled:** Forgejo, plus obsidian-hybrid-search, plus Obsidian or Hatchdoor for humans, plus a thin **wiki gateway we write**. The gateway handles identity, routing to spaces, the write gate and the generated files.
- **Turnkey alternatives for a two-week pilot:**
  - **ai-memory** (MIT, OKF-native, but its web UI is read-only);
  - **KiwiFS** (BSL, the best integrated UI).

  Both use OKF pages, so the content carries over to the assembled build.
- The roadmap is six phases, and Phase 0 is useful within days: a schema-checked git repo that agents edit on a clone.

### Part 1: Obsidian MCP servers

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

### Part 2 (design)

1. **Built on earlier reports instead of repeating them:** [multi-agent-shared-wiki](../multi-agent-shared-wiki/README.md) (scopes, harness hooks, ai-memory, KiwiFS, SilverBullet) and [agent-memory-systems-and-dreaming](../agent-memory-systems-and-dreaming/README.md) (consolidation, update correctness, poisoning). Also read iirc's README and `docs/HOW-IT-WORKS.md`, and this repo's own `.memory/` pages as live examples of the format.
2. **Ran five research tracks in parallel,** each reading primary sources through `gh api` and the web (nothing was installed):
   - **Formats:** OKF, memoryfield/iirc, and about 12 others.
   - **Verification and freshness:** Wikipedia policies, the Wikidata statement model, PROV-O, W3C annotations, FActScore/SAFE/VeriScore/ALCE, and poisoning defences.
   - **Organization and publishing:** MediaWiki namespaces and categories, SKOS, Diátaxis, PARA, Johnny.Decimal, bot policies, and Letta and Managed Agents memory.
   - **Retrieval and working memory:** Anthropic's engineering posts, Contextual Retrieval, Cursor, Tool Search, iirc's search-quality data, Letta, the memory tool and Codex memories.
   - **Platforms:** about 30 servers and UIs, with fresh repo metrics.
3. **Checked the load-bearing claims myself:**
   - OKF spec version, licence and repo metrics, and its `usage_count` signal (§5.1).
   - ai-memory's web UI is read-only ("The web UI is read-only" in `docs/usage.md`).
   - SilverBullet's MCP issue #1479 is closed.
   - gosidian, KiwiFS, Hatchdoor, vouch and SilverBullet community MCP metrics.
4. **Wrote a JSON Schema for the page profile** and [`validate_pages.py`](llm-wiki-design/validate_pages.py), which also checks that every `[^id]` footnote resolves. Ran it with `uv run --no-project --with jsonschema --with pyyaml` on six example pages (all pass) and one deliberately bad page (fails on all five planted errors). The first run caught a schema bug: a 3-character minimum on titles rejected the topic page "uv".

### Part 1 (Obsidian MCP servers)

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

### Part 2: formats compared

| | OKF v0.2 | memoryfield v0.3 / iirc | OpenClaw memory-wiki | Basic Memory | Vault-LD |
|---|---|---|---|---|---|
| Plain markdown + git | ✓ | ✓ | ✓ | ✓ | ✓ |
| Typed pages | `type` (free text) | iirc `kind` (4 values) | `pageType` | `type` | `rdf:type` |
| Claim-level provenance | **`[^id]` → `sources[].id`** | page-level `refs` | `claims[].evidence` | `(context)` text | – |
| Trust | derived tier from `verified[]` | iirc: suspect on evidence | claim `status`, `confidence` | – | – |
| Freshness | `stale_after`, `generated.at` | **`file@sha` + `check`**, kind-based glance age | `lastRefreshedAt` | timestamps | – |
| Stable ID / scope | path only | **`uuid`**; iirc stores | `canonicalId` | `permalink` | IRIs |
| Adoption | **highest** (ai-memory, markdown-vault-mcp, llm-wiki-compiler, obsidian-wiki, OpenClaw import, Basic Memory sources) | iirc + spec author | one product | one product | small |

The design layers OKF (envelope and provenance), memoryfield (identity, size budget, doubt vocabulary) and iirc (evidence-driven staleness), plus Wikipedia/Wikidata ideas (source tiers, `as_of`, ranked statements). The field-by-field origins are in [DESIGN.md §4](llm-wiki-design/DESIGN.md#4-page-format-an-okf-profile).

### Part 2: platforms for the central server and human UI

| Platform | Licence | md + git | Spaces / per-agent auth | MCP | Write concurrency | Human UI | Fit |
|---|---|---|---|---|---|---|---|
| [ai-memory](https://github.com/akitaonrails/ai-memory) v3.3 | MIT | ✓ (one git author) | ✓ projects, `_global`, accounts, keys | ✓ + hooks for ~40 harnesses | single writer | **read-only** web: tree, search, graph, history diffs | turnkey; capture-first |
| [KiwiFS](https://github.com/kiwifs/kiwifs) | BSL 1.1 | ✓ commit per write | ✓ spaces, scoped tokens, OIDC | 62 tools, HTTP | ETag/`If-Match`, drafts | editor, graph, backlinks, content health | best integrated product |
| [Hatchdoor](https://github.com/BatterWorks/Hatchdoor) | AGPL-3.0 | ✓ git per vault | multi-vault, one user | HTTP | optimistic | **best web UI** (Obsidian-like, graph, Bases) | human UI layer |
| [Forgejo](https://codeberg.org/forgejo/forgejo) / [gitea-mcp](https://gitea.com/gitea/gitea-mcp) | MIT/GPL | ✓ | ✓ user per agent, teams | ✓ OAuth 2.1 | file `sha` | **PR diffs and review**, history | review layer |
| [markdown-vault-mcp](https://github.com/pvliesdonk/markdown-vault-mcp) | MIT | ✓ commit per write | one vault per server; OIDC | ✓ OKF tools | etag | MCP Apps views only | per-space engine |
| [gosidian](https://github.com/daniele-chiappa/gosidian) | MIT | optional git sync | ✓ projects, grants, OAuth 2.1 | 71 tools | not stated | editor, graph, audit | fork candidate (3★) |
| [SilverBullet](https://github.com/silverbulletmd/silverbullet) | MIT | ✓ (batched commits) | spaces, accounts | **no official MCP** (#1479 closed) | `If-Match` | good editor | UI only |

Ruled out as the central server: Wiki.js 3 (beta; database is the source of truth), BookStack, Outline and Docmost (database-backed), Trilium, AFFiNE, Logseq DB (alpha sync), Gollum (stale), and the personal or local-only Karpathy tools (llm-wiki-compiler, swarmvault, Molio). Details are in DESIGN.md §10 and in [notes](notes.md).

### Part 1: Ranking (default weights, data as of 2026-10-31)

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

### Part 2

- **The format choice matters more than the platform choice.** Every serious platform keeps markdown in git, and OKF is the one format several of them already share. Writing an OKF profile from day one makes ai-memory, KiwiFS, markdown-vault-mcp or our own gateway interchangeable later, and a two-week pilot becomes cheap.
- **The gaps cluster in one thin layer.** Every turnkey option is missing per-agent identity mapped to git authors, routing to spaces, a write gate that enforces sourcing, or working-memory tools. That layer is small enough to write: the gateway in DESIGN.md §8.4.
- **Wikipedia's process is the best available guide for many writers.** It covers flat namespaces, most-specific categories, verifiability, perennial sources, drafts, pending changes, talk pages and bot approval. The agent research supplies what Wikipedia doesn't need: independent entailment checks (citations are often attached after the text was written), and structural defences against poisoning, because agreement between agents can be forged.
- **Caveats:**
  - The design's thresholds and tiers are proposals, not measurements.
  - OKF is v0.x with one maintainer.
  - Several platform details are marked unverified in DESIGN.md §13.

### Part 1

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
  - **istefox embedding backends:** GPU is used only through WebGPU, chosen automatically. There is no CUDA, no native ONNX runtime and no device setting. EmbeddingGemma is forced onto the CPU because its WebGPU vectors were wrong. Headless mode is CPU only. There is no API embedding provider (no OpenAI, Ollama or other endpoint setting). If you need GPU or API embeddings, put obsidian-hybrid-search (any OpenAI-compatible endpoint, including Ollama or LM Studio) beside it as the search layer.
  - Known issues to watch: the istefox EmbeddingGemma full rebuild can block the UI for hours (#664), so use MiniLM. TurboVault's vector plugin is 0.x and opt-in (`--plugins`). In TurboVault plain-folder mode, `move_note` does not rewrite links unless you pass `update_backlinks=true`.

## Files

| File | Purpose |
|---|---|
| `README.md` | This report |
| `llm-wiki-design/DESIGN.md` | Part 2: the full design. Requirements, architecture, storage, format, organization, verification, publishing, retrieval, working memory, platform options, roadmap, iirc, risks, and 41 numbered sources |
| `llm-wiki-design/schema/wiki-page.schema.json` | JSON Schema (2020-12) for page frontmatter: the OKF v0.2 profile plus memoryfield/iirc fields and this design's additions |
| `llm-wiki-design/validate_pages.py` | Validates pages against the schema and checks that footnotes resolve (`uv run --no-project --with jsonschema --with pyyaml python validate_pages.py examples/*.md`) |
| `llm-wiki-design/examples/` | Six valid example pages (entity, recipe, topic hub, coding finding, source, working note) and `invalid/` with one page the write gate must refuse |
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

### Follow-up prompts

> Can mcp connector use a GPU for the embedding or an API?

> Expand this research to include more about how we might build an LLM wiki for our usage. It should support multiple agents, multiple git projects, and allow for cross functional topics like coding wiki notes shared by all agents that might be split up by language or tool. Don’t limit it to these topics though, it should be generalizable for all types of information including non-technical just like real Wikipedia isn’t limited. For format and structure I’ve found things like OKF - open knowledge format, and we’re already using memory notes format in our daftdoki/dokidlc-iirc memory plug in. Working memory for an agent is another use case I’m interested in in addition to long term knowledge management and creation. Semantics that help deal with verifying information, sources, accuracy, and freshness are also important. You will also need to research and consider how agents will use this information effectively for retrieval, search, publishing, and organization. Since it will be centralized it should be network accessible and also have a human interface.  Karpathy’s LLM wiki serves as my original inspiration, but we don’t have to strictly adhere to it. Off the shelf, open source projects, and building our own are all options including any combination of those to assemble a working system.

> Other formats are also on the table if your research leads you to others that make more sense.
