# Annotated sources

Access status matters here, because this report was researched across three sessions
with different egress policies. The first two could reach only `github.com` and
`raw.githubusercontent.com`; the third could reach arXiv, Anthropic's docs, Nature,
ACL Anthology and Letta's docs. Sources are tagged:

- **[read]** — fetched and read in full.
- **[partial]** — the source was reached and its prose read, but some content
  (chart images) could not be extracted.
- **[summary]** — the document itself could not be retrieved; only search-engine
  summaries were available. Treat numbers as unverified.

**As of the third pass, two entries remain below [read].** Everything else has been
read against the primary source, and four claims that survived two passes of
search-summary cross-checking turned out to be wrong when the primary source was
opened. Those corrections are documented in [notes.md](notes.md#third-pass-the-primary-sources-actually-read)
and summarised in the README's
[verification discipline](README.md#verification-discipline-and-what-it-caught) section.

## The "dreaming" thread

| Source | Status | Why it matters |
|---|---|---|
| [OpenClaw — Dreaming](https://github.com/openclaw/openclaw/blob/main/docs/concepts/dreaming.md) | **[read]** | The only *scheduled* dream cycle documented in full. Phases, weights, thresholds, config keys, safety caps. |
| [OpenClaw — Memory](https://github.com/openclaw/openclaw/blob/main/docs/concepts/memory.md) | **[read]** | The store the dream cycle operates on: `USER.md`, `MEMORY.md`, `memory/YYYY-MM-DD.md`, `DREAMS.md`. |
| [openclaw/openclaw issue #67363](https://github.com/openclaw/openclaw/issues/67363) | **[read]** | Deep phase promotes verbatim daily-log snippets without distillation. Closed as not planned. The best negative result found. |
| [ptburkis/openclaw-memory-dreaming](https://github.com/ptburkis/openclaw-memory-dreaming) | **[read]** | Files-only dream cycle with explicit decay tiers. Argues "the agent IS the retrieval engine". |
| [Anthropic — Managed Agents: Dreams](https://platform.claude.com/docs/en/managed-agents/dreams) | **[read]** | First-party consolidation API. Research preview behind the `dreaming-2026-04-21` beta header. On-demand async job; 1 store + 1–100 sessions in, a **new** store out; input never modified; live `usage` token accounting; 4,096-char `instructions`; 100 sessions/dream cap. |
| [Anthropic — Managed Agents: Memory stores](https://platform.claude.com/docs/en/managed-agents/memory) | **[read]** | The store Dreams operates on. Immutable memory versions, session-attributed writes, 30-day version retention, `redact` endpoint, 10,000-memory cap per store, no restore endpoint. |
| [Anthropic — Claude Code: How Claude remembers your project](https://docs.claude.com/en/docs/claude-code/memory) | **[read]** | Settles the "Claude Code Auto Dream" question: there is no such feature. Claude Code has **Auto memory** — online, four note types, `MEMORY.md` index capped at 200 lines / 25KB, harness-enforced compaction. The word "dream" does not appear. |
| [Letta — Memory and dreaming](https://docs.letta.com/agent-sdk/memory/index.md) | **[read]** | Fourth shipping dream cycle. Background subagents over git-backed MemFS; `trigger` is `off` / `step-count` / `compaction-event`; `behavior` is `reminder` / `auto-launch`; optional "agent reviews before applying" second pass. |
| [Letta — Memory configuration](https://docs.letta.com/configuration/memory/index.md) | **[read]** | The `/sleeptime` CLI surface, and the separate "reorganize memory" workflow that backs up the repository before restructuring. |
| [Sleep-time Compute (Letta + UC Berkeley)](https://arxiv.org/abs/2504.13171) | **[read]** paper and [repo](https://github.com/letta-ai/sleep-time-compute) | ~5x fewer test-time tokens on Stateful GSM-Symbolic *and* Stateful AIME; +13% / +18% accuracy; 2.5x cost cut **at 10 queries per context**. SWE-Features case study: ~1.5x, and only at low test-time budgets. |
| [Auto-Dreamer](https://arxiv.org/abs/2605.20616) | **[read]** | Ye, Liu et al. (UIUC / UCSD), 20 May 2026. Learned offline consolidator trained with GRPO. ScienceWorld 41.1% vs UMEM 34.1%; 12x / 6x smaller banks. Appendix H bootstrap CIs show only the ScienceWorld gain clears noise. Appendix I independently replicates the issue #67363 failure mode. |
| [OpenAI — Dreaming: Better memory for a more helpful ChatGPT](https://openai.com/index/chatgpt-memory-dreaming/) | **[partial]** | June 4, 2026. Prose read via headless Chromium; the evaluation charts are images and their values could not be extracted. Confirms Dreaming V0 shipped **April 2025**, V3 is the 2026 release, and ~5x less compute *to serve* Free users. **Contains no percentages in text** — the circulating 41.5% → 82.8% figure is a third-party reading of a chart image. |

## Memory system architectures

| Source | Status | Why it matters |
|---|---|---|
| [HippoRAG / HippoRAG 2](https://github.com/OSU-NLP-Group/HippoRAG) | **[read]** | Hippocampal indexing → KG + personalised PageRank. The case where the neuroscience is load-bearing rather than decorative. |
| [Mem0](https://github.com/mem0ai/mem0) | **[read]** | Apr 2026 rewrite: single-pass ADD-only extraction, no UPDATE/DELETE. Self-reported LoCoMo 92.5, LongMemEval 94.4. |
| [Graphiti / Zep](https://github.com/getzep/graphiti) | **[read]** | Bi-temporal graph; facts get validity windows and are invalidated, not deleted; episodes retained as ground truth. |
| [A-MEM](https://github.com/agiresearch/A-mem) | **[read]** | Zettelkasten: note construction, automatic link generation, memory evolution on insert. |
| [MemOS](https://arxiv.org/abs/2507.03724) | **[read]** paper and [repo](https://github.com/MemTensor/MemOS) | Parametric / activation-KV / plaintext memory in a MemCube that "encapsulates both memory content and metadata such as provenance and versioning", with a scheduler, a generation→activation→fusion→disposal lifecycle, and multi-level permission control. Best HaluMem scores. |
| [Letta (formerly MemGPT)](https://github.com/letta-ai/letta) | **[read]** repo and [docs](https://docs.letta.com/) | Stateful agents, memory blocks, MemFS, sleep-time subagents. |
| [Generative Agents](https://arxiv.org/abs/2304.03442) | **[read]** paper and [repo](https://github.com/joonspk-research/generative_agents) | Memory stream; `recency + importance + relevance` with **all α weights set to 1**; recency is exponential decay with **factor 0.995**; reflection fires when summed importance of recent events exceeds **150**, "roughly two or three times a day". Ancestor of every dream cycle shipping today. |
| [Effective context engineering for AI agents (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | **[read]** | Compaction, structured note-taking, sub-agent context isolation. Subagents "return only a condensed, distilled summary of their work (often 1,000-2,000 tokens)". Recommends tuning compaction prompts for recall first, then precision. |

## Evaluation

| Source | Status | Why it matters |
|---|---|---|
| [HaluMem](https://github.com/MemTensor/HaluMem) | **[read]** | arXiv 2511.03506. Operation-level hallucination eval — extraction, update, QA measured separately. Full results tables read from the repo. |
| [ConvoMem](https://arxiv.org/abs/2511.10523) | **[read]** | Pakhomov, Nijkamp, Xiong (Salesforce AI Research), 13 Nov 2025. "Why your first 150 conversations don't need RAG." 75,336 QA pairs, six categories, evidence across 1–6 messages, 2–300 conversations. The strongest argument against building a memory system too early — but note the paper's own abstract (150) and body (50–100) give different thresholds, and Mem0 is up to 95x cheaper. |
| [LongMemEval](https://github.com/xiaowu0162/LongMemEval) | **[read]** | 500 instances across information extraction, multi-session reasoning, knowledge updates, temporal reasoning, abstention. `_S` ≈ 40 sessions/115k tokens; `_M` ≈ 500 sessions. ConvoMem criticises it for statistical power: some subgroups have 6 questions, ±40% margin of error. |
| [LoCoMo](https://arxiv.org/abs/2402.17753) | **[read]** | Maharana, Lee, Tulyakov, Bansal, Barbieri, Fang (UNC / USC / Snap), ACL 2024. **50 conversations**, avg 304.9 turns, 19.3 sessions, **9,209 tokens**; 7,512 questions. The most commonly quoted vendor number, measured on conversations that fit in a modern context window hundreds of times over. |

## Security

| Source | Status | Why it matters |
|---|---|---|
| [MINJA](https://arxiv.org/abs/2503.03704) | **[read]** | Dong, Xu et al. (MSU / UGA / SMU), NeurIPS 2025. Query-only memory injection, no privileged access. **98.2% injection success, 76.8% attack success.** §5.4 shows embedding-level sanitization fails and prompt-level detection does not generalise (131/135 on one agent, 0 on two others). Makes provenance gating a security control, not hygiene. |
| [AgentPoison](https://arxiv.org/abs/2407.12784) | **[read]** | Chen, Xiang, Xiao, Song, Li (UChicago / UIUC / Wisconsin / Berkeley), NeurIPS 2024. Assumes direct store access: **≥80% attack success at <0.1% poison rate with ≤1% benign impact**. MINJA reaches comparable attack success from a far weaker threat model — the escalation is in the assumptions, not the numbers. |

## Neuroscience background

| Source | Status | Why it matters |
|---|---|---|
| McClelland, McNaughton & O'Reilly (1995), *Why there are complementary learning systems in the hippocampus and neocortex*, Psychological Review 102, 419–457 | **[summary]** | The origin of the fast/slow two-system argument the whole "dreaming" metaphor rests on. **Still not read**: `stanford.edu` redirects then 403s, `cnbc.cmu.edu` has a broken certificate chain, ResearchGate requires login, DTIC 403s. Nothing in this report cites a figure from it. |
| [Brain-inspired replay for continual learning with artificial neural networks](https://www.nature.com/articles/s41467-020-17866-2) | **[read]** | van de Ven, Siegelmann & Tolias, *Nature Communications* 2020. Where the replay analogy genuinely applies: generative replay exists to "prevent catastrophic forgetting" during **weight updates**. A retrieval store has no weights and therefore no such problem. |
| Auto-Dreamer §1, on CLS | **[read]** | The honest statement of the metaphor, from people building on it: "We adopt CLS not as a biological claim about language models, but as an operational design principle for separating fast acquisition from slow cross-session consolidation." |

## Curated lists consulted (as pointers, not evidence)

- [tfatykhov/awesome-agent-memory](https://github.com/tfatykhov/awesome-agent-memory) — 18-section taxonomy with an explicit "Forgetting & Consolidation" section. **[read]**
- [TsinghuaC3I/Awesome-Memory-for-Agents](https://github.com/TsinghuaC3I/Awesome-Memory-for-Agents) — systems-heavy, includes runnable notebooks. **[read]**
- [Shichun-Liu/Agent-Memory-Paper-List](https://github.com/Shichun-Liu/Agent-Memory-Paper-List) — forms × functions × dynamics taxonomy. **[read]**
- [Snseam/awesome-agent-memory](https://github.com/Snseam/awesome-agent-memory) — 989 papers, but the maintainer states 988 are unread stubs, some LLM-drafted. **[read]**
- [github.com/topics/memory-consolidation](https://github.com/topics/memory-consolidation) — ~20 small projects, most under 25 stars. Useful as a census of how many people are building this. **[read]**
