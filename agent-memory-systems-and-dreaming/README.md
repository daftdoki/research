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

1. A **product feature** — an offline pass that merges, prunes and supersedes entries
   in a memory store (OpenClaw Dreaming, Anthropic's Managed Agents **Dreams**, Letta
   **Dreaming**, ChatGPT **Dreaming V3**). This is database maintenance with a sleep
   metaphor bolted on. It is genuinely useful and genuinely unglamorous. Note that only
   one of those four actually runs at night — see
   [what the products ship](#what-the-dream-cycle-products-actually-ship-read).
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
  managed 30–45%. Long context wins on *accuracy* while the corpus is small; it does
  not win on cost or latency, and the paper is blunt about that (Mem0 is up to 95x
  cheaper at scale and faster after ~10–20 conversations). The claim is that accuracy
  is worth the premium up to roughly 150 conversations — not that you get it free.
  A month of daily hour-long use is ~100k tokens: 10% of a 1M-token window.
- **Updating memory is the unsolved part, not writing it.** On HaluMem, the best
  update-correctness of six production systems was 65%; most scored between 1% and 25%.
  Everyone can extract facts. Almost nobody can correctly change one.
- **A scoring gate is not a consolidation step.** OpenClaw's dream cycle shipped with
  a six-signal weighted scorer deciding *whether* to promote an entry and nothing
  deciding *how* to write it, so it promoted verbatim daily-log lines like
  "Started the day. 10:15 AM. Greeted the user." into curated long-term memory. The
  same failure appears, measured, in Auto-Dreamer's appendix: a baseline whose
  consolidation step "fires nine times but retires no active entries", leaving a bank
  of 265 entries in which 49 are paraphrases of the task instruction and four are
  byte-identical copies of "The agent's inventory contains an orange."

A practical takeaway for a small system: steal OpenClaw's *structure* (read/stage
phases separated from a single write phase, a hard cap on how much one sweep may
destroy, provenance checked before promotion), steal Anthropic's *write model* (the
pass emits a new store and never mutates the input, so there is no update to get
wrong) or Graphiti's if you need it in place (invalidate with a validity window, never
silently overwrite), steal Letta's *trigger* (step count or compaction event, not a
cron), and do not build any of it until you have measured a no-memory full-context
control arm on your own traffic.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

Desk research against public sources, plus two supporting artifacts built from the
findings: a [systems comparison table](systems-comparison.csv) and an
[evaluation checklist](evaluation-checklist.md).

### How this report was researched, in three passes

The first two passes ran in a session whose egress proxy permitted only `github.com`
and `raw.githubusercontent.com` and blocked essentially every scholarly and vendor
host. Primary reading was done against GitHub — repositories, `docs/` folders, issue
threads — and everything else rested on search-engine summaries, tagged **[summary]**
with the warning that the numbers were unverified.

A third pass ran in a new session with a wider policy. This confirmed the earlier
diagnosis that the egress policy is fixed per environment and cannot be widened
mid-session:

| Host | Passes 1–2 | Pass 3 |
|---|---|---|
| `github.com`, `raw.githubusercontent.com` | OK | OK |
| `arxiv.org`, `aclanthology.org`, `nature.com` | blocked | **OK** |
| `www.anthropic.com`, `docs.claude.com`, `platform.claude.com`, `docs.letta.com` | blocked | **OK** |
| `openai.com` | blocked | reachable, but Cloudflare challenges non-browser clients |

**Every source this report depends on has now been read in full, with two exceptions
noted in [sources.md](sources.md).** The OpenAI announcement was read via headless
Chromium, which clears the Cloudflare challenge; its evaluation charts are images and
their values could not be extracted. McClelland, McNaughton & O'Reilly (1995) is still
paywalled or 403 on every host tried.

### Verification discipline, and what it caught

Two rounds of re-checking happened before the primary sources were reachable, and both
earned their keep. The first read of HaluMem's results produced the implausible
combination of 6.22% extraction F1 and 98.51% QA accuracy for the same system;
re-fetching with a request for verbatim column headers revealed the reader had mapped
the *omission rate* column onto QA accuracy. The second round re-queried each
load-bearing **[summary]** figure from an independent angle.

Reading the primary sources then overturned four claims that both earlier passes had
let through. They are worth stating plainly, because they are a fair
sample of what search summaries do to facts and figures:

| Claim as first reported | What the source says |
|---|---|
| Claude Code ships "Auto Dream": four-phase offline consolidation with a `/dream` trigger | No such feature. Claude Code has *Auto memory* (online, no sweep, no `/dream`); Anthropic's consolidation pass is **Dreams** in the separate Managed Agents platform, and it is an on-demand job, not four phases |
| Below ~150 conversations long context wins on accuracy **and cost** | Accuracy only. Mem0 is up to **95x cheaper** at scale and faster past ~10–20 conversations; the paper's body puts Mem0 as the default beyond **50–100** interactions |
| MINJA attack success ~70% | **76.8%** |
| The 41.5% → 82.8% recall figure comes from OpenAI's announcement | The announcement's text contains **no percentages at all**. The figure is a third-party reading of a chart image |

Two of those four were *stable across two independent search passes* and still wrong.
Agreement between summaries is not evidence; it mostly measures how widely one phrasing
has been copied.

## Results

### The landscape, organised by what the system actually does

| Family | Representative systems | Core idea | What it solves |
|---|---|---|---|
| Reflection | Generative Agents, Reflexion | Periodically synthesise higher-level thoughts from raw observations | Raw logs don't generalise |
| OS metaphor | MemGPT/Letta, MemOS | Tiered memory with paging and a scheduler | Context window is a scarce resource |
| Extract–retrieve | Mem0, Memobase, Supermemory | LLM extracts facts; vector/hybrid retrieval serves them | Cheap, simple, framework-agnostic |
| Temporal graph | Zep/Graphiti, kaeru | Bi-temporal knowledge graph; facts have validity windows | Facts change and you must audit the change |
| Associative / Zettelkasten | A-MEM, HippoRAG | Links between memories are first-class | Multi-hop and sense-making queries |
| Dream cycle | OpenClaw Dreaming, Anthropic Dreams, Letta Dreaming, ChatGPT Dreaming V3 | Offline pass that merges/prunes/supersedes | Store grows monotonically and rots |
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

### What the dream-cycle products actually ship **[read]**

Four vendors now ship something called dreaming. Reading the first-party docs rather
than the coverage, they agree on *what* the pass does and disagree on almost every
design decision that matters:

| | OpenClaw Dreaming | Anthropic Managed Agents **Dreams** | Letta **Dreaming** | ChatGPT **Dreaming V3** |
|---|---|---|---|---|
| Trigger | nightly cron `0 3 * * *` | on demand (`POST /v1/dreams`) | step count, or compaction event | continuous background |
| Writes to | the live store | a **new** store; input never modified | MemFS (git-backed) | the live memory state |
| Scope | staged candidates | 1 store + 1–100 session transcripts | recent conversations | years of conversations |
| Blast-radius control | `maxPriorEntryLossFraction` 0.25 | total — input is read-only | backup-before-reorganise | not documented |
| Review before adopt | no | **yes** — you inspect the output store, then attach or delete it | optional "agent reviews before applying" | memory summary page, after the fact |
| Sweep cost visible | no | **yes** — `usage` on the dream resource, live | no | no |
| Status | shipping | research preview (`dreaming-2026-04-21` beta header) | shipping | rolling out from June 4, 2026 |

Four things are worth pulling out.

**Only one of the four is nightly.** The sleep metaphor implies a clock, and three of
the four implementations don't use one. Letta's choice is the most interesting:
consolidation fires on *step count or context compaction*, so it tracks how much work
happened rather than how much time passed. For anything with uneven usage that is a
better default than 3am.

**Anthropic's version sidesteps the update problem entirely.** A dream reads one memory
store plus up to 100 session transcripts and emits a *separate* output store — "The
input store is never modified, so you can review the output and discard it if you don't
like the result." There is no supersession logic to get wrong, because nothing is
overwritten. The cost of that safety is that nothing is automatic: no cadence, and a
human decides whether the output is adopted. The surrounding Memory Stores API does the
other half independently: "Every change to a memory creates an immutable memory
version, giving you an audit trail and point-in-time recovery for everything the agent
writes", versions attributed to the session that made them, retained 30 days, with a
`redact` endpoint for scrubbing history.

The docs are also explicit that steering the pass is synthesis-level, not editorial:
"The pipeline is a synthesis pass over the inputs, not an editor applied to the text of
the store, so imperative directives that target specific lines … generally produce no
change." That is the gate/writer separation of
[Selection is not synthesis](#selection-is-not-synthesis), stated as a product
constraint.

**"Claude Code Auto Dream" does not exist.** Earlier drafts of this report repeated a
third-party description of a four-phase offline cycle in Claude Code with a `/dream`
trigger. The first-party docs describe two unrelated features and neither is that.
Claude Code has **Auto memory**: online, in-session, writing typed notes (`user`,
`feedback`, `project`, `reference`) to `~/.claude/projects/<project>/memory/` behind a
`MEMORY.md` index. The word "dream" does not appear in the Claude Code documentation.
Anthropic's consolidation pass is Dreams, in the separate Managed Agents platform.

Claude Code's actual approach is worth a look anyway, because it answers the same
problem differently. `MEMORY.md` is capped at 200 lines or 25KB — the load limit at
session start. When a write approaches the cap, the harness tells the model to "keep
one line per entry, move detail into topic files, and merge or drop stale entries";
when a write exceeds it, the write succeeds but the harness returns an error demanding
a rewrite, because everything past the limit is silently dropped on the next load. That
is consolidation forced by a hard budget at write time, with no sweep at all.

**What OpenAI's announcement actually says.** The June 4, 2026 post confirms Dreaming
V0 shipped in **April 2025** — dreaming is not new in 2026, V3 is — and that it is "a
background process that allows ChatGPT to learn from many conversations and synthesize
ChatGPT's memory state". It states one number in prose: "Recent improvements reduced
the compute required to serve dreaming to Free users by approximately 5x." That is a
serving-cost figure, not an accuracy figure.

The widely-quoted 41.5% → 82.8% recall improvement **is not in the announcement's
text**, which contains no percentages at all. Results appear only as charts — images —
across three axes (carrying forward context, following preferences, staying current
over time) and three generations (2024 saved memories / 2025 + Dreaming V0 / 2026
Dreaming V3), described in prose as "a substantial lift". The circulating numbers are
third-party readings of those images, of an internal eval OpenAI has not released. Cite
them as vendor chart values at best.

### Sleep-time compute: the numbers **[read]**

Kevin Lin, Charlie Snell, Yu Wang, Charles Packer, Sarah Wooders, Ion Stoica and
Joseph E. Gonzalez (Letta and UC Berkeley), arXiv 2504.13171.

| Measure | Result | Fine print |
|---|---|---|
| Test-time tokens for equal accuracy (Stateful GSM-Symbolic *and* Stateful AIME) | ~5x fewer | synthetic stateful maths |
| Accuracy gain from scaling sleep-time compute (Stateful GSM-Symbolic) | up to +13% | |
| Accuracy gain (Stateful AIME) | up to +18% | |
| Cost per query when amortised across related queries (Multi-Query GSM-Symbolic) | 2.5x lower | **requires 10 queries per context** |
| Test-time tokens on a realistic agentic SWE task (SWE-Features) | ~1.5x fewer | **only at low test-time budgets** |

The amortisation row is the one that decides applicability, and the paper pins it
down: the 2.5x arrives "when there are 10 queries per context, compared to the
single-query baseline." One question per context and it is pure waste.

The last row is the row to take seriously if you are building an agent rather than a
benchmark. On SWE-Features — real PRs touching three or more files — sleep-time compute
helps at low test-time budgets and *loses* at high ones: "when the test-time compute
budget is high, using only test-time compute can perform better." The clean 5x lives on
synthetic stateful maths. The paper's own explanation of when the technique works is
the useful design rule: it pays in proportion to how **predictable the query is from
the context**, measured directly and confirmed in §5.4.

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

### ConvoMem: the control arm nobody runs **[read]**

Pakhomov, Nijkamp and Xiong, Salesforce AI Research, arXiv 2511.10523. 75,336
question–answer pairs across six categories — user facts, assistant facts, abstention,
preferences, changing facts, implicit connections — with evidence systematically
distributed across 1–6 messages and context configurable from 2 to 300 conversations.
All figures below use Gemini 2.5 Flash unless noted.

Accuracy, by evidence type:

| Category | Full context | Mem0 | Gap |
|---|---|---|---|
| User facts | 94.7% at the start | 77.5% at the start | stable 15–25 pts at every scale |
| Preferences | 77–90% | 30–45% | ~45 pts |
| Implicit connections | 63–82% | 25–45% | ~38 pts |

The degradation pattern under multiple evidence items is the sharpest result in the
paper, and it is the one that should worry anyone building a retrieval-based store:

| Evidence items | Full context @300 convs | Mem0 @300 convs | Gap |
|---|---|---|---|
| 1 | ~84% | 61% | 23 pts |
| 3 | ~83% | 38% | 37 pts |
| 6 | ~83% | 25% | **58 pts** |

Long context is flat across 1, 3 and 6 evidence items. Mem0 loses three quarters of its
accuracy. "RAG architectures struggle fundamentally with multi-fact retrieval
scenarios, where relevant information is distributed across multiple memory entries."

**The cost story runs the other way.** This is where an earlier draft of this report
was wrong, having taken the abstract's framing at face value. Long context costs $0.001 → $0.09 per query as history grows to 300 conversations; Mem0
holds steady at $0.0007–$0.0015, "achieving up to 95x cost reduction at scale." On
latency, long context climbs to ~23s at 300 conversations while Mem0 stays at 3–7s,
with the crossover "around 10–20 conversations."

So there are two different transition points in the same paper and they should not be
conflated:

| Framing | Threshold | Source |
|---|---|---|
| Long context "remains viable with manageable trade-offs" | ~150 conversations | abstract |
| Mem0 "becomes the default choice … despite its accuracy limitations" | 50–100 interactions | §3.4.4 |

Both are true. The first is about what you can still afford; the second is about what
you would choose on cost alone. The design conclusion survives either way — measure the
no-memory arm before you build — but the argument is "accuracy is worth paying for
early", not "simplicity is free".

One more finding with direct budget consequences: medium-tier models match premium ones
on memory tasks (2.3 points separate Flash from Pro at 300 conversations) while
ultra-light models fall off a cliff (Flash Lite trails Flash by 24–31 points). There is
a minimum model capacity for memory work, and above it, spending more buys very little.

## Analysis

### The metaphor is about scheduling, not mechanism

Complementary learning systems theory says there are two learning systems because the
neocortex must learn *slowly* — learning a new fact quickly at full strength destroys
the structure already encoded in the weights. Hippocampal replay during sleep
interleaves new experience with old, which is what makes slow consolidation possible
without catastrophic interference.

None of that applies to a Markdown file and a vector index. There are no weights being
updated, so there is no interference to prevent. The literature on replay in artificial
networks is explicit about this: van de Ven, Siegelmann & Tolias (*Nature
Communications*, 2020) motivate generative replay entirely by the need to "prevent
catastrophic forgetting" during training. No weights, no problem to solve.

What survives the analogy is much weaker and much more mundane: *some useful work is
expensive, latency-sensitive work should not pay for it, so do it out of band when
nobody is waiting.* That is a good idea. It is also an idea that batch ETL had in 1985.

The people building on CLS most seriously say the same thing. Auto-Dreamer, whose
entire architecture is the fast/slow split, states it outright: "We adopt CLS not as a
biological claim about language models, but as an operational design principle for
separating fast acquisition from slow cross-session consolidation." That is the version
to steal — the scheduling discipline, not the biology.

And the schedule itself turns out to be the part the metaphor gets wrong. Of the four
shipping implementations, only OpenClaw's actually runs at night; Anthropic's is
on-demand, Letta's fires on step count or compaction, OpenAI's is continuous. "Sleep"
is a name for *out of band*, not for a time of day.

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

This is no longer a single anecdote. Auto-Dreamer's Appendix I reproduces the same
failure in a different system, measured. On 96 ScienceWorld episodes, Auto-Dreamer and
LightMem both solve exactly 48 — identical accuracy — but LightMem's bank holds 265
entries / 17,512 tokens against Auto-Dreamer's 14 / 716. What is *in* LightMem's bank
is the point: 49 of the 265 entries are paraphrases of the task instruction, the first
four byte-identical; four byte-identical copies of "The agent's inventory contains an
orange."; two of "The agent has taken 0 moves so far."; and four entries that are the
same room description with the objects listed in a different order. The authors'
summary: "In this run, LightMem's consolidation step fires nine times but retires no
active entries, so memory grows monotonically."

A scheduled pass that fires nine times and removes nothing is a scheduled pass in name
only. Both artifacts — one bug report, one benchmark appendix — say the same thing: the
gate is the easy half.

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
about the entire benchmark literature in this area.

Reading LoCoMo itself makes the scale gap concrete. It is 50 conversations averaging
304.9 turns, 19.3 sessions and **9,209 tokens**, with 7,512 questions (Maharana et al.,
UNC / USC / Snap, arXiv 2402.17753). A LoCoMo score of 92.5 is therefore a score on
~9k-token conversations — a context that fits in any modern window several hundred
times over. HaluMem-Long's 6.22% for the same system is measured at ~1M tokens. These
are not contradictory findings; they are findings two orders of magnitude apart in
corpus size, and only the flattering one appears in a README. ConvoMem makes the same
point from the other direction: "simple filesystem operations achieved 74% accuracy on
LoCoMo, matching or exceeding sophisticated memory systems."

Worth noting that the paper this report leans on hardest for the "you may not need
this" argument is itself a preprint with self-reported numbers, and its abstract and
body disagree about the key threshold (150 vs 50–100). The discipline applies to it
too. The maintainer of the largest
curated list in the field segregates "vendor self-claims" from "independent
reproductions" for exactly this reason, and openly notes that 988 of its 989 papers are
unread stubs.

The collapse between HaluMem-Medium and HaluMem-Long is the sharper warning: a memory
system's benchmark score does not transfer across corpus scale. A number measured at
160k tokens tells you nothing about behaviour at 1M.

### Consolidation is an attack surface

MINJA (Dong et al., NeurIPS 2025) injects malicious records into an agent's long-term
memory through ordinary queries alone — no privileged access, no direct store writes.
Two success rates are worth keeping separate: **injection** success — getting the record
into the memory bank — averages 98.2%, while **attack** success — the poisoned record
actually changing behaviour on a victim query — averages 76.8%. Injection is also the
more reliable of the two: across six agent/dataset configurations, injection success
ranges 95.6%–100.0% with low variance, while attack success ranges from 57.0%±10.3 to
98.9%±2.2. Now add a dream cycle. The sweep takes a transient poisoned record, notices it recurs, promotes
it into the durable high-trust store, and summarises away the provenance that would
have let you find it. Consolidation converts a transient compromise into a permanent
one and launders its origin in the process.

It is worth being precise about how MINJA compares to the earlier AgentPoison (Chen et
al., NeurIPS 2024), because the interesting claim is not the one usually made.
AgentPoison achieves "an average attack success rate of ≥80% with minimal impact on
benign performance (≤1%) with a poison rate <0.1%" — but it assumes the attacker can
write to the memory or knowledge base directly. MINJA gets **comparable** attack
success (76.8%) from a threat model where the attacker is an ordinary user typing
queries. The escalation is in the assumptions, not the numbers, and that is worse news.

MINJA's own defence evaluation (§5.4) closes off most of the obvious answers.
Embedding-level sanitization fails because the malicious records look benign under
similarity filtering. Prompt-level detection with GPT-4o is "the most practical and
potentially effective" but does not generalise: a targeted flagging prompt caught
131/135 malicious records on one agent and *zero* on the other two, while a general
prompt generalised at the cost of flagging benign records and "undermining the
utility." What remains is system-level: isolating memory banks across users, and rate
limiting.

OpenClaw's answer is the right shape: exclude `untrusted` and `system` provenance
candidates *before* consolidation runs, not after. If you build a sweep, build the
provenance filter in the same commit.

### What this means for a small system

In rough priority order:

1. **Build the control arm first.** Full context, no memory. If you cannot beat it on
   your own traffic, you have not yet earned a memory system. ConvoMem puts the
   accuracy crossover somewhere around 150 conversations and the *cost* crossover much
   earlier, around 50–100 — so run the arm on your own traffic rather than taking
   either number.
2. **Append-only with supersession, or copy-on-write.** Never mutate in place. You get
   auditability free and you sidestep the worst-measured operation in the field.
   Anthropic's Dreams API takes the stronger version — the consolidation pass emits a
   *new* store and never touches the input — which removes the update problem instead
   of managing it, at the price of a human deciding whether to adopt the result.
3. **Separate the gate from the writer.** Score to select; generate to write. Issue
   #67363 is what happens otherwise, and Auto-Dreamer's LightMem case study is the same
   failure measured: nine consolidation passes, zero entries retired.
4. **Cap the blast radius of a sweep.** A quarter of entries is OpenClaw's default;
   Letta backs up the store before a reorganisation; Anthropic's radius is zero by
   construction. Pick one of the three. Anything less conservative and one bad model
   call eats your memory.
5. **Trigger on work done, not on the clock.** Letta fires consolidation on step count
   or on a compaction event. For uneven usage that beats a nightly cron, which either
   runs over nothing or falls far behind.
6. **Provenance before promotion**, as a security control.
7. **Keep it human-readable.** Every dream-cycle implementation examined here — the two
   OpenClaw projects, Letta's git-backed MemFS, Claude Code's `MEMORY.md` plus topic
   files — chose plain Markdown over a vector store, on the grounds that you cannot
   debug what you cannot read. For a small system this is close to free.
8. **Measure the sweep's token cost.** Almost nobody publishes it, so instrument it
   yourself; it is the number that decides whether scheduled consolidation is viable at
   your scale. The one exception is now Anthropic's Dreams API, where every dream
   carries a live `usage` object (input, output and cache token counts) and the docs
   state cost "scales roughly linearly with the number and length of input sessions."
   Auto-Dreamer logs the same thing per consolidator call and then reports only
   retrieval-time memory tokens in the paper — which is the general pattern.

### What remains unknown **[read]**

Earlier drafts said no apples-to-apples ablation existed isolating offline
consolidation. Reading Auto-Dreamer (Ye, Liu et al., UIUC / UCSD, arXiv 2605.20616)
changes that: its Table 1 Panel B is exactly that experiment. Every method gets the
same fixed initial bank `B0`, a frozen task agent and held-out tasks, so the only thing
varying is the consolidation operator. Auto-Dreamer wins it — 44.3% vs 42.0% (Mem0) and
31.8% (LightMem) on ScienceWorld, 72.7% vs 70.1% (ExpeL) on ALFWorld.

The headline continual-deployment numbers hold up exactly as reported: 41.1% on
ScienceWorld against UMEM's 34.1% (+7.0) and ReasoningBank's 30.9% (+10.2), with 6.9k
memory tokens against UMEM's 80.9k (12x) and, on held-out ALFWorld, 11.0k against 62.9k
(6x). What the abstract does not carry is Appendix H, and Appendix H changes the
reading:

| Domain | Auto-Dreamer, bootstrap 95% CI | Strongest baseline | Verdict |
|---|---|---|---|
| ScienceWorld | 41.07 [37.53, 44.70] | UMEM 34.07 [30.51, 37.71] | non-overlapping — real |
| ALFWorld (held out) | 60.21 [54.65, 65.59] | UMEM 58.43 [53.15, 63.65] | heavy overlap — not significant |
| WebArena (held out) | 52.3 [43.5, 60.9] | AWM / LightMem 52.0 | total overlap — not significant |

The one domain where the success-rate gain clears noise is the one domain the
consolidator was trained on. On the held-out domains the accuracy transfer claim rests
on point estimates inside the confidence intervals.

What *does* transfer, decisively, is compactness: 927 tokens on WebArena against 370k
for LightMem and 43.4k for Mem0, at equal or better success. And the cleanest single
result in the paper is the case study, where consolidation changes nothing about
accuracy and everything about size — 48/96 for both methods, with a 24.5x smaller bank.

So the honest position is unchanged and now better evidenced: consolidation's
demonstrated, reproducible win is **compression at equal accuracy**. Its effect on
**recall** is real in one trained-on domain and inside the noise everywhere else it has
been measured — which is still more than "asserted", and still less than "established".

The genuinely open questions after this pass:

1. **Does consolidation beat online summarisation at equal *total* token budget?**
   Auto-Dreamer's control study holds the *bank* fixed, not the compute. Nobody has
   published the comparison that charges the sweep against the same budget.
2. **What does a sweep cost in production?** Anthropic's API now exposes it per job,
   which makes the question answerable for the first time — but no one has published
   the answer.
3. **Do the shipping products work?** Four vendors ship dreaming. Not one has published
   an evaluation anyone outside the company can check; OpenAI's is chart images of an
   unreleased internal benchmark.

## Files

- `README.md` — this report
- `notes.md` — full research log, including dead ends and the tagged evidence dump
- `sources.md` — annotated bibliography, each entry tagged `[read]` or `[summary]`
- `systems-comparison.csv` — 15 systems × 11 attributes (storage, write path, update
  strategy, offline consolidation, forgetting, provenance, evidence strength)
- `evaluation-checklist.md` — a design checklist derived from the failure modes above,
  organised by memory operation

## Original Prompt

> I am building a small memory system for agents and I've heard some news about dreaming applied to AI memory systems and I'd like you to research the approaches for memory systems and collect some research that I can use to help me evaluate approaches in my own system.
