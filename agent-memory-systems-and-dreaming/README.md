# Agent Memory Systems and the "Dreaming" Turn

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What are the current approaches to memory for LLM agents, what exactly is the
"dreaming" idea that has been in the news, and what evidence exists that any of it
works — enough to evaluate design choices in a small memory system of one's own?
([original prompt](#original-prompt))

## Answer

**"Dreaming" is three unrelated things wearing one name, and only one of them has
convincing evidence behind it.**

1. A **product feature** — a scheduled batch pass that merges, prunes and supersedes
   entries in a memory store (OpenClaw Dreaming, Claude Code Auto Dream, ChatGPT
   Dreaming V3). This is scheduled database maintenance with a sleep metaphor bolted
   on. It is genuinely useful and genuinely unglamorous.
2. An **inference-scaling technique** — Letta and UC Berkeley's *sleep-time compute*:
   precompute reasoning over a context before the query arrives. It has real numbers
   (~5x fewer test-time tokens, +13–18% accuracy) but it is not memory consolidation
   at all, and it only pays when many queries hit the same context.
3. A **neuroscience metaphor** — hippocampal replay and complementary learning
   systems. This is load-bearing in exactly one popular system (HippoRAG) and
   decorative in most of the rest. The problem CLS theory solves — catastrophic
   interference during weight updates — does not exist in a retrieval-based memory
   system, because nothing is updating weights.

**Three findings should change how you build:**

- **You may not need a memory system yet.** ConvoMem found full-context baselines
  scoring 70–82% on the hardest multi-message cases where RAG-based memory systems
  managed 30–45%, and that below ~150 conversations long context wins on both accuracy
  and cost. A month of daily hour-long use is ~100k tokens: 10% of a 1M-token window.
- **Updating memory is the unsolved part, not writing it.** On HaluMem, the best
  update-correctness of six production systems was 65%; most scored between 1% and 25%.
  Everyone can extract facts. Almost nobody can correctly change one.
- **A scoring gate is not a consolidation step.** OpenClaw's dream cycle shipped with
  a six-signal weighted scorer deciding *whether* to promote an entry and nothing
  deciding *how* to write it, so it promoted verbatim daily-log lines like
  "Started the day. 10:15 AM. Greeted the user." into curated long-term memory. That
  bug report is the most useful single artifact in this whole investigation.

A practical takeaway for a small system: steal OpenClaw's *structure* (read/stage
phases separated from a single write phase, a hard cap on how much one sweep may
destroy, provenance checked before promotion), steal Graphiti's *update model*
(invalidate with a validity window, never silently overwrite), and do not build any of
it until you have measured a no-memory full-context control arm on your own traffic.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

Desk research against public sources, plus two supporting artifacts built from the
findings: a [systems comparison table](systems-comparison.csv) and an
[evaluation checklist](evaluation-checklist.md).

### A constraint worth stating up front

This session's egress proxy permits `github.com` and `raw.githubusercontent.com` and
blocks essentially every scholarly and vendor host:

| Host | Result |
|---|---|
| `github.com`, `raw.githubusercontent.com` | OK |
| `arxiv.org`, `aclanthology.org`, `openreview.net` | blocked |
| `huggingface.co`, `pmc.ncbi.nlm.nih.gov`, `stanford.edu` | blocked |
| `openai.com`, `www.anthropic.com`, `docs.letta.com`, `docs.openclaw.ai`, `dev.to` | blocked |

`/root/.ccr/README.md` states that a proxy denial is an organisation egress policy
decision to be reported rather than routed around, so no mirror was used. Primary
reading was done against GitHub — repositories, `docs/` folders, issue threads — and
supplemented by search-engine summaries for documents on blocked hosts.

Every claim in this report and in [sources.md](sources.md) is tagged **[read]** or
**[summary]** accordingly. **[summary]** numbers should be re-verified against the
source PDF before anyone makes a decision on them. This turned out to be a productive
constraint in one respect: it forced reliance on shipping source code, documentation
and bug reports rather than on paper abstracts, and the bug reports were more
informative than the abstracts.

### Verification discipline

One table was fetched twice. The first read of HaluMem's results produced the
implausible combination of 6.22% extraction F1 and 98.51% QA accuracy for the same
system; re-fetching with a request for verbatim column headers revealed the reader had
mapped the *omission rate* column onto QA accuracy. The corrected tables are below.
Any result that flatters or damns a system implausibly was re-read.

## Results

### The landscape, organised by what the system actually does

| Family | Representative systems | Core idea | What it solves |
|---|---|---|---|
| Reflection | Generative Agents, Reflexion | Periodically synthesise higher-level thoughts from raw observations | Raw logs don't generalise |
| OS metaphor | MemGPT/Letta, MemOS | Tiered memory with paging and a scheduler | Context window is a scarce resource |
| Extract–retrieve | Mem0, Memobase, Supermemory | LLM extracts facts; vector/hybrid retrieval serves them | Cheap, simple, framework-agnostic |
| Temporal graph | Zep/Graphiti, kaeru | Bi-temporal knowledge graph; facts have validity windows | Facts change and you must audit the change |
| Associative / Zettelkasten | A-MEM, HippoRAG | Links between memories are first-class | Multi-hop and sense-making queries |
| Dream cycle | OpenClaw Dreaming, Claude Code Auto Dream | Scheduled offline sweep that merges/prunes/supersedes | Store grows monotonically and rots |
| Precompute | Sleep-time compute | Reason over context before the query arrives | Latency and per-query cost |
| Context engineering | Anthropic compaction + note-taking + subagents | Manage the window rather than build a store | Long-horizon single tasks |

Full attribute-level breakdown in [systems-comparison.csv](systems-comparison.csv).

### What a real dream cycle looks like

OpenClaw's is the only one documented in enough detail to evaluate. Three phases per
sweep, of which **only the last is allowed to write**:

| Phase | Reads | Writes | Job |
|---|---|---|---|
| light | short-term recall, daily files, transcripts | nothing durable | ingest, dedupe, stage candidates |
| REM | recent traces | nothing durable | theme and reflection summaries; reinforcement signals for ranking |
| deep | staged candidates, rehydrated from live files | `MEMORY.md`, `DREAMS.md` | score → gate → model-based add/merge/supersede |

Deep-phase ranking weights:

| Signal | Weight |
|---|---:|
| Relevance | 0.30 |
| Frequency | 0.24 |
| Query diversity | 0.15 |
| Recency | 0.15 |
| Consolidation | 0.10 |
| Conceptual richness | 0.06 |

Defaults: runs `0 3 * * *`; `maxPriorEntryLossFraction` 0.25; `maxPromotedSnippetTokens`
160; enabled by default. Gates are `minScore`, `minRecallCount`, `minUniqueQueries`.
Candidates with `untrusted` or `system` provenance are excluded *before* consolidation.
Annotated entries remain byte-for-byte unless explicitly merged or superseded.

A community project, `openclaw-memory-dreaming`, runs a five-step nightly cycle
(decay → review → integrate → prune → supersede) over plain Markdown with no vector
store, and adds explicit decay tiers — crystallised at 20+ recalls (never decays),
hot 1.0 (<48h), warm 0.6 (<30d), cold 0.3 (<365d), archived below 0.1 — with a 0.3
score floor under structural facts like IPs and URLs.

### Sleep-time compute: the numbers **[summary]**

| Measure | Result |
|---|---|
| Test-time tokens for equal accuracy (Stateful GSM-Symbolic) | ~5x fewer |
| Accuracy gain from scaling sleep-time compute (Stateful GSM-Symbolic) | up to +13% |
| Accuracy gain (Stateful AIME) | up to +18% |
| Cost per query when amortised across related queries (Multi-Query GSM-Symbolic) | 2.5x lower |

The amortisation row is the one that decides applicability. Sleep-time compute pays
when many queries share one context. One question per context and it is pure waste.

### HaluMem: what happens when you measure operations instead of answers **[read]**

HaluMem-Medium — 20 users, 30,073 dialogues, ~160k tokens of context, 14,948 memory
points:

| System | Extraction F1 ↑ | Update correct ↑ | QA correct ↑ | QA halluc. ↓ | QA omission ↓ |
|---|---:|---:|---:|---:|---:|
| MemOS | **79.70%** | **62.11%** | **67.23%** | **15.17%** | **17.59%** |
| Mem0-Graph | 57.85% | 24.50% | 54.66% | 19.28% | 26.06% |
| Mem0 | 57.31% | 25.50% | 53.02% | 19.17% | 27.81% |
| Supermemory | 56.90% | 16.37% | 54.07% | 22.24% | 23.69% |
| Zep | n/a | 47.28% | 55.47% | 21.92% | 22.62% |
| Memobase | 25.13% | 5.20% | 35.33% | 29.97% | 34.71% |

HaluMem-Long — same memory points, ~1M tokens of context:

| System | Extraction F1 ↑ | Update correct ↑ | QA correct ↑ | QA halluc. ↓ |
|---|---:|---:|---:|---:|
| MemOS | **82.11%** | **65.25%** | **64.44%** | **16.61%** |
| Supermemory | 65.54% | 17.01% | 53.77% | 22.21% |
| Zep | n/a | 37.35% | 50.19% | 22.51% |
| Memobase | 11.55% | 4.10% | 33.60% | 29.46% |
| Mem0-Graph | 4.36% | 1.47% | 32.44% | 21.82% |
| Mem0 | 6.22% | 1.45% | 28.11% | 17.29% |

Zep has no memory-extraction API, so extraction metrics are not applicable to it.

### ConvoMem: the control arm nobody runs **[summary]**

| Condition | Full context | RAG-based memory (incl. Mem0) |
|---|---|---|
| Hardest multi-message-evidence cases | 70–82% | 30–45% |
| Evidence spread across 6 messages | ~80% | ~25% |

Reported transition points: under ~30 conversations long context is unbeatable; up to
~150 it remains the best accuracy/cost balance; past ~300 its latency (~23s) forces a
RAG or hybrid approach.

## Analysis

### The metaphor is about scheduling, not mechanism

Complementary learning systems theory says there are two learning systems because the
neocortex must learn *slowly* — learning a new fact quickly at full strength destroys
the structure already encoded in the weights. Hippocampal replay during sleep
interleaves new experience with old, which is what makes slow consolidation possible
without catastrophic interference.

None of that applies to a Markdown file and a vector index. There are no weights being
updated, so there is no interference to prevent. What survives the analogy is much
weaker and much more mundane: *some useful work is expensive, latency-sensitive work
should not pay for it, so do it on a schedule when nobody is waiting.* That is a good
idea. It is also an idea that batch ETL had in 1985.

This matters practically because the metaphor invites you to build phases you do not
need. The "REM" phase in OpenClaw's cycle writes nothing durable; it exists to produce
reinforcement signals for the deep phase's ranking. That is defensible as an
architecture, but it is a ranking pre-pass, and calling it REM does not make its
existence self-justifying.

The exception worth taking seriously is HippoRAG, where hippocampal *indexing* theory
maps onto a concrete mechanism — a knowledge graph traversed with personalised
PageRank — and makes a falsifiable prediction about multi-hop retrieval that the
authors then test. That is the analogy doing work.

### Selection is not synthesis

OpenClaw issue #67363 deserves to be read by anyone building this. The dream cycle has
a careful six-signal weighted scorer with three threshold gates. It correctly decided
that some entries deserved promotion. It then copied them *verbatim* into the curated
long-term store, because `buildPromotionSection` had no distillation step. Entries like
"Started the day. 10:15 AM. Greeted the user" score well on frequency and recency and
carry no information.

The generalisation: a consolidation pipeline needs two separable decisions —
**which** entries survive, and **what** the surviving entry says. Scoring answers the
first. Only a generation step answers the second. It is easy to build the first,
satisfying to tune, and completely useless alone. The issue was closed as not planned.

### Updating is where the field actually is

Read the HaluMem update column again. Best in class is 65%. Four of six systems are
under 26%. Two are under 2% at long context.

This is the strongest argument for the temporal-graph approach. Graphiti does not
update facts; it attaches validity windows and *invalidates* superseded ones, keeping
the original episode as traceable ground truth. Mem0's April 2026 rewrite went the
other way and removed UPDATE and DELETE entirely — memories accumulate and retrieval
sorts it out. Both are principled responses to the same observation: in-place mutation
of an LLM-extracted fact store is where correctness goes to die.

For a small system, the cheap version of this is an append-only log with supersession
pointers. You get auditability and time-travel for roughly the cost of never running
`UPDATE`.

### Vendor numbers and independent numbers describe different worlds

Mem0's README reports LoCoMo 92.5 and LongMemEval 94.4. HaluMem measures the same
system at 57.31% extraction F1 on medium contexts and 6.22% on long ones. Both can be
true — they measure different things at different scales — but the gap is a warning
about the entire benchmark literature in this area. The maintainer of the largest
curated list in the field segregates "vendor self-claims" from "independent
reproductions" for exactly this reason, and openly notes that 988 of its 989 papers are
unread stubs.

The collapse between HaluMem-Medium and HaluMem-Long is the sharper warning: a memory
system's benchmark score does not transfer across corpus scale. A number measured at
160k tokens tells you nothing about behaviour at 1M.

### Consolidation is an attack surface

MINJA injects malicious records into an agent's long-term memory through ordinary
queries alone — no privileged access, no direct store writes — at >95% success. Now add
a dream cycle. The sweep takes a transient poisoned record, notices it recurs, promotes
it into the durable high-trust store, and summarises away the provenance that would
have let you find it. Consolidation converts a transient compromise into a permanent
one and launders its origin in the process.

OpenClaw's answer is the right shape: exclude `untrusted` and `system` provenance
candidates *before* consolidation runs, not after. If you build a sweep, build the
provenance filter in the same commit.

### What this means for a small system

In rough priority order:

1. **Build the control arm first.** Full context, no memory. If you cannot beat it on
   your own traffic, you have not yet earned a memory system. ConvoMem suggests that
   threshold sits somewhere around 150 conversations.
2. **Append-only with supersession.** Never mutate in place. You get auditability free
   and you sidestep the worst-measured operation in the field.
3. **Separate the gate from the writer.** Score to select; generate to write. Issue
   #67363 is what happens otherwise.
4. **Cap the blast radius of a sweep.** A quarter of entries is OpenClaw's default.
   Anything less conservative and one bad model call eats your memory.
5. **Provenance before promotion**, as a security control.
6. **Keep it human-readable.** Both dream-cycle projects examined here chose plain
   Markdown over a vector store, on the grounds that you cannot debug what you cannot
   read. For a small system this is close to free.
7. **Measure the sweep's token cost.** Nobody publishes it. It is the number that
   decides whether nightly consolidation is viable at your scale.

### What remains unknown

No independent, apples-to-apples ablation was found showing that an offline
consolidation pass beats an online summarisation pass at the same token budget.
Auto-Dreamer comes closest — +7 points on ScienceWorld with a 12x smaller active
memory bank — and it is a single preprint with self-reported numbers on a blocked host.
The honest position is that consolidation's demonstrated win is **compression**, and
its effect on **recall** is asserted more often than measured.

## Files

- `README.md` — this report
- `notes.md` — full research log, including dead ends and the tagged evidence dump
- `sources.md` — annotated bibliography, each entry tagged `[read]` or `[summary]`
- `systems-comparison.csv` — 12 systems × 11 attributes (storage, write path, update
  strategy, offline consolidation, forgetting, provenance, evidence strength)
- `evaluation-checklist.md` — a design checklist derived from the failure modes above,
  organised by memory operation

## Original Prompt

> I am building a small memory system for agents and I've heard some news about dreaming applied to AI memory systems and I'd like you to research the approaches for memory systems and collect some research that I can use to help me evaluate approaches in my own system.
