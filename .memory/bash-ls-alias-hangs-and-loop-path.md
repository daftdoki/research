---
title: ls alias hangs in Bash tool chains; while-read loops lose PATH; fetch GitHub
  files with gh api
summary: Bare ls hangs at the end of a command chain (use /bin/ls); while-read loop
  bodies lack base64 and md5 (use Python); gh api contents beats curl to raw GitHub.
topics:
- bash
- gh
kind: environment
uuid: 1f1af178-7ff7-685a-b9bf-ef8581954663
created: '2026-09-13T02:05:02Z'
updated: '2026-09-13T02:05:30Z'
---
Two things that cost retries in the 2026-09-12 skills-lineage session, both
in the Bash tool on this Mac:

- `ls` with no path hangs past the 120 s timeout when it is the last command
  of an `&&` chain, or when its output is piped. It is an alias (eza with git
  integration, most likely). `/bin/ls` returns at once.
- Inside a `... | while read a b; do ...; done` loop, `base64` and `md5` were
  "command not found" even though both are in /usr/bin. Loop bodies run with
  a reduced PATH. Move any per-item fetching into a Python script instead.

Also useful: `curl` to raw.githubusercontent.com works but took over two
minutes for ten small files. `gh api repos/OWNER/REPO/contents/PATH --jq
.content | base64 -d` returns in a second or two, and
`?ref=SHA` reads a file at a past commit.

## Sources

- Observed on 2026-09-12 in the unslop-and-writing-for-agents-skills session: two Bash calls ending in `ls` timed out at 120 s, a `while read` loop over `gh api` output reported base64 and md5 missing, and a ten-file curl loop was backgrounded after 120 s.
