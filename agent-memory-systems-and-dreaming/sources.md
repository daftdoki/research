# Annotated sources

Access status matters here: this session's egress proxy allowed `github.com` and
`raw.githubusercontent.com` and blocked every scholarly host. Sources are tagged:

- **[read]** — fetched and read in full during this investigation.
- **[summary]** — only the search engine's summary of the source was available; the
  underlying document is on a blocked host. Treat numbers as unverified.

The sleep-time compute, ConvoMem, MINJA and Auto-Dreamer figures were re-queried from a
second angle in a later pass and the independent result sets agreed; two gained detail
that corrected the first reading (see `notes.md`). They remain **[summary]** — agreement
between two search summaries is not the same as reading the paper.

## The "dreaming" thread

| Source | Status | Why it matters |
|---|---|---|
| [OpenClaw — Dreaming](https://github.com/openclaw/openclaw/blob/main/docs/concepts/dreaming.md) | **[read]** | The only fully documented shipping dream cycle. Phases, weights, thresholds, config keys, safety caps. |
| [OpenClaw — Memory](https://github.com/openclaw/openclaw/blob/main/docs/concepts/memory.md) | **[read]** | The store the dream cycle operates on: `USER.md`, `MEMORY.md`, `memory/YYYY-MM-DD.md`, `DREAMS.md`. |
| [openclaw/openclaw issue #67363](https://github.com/openclaw/openclaw/issues/67363) | **[read]** | Deep phase promotes verbatim daily-log snippets without distillation. Closed as not planned. The best negative result I found. |
| [ptburkis/openclaw-memory-dreaming](https://github.com/ptburkis/openclaw-memory-dreaming) | **[read]** | Files-only dream cycle with explicit decay tiers. Argues "the agent IS the retrieval engine". |
| [Sleep-time Compute (Letta + UC Berkeley)](https://github.com/letta-ai/sleep-time-compute) | **[read]** repo / **[summary]** paper | arXiv 2504.13171. ~5x fewer test-time tokens; +13% GSM-Symbolic, +18% AIME; 2.5x cost cut when amortised across queries. |
| [Auto-Dreamer](https://arxiv.org/abs/2605.20616) | **[summary]** | Learned offline consolidator. +7 pts on ScienceWorld with a 12x smaller active memory bank; transfers to ALFWorld/WebArena. |
| [OpenAI — Dreaming](https://openai.com/index/chatgpt-memory-dreaming/) | **[summary]** | June 2026 background memory synthesis for ChatGPT. Widely quoted 41.5% -> 82.8% recall figure originates here; I could not load the page to verify it. |
| Claude Code "Auto Dream" | **[summary]** | Reported March 2026, four-phase offline consolidation, `/dream` manual trigger. No first-party documentation reachable; all coverage is third-party blogs. |

## Memory system architectures

| Source | Status | Why it matters |
|---|---|---|
| [HippoRAG / HippoRAG 2](https://github.com/OSU-NLP-Group/HippoRAG) | **[read]** | Hippocampal indexing → KG + personalised PageRank. The case where the neuroscience is load-bearing rather than decorative. |
| [Mem0](https://github.com/mem0ai/mem0) | **[read]** | Apr 2026 rewrite: single-pass ADD-only extraction, no UPDATE/DELETE. Self-reported LoCoMo 92.5, LongMemEval 94.4. |
| [Graphiti / Zep](https://github.com/getzep/graphiti) | **[read]** | Bi-temporal graph; facts get validity windows and are invalidated, not deleted; episodes retained as ground truth. |
| [A-MEM](https://github.com/agiresearch/A-mem) | **[read]** | Zettelkasten: note construction, automatic link generation, memory evolution on insert. |
| [MemOS](https://github.com/MemTensor/MemOS) | **[summary]** | Parametric / activation-KV / plaintext memory in a MemCube with scheduler, lifecycle, governance. Best HaluMem scores. |
| [Letta (formerly MemGPT)](https://github.com/letta-ai/letta) | **[read]** README | Stateful agents, memory blocks; docs host blocked. |
| [Generative Agents](https://github.com/joonspk-research/generative_agents) | **[read]** repo / **[summary]** mechanism | Memory stream, `recency + importance + relevance` (all weights 1), reflection at cumulative importance 150. Ancestor of every dream cycle shipping today. |
| [Effective context engineering for AI agents (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | **[summary]** | Compaction, structured note-taking, sub-agent context isolation. |

## Evaluation

| Source | Status | Why it matters |
|---|---|---|
| [HaluMem](https://github.com/MemTensor/HaluMem) | **[read]** | arXiv 2511.03506. Operation-level hallucination eval — extraction, update, QA measured separately. Full results tables read from the repo. |
| [ConvoMem](https://arxiv.org/abs/2511.10523) | **[summary]** | "Why your first 150 conversations don't need RAG." The strongest argument against building a memory system too early. |
| [LongMemEval](https://github.com/xiaowu0162/LongMemEval) | **[read]** | 500 instances across information extraction, multi-session reasoning, knowledge updates, temporal reasoning, abstention. `_S` ≈ 40 sessions/115k tokens; `_M` ≈ 500 sessions. |
| LoCoMo | **[summary]** | ACL 2024. Very long-term conversation benchmark; the most commonly quoted vendor number. |

## Security

| Source | Status | Why it matters |
|---|---|---|
| [MINJA](https://arxiv.org/abs/2503.03704) | **[summary]** | NeurIPS 2025. Query-only memory injection, no privileged access, >95% success. Makes provenance gating a security control, not hygiene. |
| AgentPoison | **[summary]** | Earlier attack assuming direct store access; MINJA is the weaker-attacker, stronger-result version. |

## Neuroscience background

| Source | Status | Why it matters |
|---|---|---|
| McClelland, McNaughton & O'Reilly (1995), *Why there are complementary learning systems in the hippocampus and neocortex* | **[summary]** | The origin of the fast/slow two-system argument the whole "dreaming" metaphor rests on. |
| Generative replay / corticohippocampal continual learning | **[summary]** | Where the replay analogy genuinely applies: systems that update weights. |

## Curated lists consulted (as pointers, not evidence)

- [tfatykhov/awesome-agent-memory](https://github.com/tfatykhov/awesome-agent-memory) — 18-section taxonomy with an explicit "Forgetting & Consolidation" section. **[read]**
- [TsinghuaC3I/Awesome-Memory-for-Agents](https://github.com/TsinghuaC3I/Awesome-Memory-for-Agents) — systems-heavy, includes runnable notebooks. **[read]**
- [Shichun-Liu/Agent-Memory-Paper-List](https://github.com/Shichun-Liu/Agent-Memory-Paper-List) — forms × functions × dynamics taxonomy. **[read]**
- [Snseam/awesome-agent-memory](https://github.com/Snseam/awesome-agent-memory) — 989 papers, but the maintainer states 988 are unread stubs, some LLM-drafted. **[read]**
- [github.com/topics/memory-consolidation](https://github.com/topics/memory-consolidation) — ~20 small projects, most under 25 stars. Useful as a census of how many people are building this. **[read]**
