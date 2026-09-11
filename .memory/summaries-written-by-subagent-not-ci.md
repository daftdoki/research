---
title: Research summaries come from a Haiku subagent, not from CI
summary: GitHub Models died in Actions; _summary.md is now written by a cold-reading
  subagent during research, and cog is deterministic.
topics:
- cogapp
- ci
- summaries
- subagents
kind: decision
uuid: 1f1ae1c3-bd05-63ce-8246-853efbff2268
created: '2026-09-11T20:06:11Z'
updated: '2026-09-11T20:06:11Z'
---
Summary generation moved out of GitHub Actions and into a `summarizer`
subagent that runs during research, before the PR is opened.

The old pipeline had cog shell out to `llm -m github/gpt-4.1` whenever a
folder lacked `_summary.md`, authenticated by the Actions `GITHUB_TOKEN`
under a `models: read` permission. GitHub changed what Actions gets from
GitHub Models and that call died. Nobody noticed for three months because
all 14 existing folders had cached summaries, so cog never took the
generating branch. It would have failed on folder 15.

Chosen over two alternatives:

- **Swapping in a paid provider key.** Smallest diff, but adds a secret to
  manage for a job that produces one paragraph.
- **Having the research agent write its own summary.** Rejected because an
  agent holding 40k words of its own report oversells it. The old `llm`
  call worked precisely because it was a cold reader.

The subagent restores the cold read with a fresh context window, pinned to
Haiku, reading only the report's H1 plus Question/Goal plus Answer/Summary.
The prompt is carried over verbatim from the cog block so the voice matches
the 14 committed summaries.

Consequences worth knowing:

- cog is now deterministic: no model, no key, no `models: read`. A folder
  without `_summary.md` is a hard error.
- The index stays generated on main rather than on the branch, because the
  generated block is ~150 shared lines and concurrent PRs would conflict.
  A `pull_request` job catches a missing summary before the merge instead.
- `extract_summary_input()` and the 20k-char cap were deleted. They existed
  only for GitHub Models' 8000-token input limit.

## Sources

- Converted on 2026-09-11, commits 567011d..2b833c0 on daftdoki/research.
- Verified green: Actions run 34642301461, 9s, installs only cogapp,
  "No changes to commit".
