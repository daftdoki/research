---
name: research
description: Investigate a topic and land the report as a PR in this repo. Use when asked to research or investigate something, to compare options, to find out how something works, or to answer a question that needs sources.
---

# Research

One investigation, one folder, one PR. `AGENTS.md` holds the report format and
the commit rules; this skill holds the sequence and the constraints on how the
work is done.

## Portable by construction

This repo's work runs on a Mac, in a cloud VM, and later in a container. A
report is only worth committing if any of those three could have produced it,
so keep the investigation inside what all three share:

- Read public sources. Cite them.
- Leave the host as you found it. Reason about what a tool does from its
  documentation and source rather than installing it.
- Treat this machine's hardware, OS version, and local network as out of
  reach. A claim you could only make by touching them is a claim the next
  run cannot reproduce.

Write the folder and nothing else.

## Steps

**1. Settle the branch.** Already on a `claude/*` branch? Stay on it. A cloud
session starts on one the platform created, and its push protection allows
pushing only to that branch, so switching away strands the work. Otherwise
create `claude/<kebab-slug>` off main before any file exists, with the slug
describing the topic rather than the answer.

**2. Open the folder and `notes.md`.** Name the folder for the topic, in
lowercase kebab-case, matching the sibling folders. Append to `notes.md` as
you go: what you tried, what you searched, what turned out wrong. The dead
ends are the part a reader cannot reconstruct later, so they earn their
place. `_example/notes.md` shows the shape.

**3. Investigate.** Done when every claim the report will make has a source
you actually read, and every question the prompt asked has an answer or a
stated reason it has none.

**4. Write `README.md`.** Follow the format in `AGENTS.md`. `_example/README.md`
is the reference. Done when all sections `AGENTS.md` requires are present and
the Original Prompt section quotes the prompt verbatim.

**5. Dispatch the summarizer.** Call the `summarizer` subagent with the folder
path. It writes `_summary.md`. Done when that file exists and is non-empty.
Write it yourself only if the subagent is unavailable.

**6. Commit and open the PR.** Stage the folder, following the "What to
commit" rules in `AGENTS.md`. The PR body starts with `## Prompt` and the
verbatim prompt in a blockquote, per `CLAUDE.md`.

## Checks before the PR

- `README.md`, `notes.md` and `_summary.md` all exist in the folder.
- Nothing is staged outside the folder.
- No fetched third-party source tree is staged. A diff against a repo you
  modified goes in as a `.diff` file.
