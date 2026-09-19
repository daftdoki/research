# Research notes: agent memory systems & "dreaming" consolidation

## Goal

The creator is building a small memory system for agents. They've heard news
about "dreaming" applied to AI memory and want a survey of approaches plus
research they can use to evaluate designs for their own system.

## Plan

1. Map the landscape of agent memory systems (open-source frameworks + papers).
2. Chase the "dreaming" / sleep-time-compute / offline-consolidation thread
   specifically — what is actually new vs. rebranded batch summarization.
3. Pull the neuroscience analogy honestly (complementary learning systems,
   replay, SWS/REM) and note where it breaks.
4. Find benchmarks/evals that can be used to compare approaches.
5. Build a decision framework + recommendations for a small system.

## Log

### Constraint discovered early: egress allowlist

Tried to fetch primary sources directly. The session's egress proxy blocks
almost everything scholarly:

| Host | Result |
|---|---|
| `arxiv.org` | EGRESS_BLOCKED |
| `www.alphaxiv.org` | EGRESS_BLOCKED |
| `aclanthology.org` | EGRESS_BLOCKED |
| `openreview.net` | EGRESS_BLOCKED |
| `huggingface.co` | EGRESS_BLOCKED |
| `pmc.ncbi.nlm.nih.gov` | EGRESS_BLOCKED |
| `docs.letta.com` | EGRESS_BLOCKED |
| `www.anthropic.com` | EGRESS_BLOCKED |
| `www.turingpost.com` | EGRESS_BLOCKED |
| `github.com` | OK |
| `raw.githubusercontent.com` | OK |

`/root/.ccr/README.md` says a 403/407 from the proxy is an org egress policy
decision and must be reported, not routed around. So: primary reading is done
against GitHub (repos, READMEs, docs folders, awesome-list paper collections)
plus the `WebSearch` tool's own result summaries. Every claim below is tagged
with how it was sourced. Claims that rest only on a search-result summary are
marked **[search-summary]** and should be re-verified against the paper PDF
from a machine with open egress.

## Landscape mapping (what I found and where)

### Sources that actually loaded

- `github.com/openclaw/openclaw` docs (`docs/concepts/memory.md`, `docs/concepts/dreaming.md`) — real, readable spec of a shipping dream-cycle.
- `github.com/openclaw/openclaw/issues/67363` — a *failure report* against that dream cycle. Gold: shows what breaks.
- `raw.githubusercontent.com/OSU-NLP-Group/HippoRAG` — neuroscience-grounded retrieval.
- `raw.githubusercontent.com/mem0ai/mem0` — extraction/update pipeline + vendor benchmark table.
- `raw.githubusercontent.com/getzep/graphiti` — bi-temporal knowledge graph.
- `raw.githubusercontent.com/agiresearch/A-mem` — Zettelkasten-style linking/evolution.
- `github.com/letta-ai/sleep-time-compute` — code repo; numbers live in the (blocked) paper.
- Awesome lists: `tfatykhov/awesome-agent-memory` (18-section taxonomy, has an explicit
  "Forgetting & Consolidation" section), `TsinghuaC3I/Awesome-Memory-for-Agents`,
  `Shichun-Liu/Agent-Memory-Paper-List`, `Snseam/awesome-agent-memory`.

### Caveat about the awesome lists

`Snseam/awesome-agent-memory` is refreshingly honest about its own weakness: 988 of its
989 papers are "paper stubs ... not yet fully read", some stubs were "accelerated with
LLM tooling", and vendor claims are deliberately quarantined from independent
reproductions. I'm treating all awesome-list rows as *pointers*, not evidence. The
2026-dated entries in particular are mostly preprints with no independent replication.

### First real finding: the "dreaming" story is three different things

1. **Product feature** — OpenClaw Dreaming, Claude Code Auto Dream, ChatGPT "Dreaming V3".
   These are batch maintenance passes over a memory store. [search-summary for the two
   closed-source ones; OpenClaw's is documented in-repo]
2. **Inference-scaling technique** — Letta/UC Berkeley "sleep-time compute": pre-compute
   reasoning over context *before* the query arrives.
3. **Neuroscience metaphor** — replay/consolidation from complementary learning systems.
   Load-bearing for HippoRAG; decorative for most of the rest.

These get conflated constantly in the blog coverage. Worth separating in the report.

## Evidence gathered, with confidence tags

### Sleep-time compute (Letta + UC Berkeley, Apr 2025, arXiv 2504.13171)

The one "dreaming-adjacent" result with clean numbers. **[search-summary]** — the repo
`letta-ai/sleep-time-compute` loaded but only holds code/data instructions, and the
paper itself is on the blocked host.

- ~5x fewer test-time tokens for equal accuracy on Stateful GSM-Symbolic.
- Scaling sleep-time compute further: up to **+13%** accuracy on Stateful GSM-Symbolic,
  up to **+18%** on Stateful AIME.
- Amortising one sleep-time pass across related queries about the same context
  (Multi-Query GSM-Symbolic): **2.5x** lower average cost per query.

Important: this is *not* memory consolidation. It's precomputing *reasoning* over a
context before the question arrives. The amortisation result is the load-bearing one —
it only pays when many queries hit the same context. If my reader's agent asks one
question per context, sleep-time compute is strictly wasted spend.

### Auto-Dreamer (May 2026, arXiv 2605.20616) **[search-summary]**

Learned offline consolidator; decouples fast per-session writes from slow cross-session
consolidation. Trained on ScienceWorld only: +7 points over fixed/RL-trained/prompted
memory baselines, with an active memory bank **12x smaller** than the strongest
baseline. Transfers to held-out ALFWorld and WebArena with no updates.

The 12x-smaller-bank number is the interesting one. Consolidation's measurable win in
this paper is *compression*, not recall.

### OpenClaw Dreaming — a shipping dream cycle, fully documented

Read directly from `openclaw/openclaw` `docs/concepts/dreaming.md` + `memory.md`.
Three phases per sweep, **light -> REM -> deep**:

- *light*: read short-term recall, daily files, transcripts; dedupe; stage candidates.
  No durable writes.
- *REM*: build theme/reflection summaries from recent traces; record reinforcement
  signals for deep ranking. No durable writes.
- *deep*: weighted scoring + threshold gates (`minScore`, `minRecallCount`,
  `minUniqueQueries`), rehydrate snippets from live files, model-based consolidation
  decides add/merge/supersede. Only phase that writes `MEMORY.md`; also emits `DREAMS.md`.

Deep ranking weights: relevance 0.30, frequency 0.24, query diversity 0.15,
recency 0.15, consolidation 0.10, conceptual richness 0.06.

Defaults: `0 3 * * *`, `maxPriorEntryLossFraction` 0.25, `maxPromotedSnippetTokens` 160,
enabled by default. Candidates with `untrusted` or `system` provenance are excluded
*before* consolidation. Existing annotated entries stay byte-for-byte unless explicitly
merged or superseded.

Three design ideas here are worth stealing regardless of whether you like the sleep
metaphor:
1. **Read/stage phases are separated from the write phase.** Only one phase mutates.
2. **A cap on destruction** (`maxPriorEntryLossFraction` 0.25) — a bad sweep can't
   nuke the store.
3. **Provenance gating before consolidation** — untrusted content never gets promoted.
   This is the direct mitigation for the MINJA-style attack below.

### The counter-example: OpenClaw issue #67363

Deep phase promoted **raw verbatim daily-log snippets** into `MEMORY.md` with no
distillation. Example promoted entry: "Started the day. 10:15 AM. Greeted the user."
Scores well on frequency and recency; worth nothing.

Root cause per the reporter: the scoring pipeline decides *whether* to promote but
nothing decides *how* to write. Closed as not planned.

This is the single most useful thing I found. A scoring gate is not a consolidation
step. Selection != synthesis. If you only build the gate, you get a curated pile of
noise instead of an uncurated pile of noise.

### HaluMem (arXiv 2511.03506) — operation-level hallucination eval

Read the results tables off `github.com/MemTensor/HaluMem`. First fetch garbled the
column headers (it read the omission-rate column as "QA accuracy" and produced the
nonsense result that Mem0 had 98.5% QA accuracy with 6% extraction F1). Re-fetched
asking for headers verbatim. **Lesson: always re-read a table that tells you something
implausible.** Corrected numbers:

Halu-Medium (20 users, 30,073 dialogues, ~160k tokens context, 14,948 memory points):

| System | Extraction F1 | Update Correct | QA Correct | QA Halluc. | QA Omission |
|---|---|---|---|---|---|
| MemOS | 79.70% | 62.11% | 67.23% | 15.17% | 17.59% |
| Mem0-Graph | 57.85% | 24.50% | 54.66% | 19.28% | 26.06% |
| Mem0 | 57.31% | 25.50% | 53.02% | 19.17% | 27.81% |
| Supermemory | 56.90% | 16.37% | 54.07% | 22.24% | 23.69% |
| Zep | n/a | 47.28% | 55.47% | 21.92% | 22.62% |
| Memobase | 25.13% | 5.20% | 35.33% | 29.97% | 34.71% |

Halu-Long (~1M tokens context, same memory points):

| System | Extraction F1 | Update Correct | QA Correct | QA Halluc. |
|---|---|---|---|---|
| MemOS | 82.11% | 65.25% | 64.44% | 16.61% |
| Supermemory | 65.54% | 17.01% | 53.77% | 22.21% |
| Zep | n/a | 37.35% | 50.19% | 22.51% |
| Memobase | 11.55% | 4.10% | 33.60% | 29.46% |
| Mem0-Graph | 4.36% | 1.47% | 32.44% | 21.82% |
| Mem0 | 6.22% | 1.45% | 28.11% | 17.29% |

Two things jump out:
- **Update is where everything falls over.** Best update-correct score is 65%; most
  systems are at 1-25%. Writing memories is solved-ish; *changing* them is not.
- **Mem0 collapses between Medium and Long** (57.3% -> 6.2% extraction F1). Whatever
  the cause, it means benchmark numbers do not transfer across corpus scale. Never
  trust a memory benchmark run at a different scale than your workload.

Compare to Mem0's own README table (LoCoMo 92.5, LongMemEval 94.4). Same system, wildly
different picture. Vendor self-eval vs independent operation-level eval.

### ConvoMem (arXiv 2511.10523) — the "do you even need this" result **[search-summary]**

- Full-context baselines hit 70-82% on the hardest multi-message-evidence cases;
  RAG-based memory systems (Mem0 among them) get 30-45% on histories under 150 convs.
- Evidence spread over 6 messages: long context ~80%, Mem0 ~25%.
- One hour/day for four weeks ≈ 100k tokens ≈ 10% of a 1M context window.
- Transition points: <30 convs long context unbeatable; <150 convs still best
  accuracy/cost; >300 convs long-context latency (~23s) forces RAG/hybrid.

This is the most decision-relevant finding in the whole investigation for someone
building a *small* memory system.

### Memory poisoning — MINJA (arXiv 2503.03704, NeurIPS 2025) **[search-summary]**

Query-only memory injection: the attacker is an ordinary user, no privileged access.
Bridging steps + indication prompt + progressive shortening. >95% injection success.
Contrast with AgentPoison, which assumes direct store access.

Consequence for consolidation: a dream cycle is an *amplifier*. It takes a transient
poisoned record and promotes it into durable, high-trust memory, then strips the
provenance that would have let you spot it. OpenClaw's provenance exclusion is the
right shape of defence.

### Neuroscience grounding, honestly stated **[search-summary]**

CLS theory (McClelland, McNaughton & O'Reilly 1995): fast-learning hippocampus +
slow-learning neocortex; hippocampal replay during sleep interleaves old and new
experience, which is what prevents catastrophic interference. The *reason* for two
systems is that the neocortex must learn slowly to avoid destroying prior structure.

Where the analogy breaks for LLM agents: nothing in a retrieval-based memory system
does gradient updates. There is no catastrophic interference to prevent, because there
is no weight-level learning happening at all. The problem CLS solves is not the problem
a markdown memory file has. The metaphor is a *scheduling* analogy (do expensive work
offline), not a mechanistic one.

Systems where the analogy is load-bearing rather than decorative: HippoRAG
(hippocampal indexing theory -> knowledge graph + personalised PageRank over it), and
genuine generative-replay continual-learning work, which does touch weights.

### Other architecture families worth naming

- **Generative Agents** (2023): memory stream + retrieval score
  `recency + importance + relevance`, all weights 1; importance is an LLM-assigned
  1-10 score; recency is exponential decay since last access. Reflection fires when
  the sum of importance for recent events crosses **150**, ~2-3x/day. **[search-summary]**
  This is the ancestor of every "dream cycle" shipping today.
- **HippoRAG / HippoRAG 2**: KG + personalised PageRank; claims cheaper offline
  indexing than GraphRAG/RAPTOR/LightRAG. Benchmarks in README as a figure only.
- **Graphiti / Zep**: bi-temporal KG. Facts get validity windows and are *invalidated,
  not deleted*. Episodes are retained as ground truth so every fact is traceable.
  Directly addresses the update-correctness hole HaluMem exposes.
- **A-MEM**: Zettelkasten — note construction (context + tags + keywords), automatic
  link generation, memory evolution that rewrites neighbours' metadata on insert.
- **MemOS**: three memory types (parametric / activation-KV / plaintext) in a
  "MemCube" with scheduling, versioning, access control. Best HaluMem scores.
- **Mem0 (Apr 2026 rewrite)**: single-pass ADD-only extraction, *no UPDATE/DELETE* —
  memories accumulate, nothing is overwritten; entity linking; semantic+BM25+entity
  fusion. Interesting: they moved *away* from in-line updating.
- **Anthropic context engineering**: compaction, structured note-taking, sub-agent
  context isolation (subagent burns 10k+ tokens, returns 1-2k). **[search-summary]**
- **ptburkis/openclaw-memory-dreaming**: files-only, no vector DB. 5-step nightly cycle
  (decay, review, integrate, prune, supersede) + 5 decay tiers (crystallised at 20+
  recalls never decays; hot 1.0 / warm 0.6 / cold 0.3 / archived <0.1). Structural
  entries (IPs, URLs, credentials) hold a 0.3 floor. Argument: "the agent IS the
  retrieval engine".

## Dead ends / things that didn't work

- Direct paper reading. Every scholarly host is blocked (see table at top). Spent the
  first ~15 minutes probing hosts before accepting the constraint.
- `Snseam/awesome-agent-memory` promised "989 papers, 529 archived PDFs" and
  "deep notes mapped to memory-kernel modules". The README turned out to be mostly
  process description; the maintainer openly says 988 of the 989 are unread stubs,
  some LLM-drafted. Not usable as evidence.
- `Shichun-Liu/Agent-Memory-Paper-List` has no consolidation/sleep section at all,
  despite backing a survey titled "Memory in the Age of AI Agents". Its axes are
  forms (token/parametric/latent) x functions (factual/experiential/working) x
  dynamics (formation/evolution/retrieval). Useful taxonomy, no dream content.
- `joonspk-research/generative_agents` README is setup instructions only; had to get
  the reflection threshold from search rather than source.
- The 2026-dated consolidation papers in `tfatykhov/awesome-agent-memory`
  (SleepGate, SCM, FSFM, CraniMem, TEPA, ...) are a long list of preprints I could not
  read and could not verify. Listing them as "here is who is working on this" is fair;
  citing their claims is not. Left them out of the report's evidence sections.

## Open questions I could not close

1. Is there *any* independent, apples-to-apples ablation showing an offline
   consolidation pass beats a same-token-budget online summarisation pass? Auto-Dreamer
   is the closest, and it is one preprint with self-reported numbers.
2. What do Claude Code Auto Dream and ChatGPT Dreaming V3 actually do? Both are
   closed; all coverage I could reach is secondhand blog writeups. The OpenAI figure
   quoted everywhere (41.5% -> 82.8% recall, 5x compute cut) traces to a vendor
   announcement I could not load.
3. What does consolidation *cost*? Nobody publishes tokens-per-sweep. For a nightly
   sweep over a working set this is the number that decides whether it's viable.

## Second pass: cross-verification after the access question came up

The creator widened network access and asked me to retry. Re-tested `arxiv.org`
(twice), `aclanthology.org` and `www.anthropic.com` — all still EGRESS_BLOCKED. The
egress policy is snapshotted when the environment is created and is not re-read by a
running session, so a widened policy needs a **new session** to take effect.

What I could do instead: `WebSearch` runs server-side and is not subject to the proxy
allowlist, so I re-queried each load-bearing **[summary]** claim from a different angle
and checked the two independent result sets agreed. This is weaker than reading the
PDF, but it catches the failure mode that actually bites — a single search summary
mangling a number, which already happened once with the HaluMem table.

Results of the cross-check — all four confirmed, three gained useful detail:

| Claim | First pass | Second pass | Verdict |
|---|---|---|---|
| Sleep-time compute ~5x | "~5x on Stateful GSM-Symbolic" | ~5x on Stateful GSM-Symbolic **and** Stateful AIME | corrected — I had under-stated the scope |
| Sleep-time +13% / +18% / 2.5x | same | same | confirmed; got full author list (Lin, Snell, Wang, Packer, Wooders, Stoica, Gonzalez) |
| ConvoMem 70-82% vs 30-45%, <150 convs | same | same, + 75,336 QA pairs over six categories, Salesforce dataset | confirmed |
| MINJA ">95%" | ">95% injection success" | 98.2% average **injection** success; ~70% **attack** success | refined — two different rates were being collapsed |
| Auto-Dreamer +7 pts, 12x smaller | same | ScienceWorld 41.1% vs UMEM 34.1% (+7.0) and ReasoningBank 30.9% (+10.2); 12x smaller bank on ScienceWorld, 6x on ALFWorld | confirmed with specifics |

The MINJA one matters for the report's argument. ">95% success" invites the reader to
imagine a 95%-effective attack. The honest framing is that getting the poison *into*
memory is nearly free (98.2%), and getting it to *fire* is harder but still common
(~70%). The consolidation risk lives on the first number: a dream cycle operates on
what is already in the bank.

Still unread and still tagged **[summary]**: the OpenAI Dreaming announcement, anything
first-party on Claude Code Auto Dream, the ConvoMem and Auto-Dreamer PDFs, the CLS
1995 paper, and Anthropic's context-engineering post.
