# Who Generates the PR Text in simonw/research?

## Question

The [simonw/research](https://github.com/simonw/research) repository README states that "prompts and links to transcripts are included in the PRs." What generates that PR text — the title, body, embedded prompts, and session links?

## Answer

**The async coding agent platforms themselves generate the PR text as a built-in product feature.** It is not configured in the repository's `AGENTS.md` or `CLAUDE.md` files, which contain zero instructions about PR creation or formatting.

When Simon submits a research task to a coding agent (usually [Claude Code on the web](https://claude.ai/code)), the platform autonomously does the research, pushes to a branch, and generates a PR body that typically includes:

1. The original prompt/task verbatim
2. A structured summary of the changes
3. A session/transcript link

Different tools produce slightly different PR formats, but the mechanism is the same: the platform generates the PR text, not any repo-level configuration.

## Methodology

Examined 8 closed PRs in simonw/research across three different AI coding tools, plus the repository's `CLAUDE.md`, `AGENTS.md`, the [Claude Code on the web documentation](https://code.claude.com/docs/en/claude-code-on-the-web), and Simon Willison's [blog post on async code research](https://simonwillison.net/2025/Nov/6/async-code-research/).

## Results

### What's in AGENTS.md (the only config file)

`CLAUDE.md` contains a single line: `@AGENTS.md`. The `AGENTS.md` file contains only research methodology instructions — create a folder, write `notes.md` and `README.md`, follow commit guidelines. There are **no instructions about PR creation, PR body formatting, including prompts, or adding session links.**

### PR body contents by tool

| PR | Tool | Prompt included? | Session link format | Body structure |
|----|------|-------------------|---------------------|----------------|
| #106 | Claude Code | Yes | `claude.ai/code/session_...` | Research question + conclusion |
| #100 | Claude Code | No (summary only) | In commits | Documentation list + findings |
| #95 | Claude Code | Yes, verbatim | `claude.ai/code/session_...` | Prompt + Summary + Key Changes |
| #91 | Claude Code | Yes, as requirements block | `claude.ai/code/session_...` | Prompt + Summary + Key Changes + Details |
| #86 | Claude Code | No (short desc) | `claude.ai/code/session_...` | Brief description |
| #79 | Claude Code | Yes, verbatim | `claude.ai/code/session_...` | Task instructions + technical summary |
| #10 | Codex Cloud | Yes, verbatim | `chatgpt.com/s/cd_...` | Prompt + Summary + Testing |
| #102 | Copilot | No (summary only) | `github.com/.../agents/...?session_id=...` | Short description |

### How Claude Code on the web creates PRs

According to the [official documentation](https://code.claude.com/docs/en/claude-code-on-the-web), the workflow is:

1. User submits a task at claude.ai/code
2. The repository is cloned to an Anthropic-managed VM
3. Claude Code executes the task (writes code, runs tests, etc.)
4. Changes are pushed to a branch
5. The user reviews a diff in the web interface
6. The user clicks **"Create PR"** — the platform generates the PR title and body

The PR body generation is a product feature of the platform. The user does not write the PR description manually.

### Each platform generates its own format

- **Claude Code on the web**: Often includes the original prompt verbatim at the top, followed by a structured summary (Summary, Key Changes, Testing sections), and appends `claude.ai/code/session_...` links
- **OpenAI Codex Cloud**: Similarly includes the original prompt and a `chatgpt.com/s/...` session link (PR #10)
- **GitHub Copilot coding agent**: Generates a brief summary and links to a GitHub-hosted agent session (PR #102)

### Author attribution

PRs show `simonw` as the author because the tools authenticate through Simon's GitHub account. However, individual commits are attributed to the AI agent (e.g., `Claude <noreply@anthropic.com>`). The merge commits are by `simonw` (the human clicking "Merge").

## Analysis

The prompt-and-transcript-in-PRs pattern that makes simonw/research useful as a research log is an emergent property of how async coding agent platforms work, not something Simon explicitly configured. These platforms are designed around a fire-and-forget model where — as Simon [describes it](https://simonwillison.net/2025/Nov/6/async-code-research/) — "you pose it a task, it churns away on a server somewhere and when it's done it files a pull request." Including the original prompt and a link back to the session is a natural part of that workflow, providing traceability from PR back to the task that created it.

The variation in PR body quality (some include the full prompt verbatim, some just a summary) likely reflects evolution in the platforms over time and possibly differences in how Claude Code generates the body depending on the complexity and nature of the task. There is no user-side configuration controlling this — it's entirely a platform behavior.

## Files

- `notes.md` — Research notes and investigation log
- `README.md` — This report
