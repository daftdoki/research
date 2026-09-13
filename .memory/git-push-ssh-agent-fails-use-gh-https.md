---
title: git push over SSH fails from the Bash tool; push over HTTPS with the gh token
summary: SSH agent signing fails from Bash; push with git -c credential.helper='!gh
  auth git-credential' to the https URL, then gh pr create without fetching.
topics:
- git
- gh
kind: procedure
check: gh auth status >/dev/null 2>&1
uuid: 1f1af1b7-257b-6360-b0e7-9eccf108e052
created: '2026-09-13T02:33:04Z'
updated: '2026-09-13T02:33:04Z'
---
On 2026-09-12, in the a2a-homelab session, `git push` to the SSH remote
failed three times (once with the sandbox off) with:

    sign_and_send_pubkey: signing failed for ED25519 "aaron@ SSH Key 2024" from agent: communication with agent failed

`ssh-add -l` from the tool reports "The agent has no identities", so the
key lives in an agent the tool's shell cannot talk to. `gh auth status`
showed a working token with git protocol https.

What worked, without touching the remote config:

    git -c credential.helper='!gh auth git-credential' \
      push https://github.com/daftdoki/research.git HEAD:claude/BRANCH

Then `gh pr create --base main --head claude/BRANCH ...`. Do not run
`git fetch` or `git branch -u` in the same chain: fetch goes over SSH and
fails the whole command. `gh pr create` needs no fetch.

## Sources

- Observed in the 2026-09-12 a2a-homelab-agent-communication session; PR #24 was pushed this way.
