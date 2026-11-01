# User stories: shared LLM wiki

A working file for the user stories behind [DESIGN.md](DESIGN.md). It changes over time; read its git history to see how the ideas evolved.

## Seed stories (as written by the creator, 2026-10-31)

IDs were added after the first commit so stories can be referred to; the wording is unchanged.

I think we have three user types: Human, AI agent, Librarian. Do we need to consider other types?

As an AI agent, I want to:
- **A1**  search for keywords, fuzzy search, and semantic search 
- **A2** narrow search by certain parameters such as (no exhaustive): topic, knowledge base section, personal, page type
- **A3** be able to publish and retrieve pages that are ephemeral based on ephemerality conditions I set that are private or sharable such that I could pass working knowledge to another agent and choose to have these pages cleaned up automatically by the server, or force them to be cleaned up myself
- **A4** publish long term knowledge that is specific to a project which could be linked to a github repo, a longer term project identifier, an area (think PARA organization methods), task or otherwise (not exhaustive).
- **A5** have pages assigned different types like "knowledge", "procedure", etc. It should be extensible, but focused on what the page is, not what it contains. The list types should be kept short and creating a new type shouldn't happen on the fly to protect against sprawl. 
- **A6** related pages to other pages (linking) and have those links automatically updated when a linked page has its name changed.
- **A7** analyze and use the graph of linked pages
- **A8** get suggestions of related pages that might be worth linking to a given page both on demand and when publishing so that they can be added from creation. Related page suggestions should have a high confidence in their relevance so that link sprawl is kept to a minimum. The wiki must be well curated. 
- **A9** use an index of pages based on a topic, type, or other primitive that I may optionally filter
- **A10** have page content/syntax/formatting/etc  modifications and creations verified on each write so that it fails with helpful messages about why so that I may correct them. Malformed pages must not be written. Verified links, verified syntax, verified attributes, etc. 
- **A11** be able to access these resources via API and MCP
- **A12** have up to three relevant pages surfaced to me when the human prompts me
- **A13** have instructions in my context that clearly instruct me how to use these capabilities and when
- **A14** be able to offload general knowledge, working memory, short-term (temporary) memory to this service and not have them necessarily committed to the repository that I may or may not be working on. 
- **A15** have all of these pages versioned and be able to use the version history
- **A16** be able to mark a page as inaccurate with a reason and have that be optionally filtered out of searches, suggestions, etc. 

As a human:
- **H1** be able to view the data in a web based view
- **H2** be able to search like the agent, while being able to do things like "search for <topic> in what we know about <repo> git repository", etc
- **H3** be able to gate updates to widely accessible information (global knowledge for all agents and others that are available to multiple agents) based on an analysis, agent permissions, fact check, etc gate. This should help us enforce a well structured wiki. These should be enforceable based on different parameters such as type, tag, or other schema properties. 
- **H4** See activity per agent for auditing
- **H5** See the change history for a page that includes what changed, who/what changed it, and when.
- **H6** Rollback changes to items. 
- **H7** Restrict agents to read only access to all or parts of the wiki

This is my list for now, but it's just a start. Not all of these things need to exist right away, or even maybe at all. We're still workshopping. THey'd all have differing priorities for implementation.

I did not write user stories for the librarian role.
- optionally being able *(cut off mid-sentence; see open questions)*

## Stories added later by the creator

Recorded as written, with the date.

- **A17** (2026-10-31) If a session that created or modified a page is still active, its prompt hooks should surface the pages that need correction or attention as soon as they’re available so they stand a god chance of getting fixed while the context they were created in is still active.

---

Everything below this line is a **proposal from Claude** for discussion. Nothing in it is agreed until it moves into the seed list or is marked accepted.

## Decisions so far

Taken from the answers in [Open questions](#open-questions).

- **D1** One human (Q1). The only human role is owner; reviewer and reader roles are deferred.
- **D2** The librarian is a responsibility of the service, made of several automatic, always-on parts, not one agent (Q2).
- **D3** (revised 2026-11-01, see D35) Pages are organized by space, topic and type. Area and project are deferred. The original five dimensions (space, area, project, topic, type) are in this file's history (Q5, Q7).
- **D4** Removed pages are tombstoned first: hidden from agents, still visible to the human for a while, purged later (Q9).
- **D5** **The storage backend is open.** Don't assume git. Versioning, history, diffs and rollback (A15, H5, H6) are features the service provides, whatever it stores pages in (Q9). DESIGN.md assumed git and needs revisiting on this point.
- **D6** Only the owner creates page types; the librarian may suggest them. Each type gets a written definition used to judge pages (Q12).
- **D7** Links to pages that don't exist yet are allowed. They appear in the graph, and near-duplicate names get reconciled (Q13).
- **D8** "Inaccurate" flags: the human and the librarian can hide or fix a page immediately; an agent can only flag it with a reason. The librarian reviews flags and escalates to the human what it can't settle. It decides whether to hide the page meanwhile (Q17).
- **D9** One type per page. A page that seems to be two types is split (Q23).
- **D10** Each type definition has: a one-sentence definition; what belongs and what doesn't, compared with the nearest other type; required fields; one good and one bad example (Q24).
- **D11** Tombstone retention is configurable. Defaults: 30 days for temporary pages, 1 year for retired knowledge. Purging a temporary page also removes it from version history by default; that is configurable too (Q25).
- **D12** A link name that nearly matches an existing page or alias fails the write with "did you mean". Problems are fixed at write time wherever possible, not left for later cleanup (Q26).
- **D13** A page with an unreviewed "inaccurate" flag is shown with a warning by default; configurable to hide instead. The flagging agent isn't notified of the outcome but can look up the flag's status (Q27).
- **D14** The librarian's AI work goes through API endpoints, local or hosted. Anthropic-style and OpenAI-style APIs first, others such as Bedrock later. Later still, it may drive an agent harness (for example Claude Code over its JSON stream) so subscriptions can be used (Q28).
- **D16** The service never changes what a writer sends. Every problem fails the write with a precise fix, and the writer applies it (Q30).
- **D17** Pages may be edited directly on disk, like editing a database by hand. It is an administrative back door, not a normal path, and the editor is responsible for mistakes. A background process eventually finds errors and flags the page. The editor can ask the service to check a page, or tell it the page changed. This doesn't need to be a first-class feature (Q31).
- **D18** Policies are set per space, with sensible defaults (Q32).
- **D19** To start, a client identifies itself with a client ID from a config file in its repository. The file also names the server and settings. A cryptographically secure identity can come later (Q3).
- **D20** Temporary pages expire on a time limit, or when their owner deletes them. Other conditions can come later (Q8).
- **D21** ~~ Sharing to start: the owner marks a temporary page as shareable and sends another agent its unique identifier; any agent holding the identifier can read it (Q10).~~ *Superseded by D42.*
- **D22** (revised after review, Q42–Q45) Writes are gated in three named layers:
  - **Structure:** always a hard gate. Malformed writes fail (A10, D16), as do near-miss link names (D12).
  - **Vocabulary:** new types (D6) and new topics are hard-gated to the owner, with the librarian proposing them.
  - **Content review:** soft by default. Changes land immediately and every result carries the page's status. Hard gates stay available per space (H3), with one on by default: in the public space, pages written from untrusted input wait for a check before agents can see them.

  Three safeguards come with the soft layer:
  - **Stable revision:** each page keeps a pointer to its last reviewed revision, which readers filtering for reviewed content get while a newer edit waits.
  - **Safer surfacing defaults:** the suggestion hook (A12) and default search leave out pages with an `inaccurate` or `untrusted-input` problem, and the hook favours pages that are at least checked. Agents can opt in to everything when searching on purpose.
  - **Backlog watch:** the review backlog (how many pages wait, and for how long) is reported, with an alert past a configured limit.

  The original D22 ("no hard gates by default") is in this file's history.
- **D29** Pending topics (Q46). A page may name a topic that doesn't exist yet; the write succeeds and the topic joins a pending queue with a count of the pages that want it. A pending name that nearly matches an existing or pending topic still fails with "did you mean" (D12), so variants don't pile up. The librarian groups pending topics and proposes, in batches, to create, merge into an existing topic, or reject; the owner decides. When a topic is approved or merged, the pages that named it are updated to the final name. When it is rejected, the librarian retags those pages to the closest existing topic itself (Q47). The service also suggests existing topics to the writer, on demand and when publishing, with the same high-confidence bar as link suggestions (A8).
- **D23** The client config file holds no secret; the token lives in an environment variable or the keychain. Harness and session are recorded as unverified labels next to the client ID (Q33).
- **D24** ~~ Agents that receive a shared temporary page can read it but not edit it. The owner can revoke a share (Q34).~~ *Superseded by D42.*
- **D25** What the librarian may do afterwards to a bad page in a widely shared space is configurable. By default it may hide the page, change its status, revert the change, or mark the page for update by its writer with notes about what is wrong (Q35).
- **D26** Status is as simple as it can be without losing function (Q36). Folding it into one word went too far: review status must survive a page being hidden or retired (Q40).
- **D27** A failed write gets a clear description of each problem. The writer fixes everything except minor syntax, for which the service may suggest the exact change (Q37).
- **D28** The first version is the five bundles in the Q22 proposal (Q22).
- **D30** Status v3 uses five lifecycle values: `active`, `superseded`, `deprecated`, `hidden`, `tombstoned` (Q48).
- **D31** A writer learns about `update-requested` problems on its pages both ways: listed in the session-start brief for its client, and through a query. Any agent using the same client ID may make the fix (Q38). A still-active writing session hears sooner, through its prompt hook (A17, proposal below).
- **D32** A librarian revert undoes only the bad change, keeping later edits (Q39). If later edits conflict with the revert, the latest writer gets an `update-requested` problem describing the bad change and the conflict (Q49).
- **D33** A factual page without sources is not rejected. It lands with an `unsourced` problem, in every space (Q16).
- **D34** A17 as described in the accepted section "Telling the writing session while it's still active": a still-active session is told, through its prompt hook, about problems on pages it wrote or changed. Notices come on top of the three suggested pages, with their own cap (Q50). Not for pages it only read (Q51), nor for temporary pages it shared (Q52).
- **D35** (2026-11-01) Two kinds of space for now (Q7):
  - **public:** knowledge shared with every agent, on any subject.
  - **repo:** one space per git repository, for knowledge specific to that repo.

  Every repo space also has **working memory**: temporary pages agents can write, share and let expire (A3, A14, D20, D21). Area, project, task, private and per-agent spaces are deferred.
- **D36** A page belongs to exactly one space (Q6). With D35, that means the public space or one repo space.
- **D37** Link suggestions are never added automatically; the writer or the librarian accepts them (Q14). There is no cap on links per page (Q15).
- **D38** Read-only and no-access rules apply to whole spaces only, to start (Q21).
- **D39** A repo space is identified by the ID in the repo's config file (D19), not by its remote URL or commit history (Q53). Renaming or moving a repo doesn't change its space. See Q58 for forks.
- **D40** "Public" means visible to all of the owner's agents. Nothing is published outside (Q54).
- **D41** Any agent can read any repo's space, so it can answer "what do we know about repo X" (H2). Space rules (D38) can restrict that. An agent writes only to the public space and its own repo's space (Q55).
- **D42** Sharing identifiers for temporary pages are dropped (Q56). Working-memory pages are readable by every agent like the rest of their repo's space (D41), so there's nothing to share. This supersedes D21 and D24 and drops G20. A3's "private or sharable" choice no longer applies; see Q59.
- **D43** Working memory exists only inside repo spaces. An agent working outside any repo has none (Q57).
- **D15** Preference: pages are simple files that are easy to use elsewhere. Other storage is acceptable only if it gives clearly better semantics (Q29).

## Proposal: storage (after D5, D11 and D15)

Three of the answers pull against each other: plain files (D15), no git assumption (D5), and temporary pages purged from history by default (D11). Purging from git history means rewriting it, which is slow and breaks clones. So:

| Data | Where it lives | History |
|---|---|---|
| **Durable pages** | Plain markdown files with frontmatter, in a normal directory tree, usable by Obsidian, editors and grep | A version store owned by the service, behind an interface. Git is one implementation; a content-addressed store is another. Rollback, diffs and per-agent activity (H4–H6) come from this interface, not from the backend's own tools |
| **Temporary pages** (working notes, handoffs, scratch) | A separate area with its own retention, outside the durable tree and its history | Kept only until purge; purging deletes them outright, so nothing needs rewriting |
| **Derived data** (search index, embeddings, link graph, wanted-pages counts, indexes and hubs) | A rebuildable side store | None; rebuilt from the pages |
| **Audit log** (who did what, flags, gate decisions) | Append-only log owned by the service | Is the history |

Direct edits to the files skip the write checks. Per D17 that is accepted as an administrative back door, caught afterwards by L24.

## Proposed: roles beyond the three user types

The three user types hold up as *personas*. Permissions, though, are better attached to **roles**, because one persona can need very different rights. Candidates:

| Persona | Role | Why it may need to be separate |
|---|---|---|
| Human | **Owner / admin** | Changes policy, types, permissions, the source registry. Can roll back anything |
| Human | ~~Reviewer~~ (deferred, D1) | Approves gated changes (H3) without being able to change policy. Matters only if more than one human is involved |
| Human | ~~Reader~~ (deferred, D1) | Web view and search only (a family member, a collaborator, a public mirror) |
| AI agent | **Trusted agent** | Normal read and write within its scopes |
| AI agent | **Quarantined agent** | A session that read untrusted input (web pages, email, files from strangers). Its pages carry an `untrusted-input` problem. In the public space they wait for a check before agents can see them (D22); elsewhere they land with the label unless that space's policy gates them |
| AI agent | **Subagent** | A short-lived child of another agent. Inherits the parent's identity and scope, or gets a narrower one? |
| Librarian | **Curator** | Merges, splits, renames, links, promotes, archives |
| Librarian | **Verifier** | Fact-checks claims. Must be a *different* identity from whoever wrote the page, so nobody grades their own work |
| (new) | **Service / integration** | Non-LLM writers: an ingest pipeline that drops raw sources, CI that posts build facts, an RSS or release-feed watcher, an importer for iirc or an Obsidian vault |
| (new) | **Auditor** | Read-only access to the activity log and history (H4, H5) without access to page content in private spaces. Possibly just a human role |

## Proposal: how the librarian is built (after Q2)

The librarian is a role the service plays, made of three kinds of parts:

| Kind | Runs | Examples | Uses an LLM? |
|---|---|---|---|
| **Gatekeepers** | Synchronously, on every write | Schema and syntax checks, link resolution and "did you mean" for near-miss link names, type rules, secret scan, permission and gate checks | No. Deterministic, fast, explainable error messages (A10) |
| **Event workers** | Asynchronously, right after something happens | Review a gated change, verify a new page's sources, triage an "inaccurate" flag, propose links for a new page, reconcile a new wanted-page name | Yes, where judgement is needed |
| **Sweepers** | On a schedule | Expire ephemeral pages and purge old tombstones, check sources for drift and dead links, find duplicates and contradictions, rebuild indexes, write the digest | Mostly no. LLM only for duplicate and contradiction judgement |

Principles:

- **Deterministic first.** Anything a rule can decide, a rule decides. LLM workers handle judgement only, and their outputs are proposals or reversible actions.
- **Each part has its own identity** (for example `librarian/gatekeeper`, `librarian/verifier`, `librarian/curator`), so the audit log (H4) shows which part did what, and the verifier is never the page's writer.
- **No back door.** LLM parts act through the same API as agents, with elevated but capped permissions: bulk-edit limits, no policy or type changes, no approving their own proposals.
- **Pluggable models.** Each LLM worker names the model it runs on, so cheap local models can do triage and stronger ones do verification.

## Accepted: telling the writing session while it's still active (A17, D34)

A page is most likely to get fixed while the session that wrote it still has the context. So the service tracks which session wrote or changed each page, and pushes problems back to that session while it lives.

- **Who gets told:** the session recorded on the write (D23's session label), for pages it created or changed. If that session has ended, it falls back to D31: the client's session-start brief, or a query.
- **What counts as needing attention:** any new problem on the page (`update-requested`, `unsourced`, `inaccurate`, `disputed`, `source-changed`, `invalid-hand-edit`), and the page being hidden, deprecated or reverted. Only pages the session wrote or changed, never pages it merely read (Q51). Temporary pages it shared get no notices (Q52).
- **How it arrives:** on the session's next prompt, the prompt hook adds a short notice ahead of any suggested pages. Each line gives the page, the problem and the librarian's note: `wiki: 1 page you wrote needs attention: uv-pip-needs-a-venv (unsourced: claim 2 has no source)`. Each problem is shown once, then again only if it's still open after a set number of prompts.
- **How the session is known to be alive:** every hook call reaches the service, so a session counts as active while its hooks keep calling. No separate heartbeat is needed.
- **Speed matters:** checks on pages whose writing session is still active go to the front of the librarian's queue (L31), so problems arrive while the context is still there.
- **Budget:** these notices come on top of the three suggested pages (A12), with their own cap: by default at most 3 notices per prompt, each shown once and then again only if still open after 5 prompts. Both numbers are configurable (Q50).

## Proposal: client config and identity (after D19)

A file in each repository, for example `.wiki/client.toml`:

```toml
server  = "https://wiki.example.ts.net"   # where the service is
client  = "homelab"                       # client ID, shown in the audit log (H4)
repo    = "homelab"                       # which repo space this repo maps to (D36, Q53)
# No secrets in this file. The token comes from an environment variable or the OS keychain.
```

- **Keep the credential out of the file.** The file gets committed, so if the client ID ever becomes a credential it would leak into git history. Keep the ID a public label and put the secret elsewhere from day one.
- **Record more than the client ID.** One ID per repo means every agent working in that repo looks the same in the audit log. Each write would therefore also record the harness (claude-code, codex) and session as self-reported labels. They are useful for auditing but not trusted for permissions until identity is cryptographic.

## Proposal: the status every result carries (v3, after Q40)

v1 (three fields) and v2 (one word) are in this file's history. v2 lost facts that must survive together: a page hidden or retired after review should still say it was reviewed (Q40).

v3 **stores** three independent facts and **derives** a one-line summary from them for display. Nothing is lost, and agents still get something they can read at a glance.

| Stored field | Values | Changes when |
|---|---|---|
| `state` (exactly one) | `active` · `superseded` · `deprecated` · `hidden` · `tombstoned` | `superseded`: replaced by another page, named in the reasons. `deprecated`: no longer right, no replacement. `hidden`: withheld from agents, for example pending review of a flag. `tombstoned`: removed and awaiting purge (D4, D11). Does **not** touch review (D30) |
| `review` (exactly one) | `unreviewed` · `checked` · `reviewed` | The librarian's verifier checks it (`checked`) or the human does (`reviewed`). Resets to `unreviewed` only when the **content** changes, never on a state change |
| `problems` (zero or more) | Each one is `{kind, reason, by, at}`. Kinds: `inaccurate`, `disputed`, `source-changed`, `untrusted-input`, `invalid-hand-edit`, `update-requested`, `unsourced` | Added by agents (`inaccurate` only), the librarian or the gatekeeper. Removed when resolved, and the resolution goes into history |
| `reviewed_rev` | The revision id the latest `checked` or `reviewed` applies to, or empty | Set with each review. Lets a filter for reviewed content return that revision when the newest one is unreviewed (D22) |

`update-requested` is the librarian's "mark for update by the writer with notes" (D25). It is a problem kind rather than a state because the page stays visible while it waits.

**Derived summary** (computed, never stored), e.g. `active · reviewed · 1 problem (inaccurate)`, `superseded · reviewed` or `tombstoned · checked`. Search results show the summary. Reads and filters use the stored fields: for example, "active, at least checked, no open problems".

## Draft: librarian stories (v1, revised after the first answers)

As the librarian, I want to:

**Curation and structure**
- **L1** review every draft and gated change (H3) against the schema, the type rules and duplicate checks, and approve, request changes with a reason, or reject.
- **L2** detect near-duplicate pages and propose a merge that keeps one uuid, records `merged_from` and leaves a redirect.
- **L3** split pages that grow past the size budget or cover two subjects, keeping links valid.
- **L4** own the topic and type vocabularies: propose new types or topics to a human with evidence (how many pages would use them, what they overlap with), and never create one myself (A5).
- **L5** keep links healthy: fix broken links, rewrite links after renames (A6), retire unused redirects, and report orphans.
- **L6** decide which suggested links (A8) are worth adding when an agent didn't add them, so the graph stays curated rather than dense.
- **L7** regenerate indexes and topic hubs (A9) after changes land.

**Lifecycle**
- **L8** promote repo knowledge to the public space when it proves general (useful in a second repo, no repo-specific paths), generalizing the text and leaving a pointer behind in the repo space.
- **L9** enforce ephemerality (A3): when a page's conditions are met, tombstone it (D4): hide it from agents, keep it visible to the human, and purge it after a retention period. Tell the owning agent first if it is still active.
- **L10** consolidate working memory into long-term pages at the end of a task, on a branch, for review, never by silently rewriting pages.
- **L11** archive stale or superseded pages instead of deleting them; tombstone only what is truly unwanted.

**Trust**
- **L12** run verification passes: check that sources still say what pages cite them for, find dead links, flag pages whose software versions have moved on.
- **L13** find contradictions between pages and open a discussion instead of choosing a winner.
- **L14** triage "inaccurate" flags from agents (A16, D8): check the stated reason against sources, then fix the page, confirm and hide it, reject the flag with an explanation, or escalate to the human. While a flag waits for the human, decide whether to hide the page, and always show a "flagged" warning on it in results.
- **L15** spot unusual agent behaviour (bursts of writes, mass "inaccurate" reports, edits to many pages from one untrusted session) and quarantine that agent's pending changes for a human.

**Reporting and policy**
- **L16** give the human a periodic digest: what changed, what's waiting for review, what's suspect, health numbers (orphans, duplicates, unverified share, search quality).
- **L17** propose changes to agent instructions (A13) and the schema when I see the same mistake repeatedly, for a human to approve.
- **L18** run schema migrations across all pages when the schema changes, in reviewable batches.
- **L20** reconcile wanted pages (D7): when different pages link to targets that mean the same thing under different names, pick one name, rewrite the links or record the variant as an alias, and keep a count of how many pages want each missing page.
- **L21** propose creating a wanted page once enough pages link to it, with a draft built from what the linking pages say about it.
- **L22** keep type definitions (D6) applied: flag pages that don't fit their type's definition, and gather evidence when a new type might be warranted.
- **L23** run my AI work through the configured providers (D14), with a model chosen per job, so cheap or local models do triage and stronger ones do verification, and report what each job cost.
- **L24** notice changes made directly to the files (D17), validate them like any write, and flag any that fail so agents see the problem in the page's status. Offer the human an administrative command to check a page now or report that it changed.
- **L25** send a bad page back to its writer (D25): add an `update-requested` problem with notes saying what is wrong and what a fix looks like, and follow up if it isn't fixed within a configured time.
- **L26** revert a bad change, or hide a page, when a space's policy allows it (D25), with a reason recorded and the human able to undo my action. A revert undoes only that change and keeps later edits (D32); if later edits conflict with the revert, I give the latest writer an `update-requested` problem describing the bad change and the conflict (Q49), and follow up as in L25.
- **L27** watch my own review backlog (D22): report how many pages wait for a check and for how long, include it in the digest, and alert the human when it passes the configured limit.
- **L28** check pages held by the public space's untrusted-input gate (D22) first, so they don't sit invisible for long.
- **L31** check pages whose writing session is still active ahead of others (A17), so any problem reaches that session while it still has the context to fix it.
- **L29** batch pending topics (D29): group near-identical requests, gather what the pages that want each topic have in common, and put create, merge and reject proposals to the human in batches, with my recommendation for each.
- **L30** apply topic decisions (D29): when a pending topic is approved or merged, update every page that named it; when it is rejected, retag the pages to the closest existing topic myself (Q47), recording the change and the reason in each page's history.
- **L19** have every action I take be attributed to me, reversible, and within limits a human set, so I can't approve my own policy changes or bulk-edit without a cap.

## Proposed: stories that seem to be missing

These came up when reading the seed list against DESIGN.md. Accept, reword or drop.

- **G1 (agent) Ingest:** add a raw source (article, PDF, transcript, web clip), have it stored unchanged, and file a summary plus updates to related pages. This is the core of Karpathy's pattern and isn't in the list yet.
- **G2 (agent) File answers back:** save a good answer to a question as a new page, with its sources.
- **G3 (agent) Atomic multi-page writes:** an ingest touches 10–15 pages; either all of them land or none do.
- **G4 (agent) Edit conflicts:** if another agent changed a page since I read it, my write fails with the difference so I can merge, instead of silently overwriting.
- **G5 (agent) Watch:** be notified (or told at session start) when pages I depend on change or are marked inaccurate.
- **G6 (agent) Feedback on suggestions:** say "this suggestion wasn't useful" so the suggestion threshold can be tuned (A8, A12).
- **G7 (agent) Ask:** leave a question for a human on a page's discussion thread when I can't verify something.
- **G8 (human) Edit in the web view,** not only read (H1).
- **G9 (human) Review queue:** one place showing everything waiting on me: gated changes, disputes, inaccurate reports, new types or topics.
- **G10 (human) Bulk rollback:** undo everything one agent did since a given time (H6), not just one page.
- **G11 (human) Import and export:** bring in existing iirc pages and Obsidian notes; export everything as plain markdown.
- **G12 (human) Privacy:** make sure private pages never reach agents or indexes that shouldn't see them, and permanently remove something (a secret, personal data) from history when needed.
- **G13 (human) Backups and restore.**
- **G14 (human) Browse the graph** visually.
- **G15 (agent) Follow a link to a page that doesn't exist yet** and get a useful answer: the pages that link to it, what they say about it, existing pages with similar names, and a way to create it.
- **G16 (human, agent) Read the type definitions** (D6) as pages in the wiki, so agents can check what a page should be before writing it, and the validator and librarian judge pages against the same text.
- **G17 (human) Restore a tombstoned page** before it is purged (D4).
- **G18 (agent) Check the status of a flag I raised** (D13): pending, fixed, hidden, rejected with a reason, or escalated.
- **G24 (agent) Be told in my current session** when a page I wrote or changed in this session gets a problem, on my next prompt, with the librarian's note, so I can fix it while I still have the context (A17).
- **G21 (agent) Learn which of my client's pages need an update** (D25, D31), with the librarian's notes, from my session-start brief or by asking, so I can fix them even if another session wrote them.
- **G23 (agent) Get topic suggestions** for a page, on demand and when I publish: a few existing topics that clearly fit, so I reuse them instead of inventing new ones (D29).
- **G22 (agent) Opt in to everything** when I search on purpose, including flagged, untrusted-input and unreviewed pages, with their status shown, for example when investigating a disputed claim.
- **G20 (agent) ~~ Revoke a share** of a temporary page I own, so the identifier stops working before the page expires.~~ *Dropped with D42.*
- **G19 (human) Change policies in one place:** retention, flag visibility, gates, type definitions, provider and model choices. Policy changes are versioned like pages, so they can be audited and rolled back.

## Open questions

Answers go here as they are settled, with the date.

**Roles and scope**
- **Q1** How many humans will use this? Just you, or family or collaborators? This decides whether Reviewer and Reader roles matter now.
  - **Answer (2026-10-31):** Just one human.
- **Q2** Is the librarian an LLM agent with extra rights, a deterministic service (scripts and jobs), or both? Can there be more than one librarian (for example one per area)?
  - **Answer (2026-10-31):** It could be part of the service, or a separate agent, but should be automatic and constant. It's more the responsibility of the service itself conceptually and could be several different things that make up a conceptual "librarian". Thoughts?
- **Q3** Should agents be identified per harness (claude-code), per harness per machine (claude-code@nas), or per session? Per session gives the best audit trail (H4) but makes permissions harder.
  - **Answer (2026-10-31):** I'm not settled on the answer to this, but I think by some kind of client ID maybe? Say a config file in a repository that the client uses to identify server, settings, and its ID. Eventually this could be a cryptographically secure ID but probably not to start.
- **Q4** Your last line, "- optionally being able", was cut off. What was it going to say?
  - **Answer (2026-10-31):** I don’t remember show me the surrounding text

**Organization (A2, A4, A9)**
- **Q5** "Knowledge base section", "topic", "area", "project", "personal" and "type" overlap. Which are separate dimensions? A proposal: *space* (who can see it: global, private, project, agent), *area* (PARA long-running responsibility, e.g. homelab, health), *project* (has a goal and an end, may map to one or more git repos), *topic* (subject), *type* (what the page is). Does that match how you think about it?
  - **Answer (2026-10-31):** Yes, I think thats a good consolidation.
- **Q6** Can one page belong to several projects or areas, or exactly one?
  - **Answer (2026-11-01):** a page belongs to only one space, project, area or other
- **Q7** How should a project be identified when it spans several repos, or a repo holds several projects (monorepo)?
  - **Answer (2026-11-01):** lets simplify the whole structure: we have a public space, and a repo space only for right now. We still have a short term or “working memory” feature available to agents by repo.

**Ephemeral pages and working memory (A3, A14)**
- **Q8** Which ephemerality conditions do you want? Candidates: a time limit, idle time, task closed, session ended, read once by the recipient, or the owner deletes it.
  - **Answer (2026-10-31):** I think time limit and owner deleting it to start.
- **Q9** When an ephemeral page is cleaned up, should it be gone from version history too, or just hidden and kept for audit? Keeping everything in git makes "cleanup" mean "hidden"; truly deleting means ephemeral pages shouldn't live in git at all.
  - **Answer (2026-10-31):** Maybe something like tombstoned so that it's around for a while, but mostly invisible and maybe accessible by the human so they can view the history. Unsure on the specifics, but not immediately gone to parts of the application. Don't assume our backing is git.
- **Q10** "Sharable" with whom: a named agent, any agent on the same task, project or area?
  - **Answer (2026-10-31):** To start any agent, perhaps it marks it as accessible to others then can send them a unique identifier they can use to access it.
- **Q11** In A14, "not committed to the repository I'm working on" means the project's code repo, right? The wiki's own store would still be versioned (A15).

**Types (A5)**
- **Q12** A starting list focused on what a page *is*: knowledge (facts about something), procedure (how to do something), decision (what was chosen and why), reference (lookup material), source (summary of an ingested item), working note (ephemeral), topic (hub). What's missing or wrong? Who approves a new type: only you?
  - **Answer (2026-10-31):** I'm not sure of the starting types, although that seems like possibly a good starting list. I'd want to continue refining this as we get crisper with this. Good start. Specific list still open. Creating a type should be gated by me, although I'll take suggestions when it makes sense. Should a page be able to be of multiple types? I'd want to write clear definitions of what each type should be to use as a way to evaluate what a page should or shouldn't be.

**Links and suggestions (A6, A7, A8)**
- **Q13** Should a page be allowed to link to a page that doesn't exist yet (Wikipedia's "red links", which show what's missing)? Or must every link resolve on write (A10)?
  - **Answer (2026-10-31):** I think that linking to a page that doesn't exist yet is ok as long as we have a process for making sure that the links remain similar when they're created indepenently, e.g. if two agents want to link to a page that should be the same but name it slightly differently we should correct for that. These links should also show up in the graph so that we can see how many pages link to it and maybe take some action like creating that page. It should probably also be ok for a bunch of pages to link to a non-existent page and have that be ok. Following that link may just result in returning an index of pages that link to it, although that is just a casual thought.
- **Q14** Should high-confidence link suggestions ever be added automatically, or always need the writer or librarian to accept them?
  - **Answer (2026-11-01):** no
- **Q15** Is there a rough cap on links per page you'd consider sprawl?
  - **Answer (2026-11-01):** no cap

**Write validation (A10)**
- **Q16** How strict is "malformed": should a write with a missing source on a factual claim be rejected, or accepted as a draft with a warning?
  - **Answer (2026-10-31):** flagged

**Inaccuracy (A16)**
- **Q17** Who can mark a page inaccurate: any agent, or only trusted ones? Does it hide the page immediately, or only after the librarian or a human confirms? Hiding immediately lets one misbehaving agent hide good pages.
  - **Answer (2026-10-31):** A human, librarian, or an agent. A human and a librarian should be able to make hidden immediately, or fix it so that it is accurate. An agent should be able to flag it as innacurate with a reason and then have that reviewed by a librarian next. If the librarian can't handle it, then it could be escalated to a human. The librarian can choose whether to hide it or not while it is pending human review.
- **Q18** Are "inaccurate", "outdated" and "disputed" different states for you?

**Gating (H3, H7)**
- **Q19** Which changes must wait for a gate, and which can land immediately? For example: new shared pages gated, edits to existing shared pages not; certain types or tags always gated.
  - **Answer (2026-10-31):** I think to start, and by default, no hard gate but consumers should always know its status so they can use that when reasoning about the information.
- **Q20** Who passes the gate: you, the librarian, or automated checks alone, depending on the rule? How long can an agent wait for approval before it gives up?
- **Q21** At what granularity do read-only and no-access rules apply: space, area, topic, type, tag, or single page?
  - **Answer (2026-11-01):** start with space only

**Raised by the first answers**
- **Q23** One type per page, or several? Proposal: exactly one. A page that seems to be two types is usually two pages and should be split; area, topic and project already cover the other ways to group it. Agree?
  - **Answer (2026-10-31):** yes, I agree
- **Q24** What should a type definition contain? Proposal: a one-sentence definition, what belongs, what doesn't (with the nearest other type), required fields, and one good and one bad example.
  - **Answer (2026-10-31):** yes, I agree
- **Q25** Tombstone retention: how long before purging, and should it vary? For example 30 days for ephemeral pages, 1 year for retired knowledge. Should purge also remove the page from version history?
  - **Answer (2026-10-31):** It should be configurable, those seem like reasonable defaults. Purging temporary pages should be removed from version history by default, but that should be configurable.
- **Q26** At write time, if a link target closely matches an existing page or alias, should the write fail with "did you mean X?" (strict, A10) or succeed and let the librarian reconcile later?
  - **Answer (2026-10-31):** Fail. Fix on write wherever we can.
- **Q27** While a page carries an unreviewed "inaccurate" flag, should agents still see it, with a warning? Should the flagging agent hear the outcome?
  - **Answer (2026-10-31):** Yes, see it with a warning by default. This should be configurable though. See with a warning or hide. The agent that flagged it does not get notified of the outcome. It should be able to check the status though, I think?
- **Q28** Any budget for the LLM parts of the librarian: model choice, local vs API, a monthly cost ceiling?
  - **Answer (2026-10-31):** It should use AI through popular APIs and support both local and hosted because they're just an API endpoint. Anthropic and OpenAI style interfaces should be supported to start. Maybe bedrock or others in the future. In the future it might be nice to be able to drive an agent harness for this work so that subscriptions could be used. e.g., driving claude code via json stream.
- **Q29** Since the backend is open (D5), does any of these matter: editing pages with ordinary tools (Obsidian, a text editor, grep) on a local copy; offline access; or is "only through the API and web view" fine?
  - **Answer (2026-10-31):** My preference would be that they're simple files easily used elsewhere, but I will entertain other options that provide different/better semantics if it's worth it.

**Raised by the second answers**
- **Q30** "Fix on write wherever we can": does that mean (a) the service fixes safe, unambiguous problems itself and reports what it changed (for example normalizing a date, quoting a timestamp, rewriting a link that exactly matches an alias) and fails only on problems that need judgement; or (b) the service never changes what was sent, and every problem fails the write with a precise fix for the writer to apply?
  - **Answer (2026-10-31):** (b), the writer should apply it
- **Q31** If pages are plain files, may you (or a tool such as Obsidian) edit them directly, outside the API? If yes, the service has to notice those edits and check them afterwards, quarantining bad ones (L24). If no, files are a read-only export, and every change goes through the API or web view.
  - **Answer (2026-10-31):** Yes, but this shouldn't be the norm. It should be possible, but similar to editing a database by hand. If something gets screwed up, it's the editors responsibility not to do that. A process should eventually see the errors and flag the page, though. And the human editor should have a way to check the page after they write it and/or notify the service that it has been changed. This does not have to be a first class feature since it's more of an administrative back end thing.
- **Q32** Is one policy configuration for the whole wiki enough, or do you want overrides per space (for example stricter gates on the global space, looser rules in agent spaces)?
  - **Answer (2026-10-31):** overrides per space, or rather different policies per space with sensible defaults

**Raised by the third answers**
- **Q33** Are you OK with the config file holding no secret, and the token living in an environment variable or the keychain? And with recording harness and session as unverified labels next to the client ID?
  - **Answer (2026-10-31):** yes split ok
- **Q34** Can an agent that receives a shared temporary page only read it, or also add to it (a handoff often needs a reply)? Can the owner revoke a share (G20)?
  - **Answer (2026-10-31):** no edits. Yes can revoke.
- **Q35** With no hard gates, what may the librarian do afterwards to a bad page in a widely shared space: only change its status, hide it, or revert the change?
  - **Answer (2026-10-31):** configurable but by default hide, change status, revert, mark for update by the writer with notes about what is wrong.
- **Q36** Is the three-field status (review, alerts, lifecycle) small enough, or should it be simpler still?
  - **Answer (2026-10-31):** lets simply to the simplest without compromising function
- **Q37** With D16, should a failed write's error include the corrected text or a ready-made patch, so the writer can apply the fix in one step?
  - **Answer (2026-10-31):** clear description of the issue but the writer should fix anything that isn’t minor syntax. Syntax change suggestions are ok.

**Raised by the fourth answers**
- **Q38** How does a writer find out its page has an `update-requested` problem? Options: listed in the session-start brief for that client; a query the agent runs; both. If the writing session is long gone, may any agent using the same client ID make the fix?
  - **Answer (2026-10-31):** both and any with the same id
- **Q39** When the librarian reverts, does it undo just the bad change, or roll the page back to its last good version (which also drops any later edits)?
  - **Answer (2026-10-31):** just bad change
- **Q40** Does the single status word in v2 work for you, or is something missing?
  - **Answer (2026-10-31):** I think the status collapse goes too far. If a page gets hidden or retired we lose the context about review status for example

- **Q41** Does v3 (stored state, review and problems, plus a derived summary) fix the problem without being too complex?

**Review of D22, "no hard gates" (2026-10-31)**

Claude reviewed D22 at the creator's request. Findings: D22 already coexists with hard gates on structure (A10, D16), link names (D12) and types (D6); a content edit resets review, which hides good pages from careful readers; the suggestion hook (A12) pushes unreviewed pages into context without the agent choosing; teaching every agent to read status (A13) is unproven; and a stalled librarian lets unreviewed content pile up unnoticed.

- **Q42** Name three gate layers explicitly: structure (always hard), vocabulary (types and new topics, hard-gated to the owner with the librarian proposing), content review (soft by default, hard per space)?
  - **Answer (2026-10-31):** yes
- **Q43** Keep a stable revision: a pointer to each page's last reviewed revision, served to readers who filter for reviewed content while a newer edit waits?
  - **Answer (2026-10-31):** yes
- **Q44** Safer surfacing defaults: the suggestion hook and default search leave out pages with an `inaccurate` or `untrusted-input` problem, and the hook favours pages that are at least checked; agents can opt in to everything when searching on purpose?
  - **Answer (2026-10-31):** yes
- **Q45** One hard gate by default on the global space: pages written from untrusted input wait for a check before agents can see them?
  - **Answer (2026-10-31):** yes

- **Q46** With new topics gated to the owner, may a page name a topic that is still pending (as links to missing pages already can), with the librarian grouping pending topics so the owner approves or merges them in batches?
  - **Answer (2026-10-31):** Yes add that. It should also suggest topics to the writer

- **Q47** When the human rejects a pending topic, should the librarian retag the affected pages to the closest existing topic itself, or send each page back to its writer with an `update-requested` problem?
  - **Answer (2026-10-31):** a

- **Q48** Should status v3 bring back finer lifecycle values: `active` · `superseded` · `deprecated` · `hidden` · `tombstoned`? Superseded points to a replacement while deprecated is simply no longer right, and hidden (pending review) differs from tombstoned (awaiting purge).
  - **Answer (2026-10-31):** yes

- **Q49** When undoing just the bad change (D32) conflicts with later edits to the same part of the page, what should happen: the librarian resolves the conflict itself, hands it to the latest writer as `update-requested`, or escalates to the human?
  - **Answer (2026-10-31):** B

**Raised by A17**
- **Q50** Do attention notices count against the three suggested pages per prompt (A12), or come on top with their own cap? Proposal: on top, at most 3 notices per prompt, each shown once and then again only if still open after 5 prompts.
  - **Answer (2026-10-31):** top
- **Q51** Should a session also be told about problems on pages it only *read and relied on* (for example, a page it used to make a decision is later flagged inaccurate), or only about pages it wrote or changed?
  - **Answer (2026-10-31):** not on read
- **Q52** Should the session-start brief (D31) and these notices also cover temporary pages the session shared with other agents, for example when a share is about to expire?
  - **Answer (2026-10-31):** no

**Raised by the simplification to public and repo spaces (D35)**
- **Q53** What identifies a repo space? Options: the ID in the repo's config file (D19); the git remote URL; the repo's first commit, which survives renames and forks; or a combination. And what happens when a repo is renamed or forked?
  - **Answer (2026-11-01):** ID in config file
- **Q54** Does "public" mean visible to all of your agents, or might some of it ever be published outside (a website, other people)? The name suggests the second.
  - **Answer (2026-11-01):** visible to all agents
- **Q55** Can an agent working in one repo read another repo's space, for example to answer "what do we know about repo X" (H2)? Proposal: yes, read by default, with D38 rules to restrict it; writes only to the public space and its own repo's space.
  - **Answer (2026-11-01):** yes to your proposal
- **Q56** Can a temporary page shared by its identifier (D21) be read by an agent in a different repo, or only within the same repo?
  - **Answer (2026-11-01):** since repo pages are now readable by all I don’t think we need this
- **Q57** Where does an agent's working memory go when it isn't working inside any repo (a chat with no checkout)? Options: nowhere for now; a catch-all scratch space; the public space's working memory.
  - **Answer (2026-11-01):** not supported

**Raised by the second round on spaces**
- **Q58** A fork copies the config file, so the fork and the original would share one repo space. Is that fine, should the owner change the ID after forking, or should the service warn when the same ID shows up from a different remote?
  - **Answer (2026-11-01):** C
- **Q59** With D41 and D42, every working-memory page is readable by every agent. Is that fine, or do you still want a private option for scratch notes, as A3 originally asked?
  - **Answer (2026-11-01):** everything visible is fine

**Priorities**
- **Q22** If you could only have five of these stories in the first usable version, which five?
  - **Proposal to react to (2026-10-31):** five bundles that make a usable first version on their own:
    1. **Validated writes:** A10 (write checks with precise errors, D16) plus A5 (types, starting list).
    2. **Search with filters:** A1 and A2 (keyword, fuzzy and semantic search; filter by space, area, project, topic, type).
    3. **Offload and scope:** A14 and A4 (publish general, project and temporary pages to the service, outside the code repo), with D19 client config.
    4. **History:** A15, H5 and H6 (versions, change history with who and when, rollback).
    5. **Access and instructions:** A11 and A13 (API and MCP, plus instructions in the agent's context).

    Next in line: H1 (web view), A12 (three pages surfaced per prompt), A6 (link updates on rename), A16 (inaccurate flags).
  - **Answer to the proposal (2026-10-31):** yes that five looks good.
  - **Answer (2026-10-31):** Not sure yet.
