# A checklist for evaluating an agent memory design

Derived from the failure modes in the accompanying [report](README.md). Each item is
phrased as a question to ask of a design, with the evidence that makes it worth asking.

## 0. Should this exist yet?

- [ ] **How many sessions of history will a typical user actually have?**
      Under ~150 conversations, ConvoMem found full-context baselines at 70-82% on the
      hardest cases while RAG-style memory systems managed 30-45%. Below ~30
      conversations, long context was unbeatable. A memory system introduced too early
      is a pure accuracy regression.
- [ ] **What is the latency budget?** ConvoMem's crossover was driven by latency
      (~23s for long context past ~300 conversations), not accuracy.
- [ ] **Can you state the workload in tokens?** One hour a day for four weeks is about
      100k tokens - 10% of a 1M window.

## 1. Writing

- [ ] Is extraction measured separately from question answering? HaluMem exists because
      end-to-end QA scores hide extraction failures.
- [ ] Does extraction quality hold at your corpus size? Mem0's extraction F1 went
      57.31% -> 6.22% between HaluMem-Medium (~160k tokens) and HaluMem-Long (~1M).
      Benchmark numbers do not transfer across scale.
- [ ] Is there a cap on how much gets written per session?

## 2. Updating - the weakest link in every system measured

- [ ] What happens when a new fact contradicts an old one?
      Best update-correctness in HaluMem was 65.25% (MemOS). Most systems scored
      1-25%. This is the least solved part of the field.
- [ ] Do you overwrite, or invalidate-with-validity-window (Graphiti), or
      accumulate-and-let-retrieval-sort-it-out (Mem0 post-Apr-2026)? All three are
      defensible; silently overwriting is the one that loses auditability.
- [ ] Can you answer "what did the agent believe on date X"?

## 3. Consolidation (the "dreaming" part)

- [ ] **Does anything decide _how_ an entry is written, not just _whether_?**
      OpenClaw issue #67363: the deep phase promoted verbatim daily-log lines like
      "Started the day. 10:15 AM. Greeted the user." A scoring gate is selection.
      Consolidation is synthesis. Shipping only the gate gets you a tidy pile of noise.
- [ ] Are read/stage phases separated from the single phase allowed to write?
- [ ] **Is there a cap on destruction per sweep?** OpenClaw defaults
      `maxPriorEntryLossFraction` to 0.25 - one bad sweep cannot empty the store.
- [ ] Are untouched entries preserved byte-for-byte unless explicitly merged?
- [ ] Is the sweep idempotent, and can you replay or roll back one?
- [ ] What does a sweep cost in tokens? Nobody publishes this. Measure it yourself
      before committing to a nightly schedule.

## 4. Forgetting

- [ ] Is forgetting explicit (decay tiers, TTLs) or implicit (failure to get promoted)?
- [ ] Are there entries that must never decay? The `openclaw-memory-dreaming` project
      crystallises anything recalled 20+ times and puts a 0.3 score floor under
      structural facts (IPs, URLs, credentials).
- [ ] Can a user see what was forgotten and why?

## 5. Trust and provenance

- [ ] **Is provenance checked _before_ consolidation, not after?** OpenClaw excludes
      `untrusted` and `system` provenance candidates pre-consolidation.
- [ ] MINJA showed >95% success injecting malicious records into agent memory through
      ordinary queries alone, with no privileged access. A consolidation pass that
      promotes a poisoned transient record into durable memory - and drops its
      provenance while summarising - is an attack amplifier, not a neutral tidy-up.
- [ ] Does every long-term entry trace back to a source episode? (Graphiti's episodes,
      Auto-Dreamer's provenance-linked trajectories.)

## 6. Inspectability

- [ ] Can a human read the memory store directly, without a query interface?
- [ ] Is there an audit log of what each sweep changed? (OpenClaw's `DREAMS.md`,
      `dream-log.md`.)

## 7. Evaluation

- [ ] Do you have a held-out set drawn from your own traffic, not just LoCoMo /
      LongMemEval? Vendor numbers and independent operation-level numbers for the same
      system diverge sharply (Mem0: 92.5 LoCoMo self-reported vs 57.31% extraction F1
      on HaluMem-Medium).
- [ ] Do you measure omission separately from hallucination? HaluMem's omission rates
      (18-55%) are larger than its hallucination rates for most systems.
- [ ] Is there a no-memory, full-context control arm in every experiment?
