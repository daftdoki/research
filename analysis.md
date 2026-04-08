# Analysis of the simonw/research Workflow

An analysis of how https://github.com/simonw/research.git implements its AI-driven research workflow — not the content, but the machinery.

## Overview

This is a repository where **every line of text and code is written by an LLM** (primarily Claude Code). Simon Willison uses it as a system for delegating exploratory coding/research questions to AI agents and collecting the results in a structured, browsable format. Each research project lives in its own directory and follows a consistent lifecycle managed by agent instructions, GitHub Actions, and a code-generation tool called `cogapp`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Human provides a research question / prompt                │
│  (via Claude Code, Codex, or similar async agent)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent works on a claude/* branch                           │
│  - Creates a new directory for the project                  │
│  - Writes notes.md (lab notebook of exploration)            │
│  - Writes code, scripts, and artifacts                      │
│  - Writes README.md (final polished report)                 │
│  - Commits and opens a PR                                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  PR is merged to main                                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions workflow fires (on push to main)            │
│  - Runs cogapp to regenerate the root README.md             │
│  - Generates _summary.md for new projects via LLM           │
│  - Injects AI-generated note banners into project READMEs   │
│  - Auto-commits the changes with [skip ci]                  │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. AGENTS.md — The Agent's Playbook

The file `AGENTS.md` (referenced by `CLAUDE.md` with `@AGENTS.md`) is the instruction set given to AI coding agents. It defines the entire research protocol:

1. **Create a new folder** with an appropriate name for the investigation.
2. **Create `notes.md`** — a running lab notebook tracking what was tried and what was learned.
3. **Build `README.md`** — the final polished report of the investigation.
4. **Commit only original work** — the agent must include its notes, README, code it wrote, and diffs of modifications to external repos, but must NOT include full copies of external code it fetched.
5. **No `_summary.md`** — these are generated automatically after the commit.
6. **Binary files under 2MB** are allowed if appropriate.

This is a remarkably minimal instruction set — roughly 15 lines — that produces highly consistent output across 83+ projects.

### 2. Branch Naming Convention

All agent-created branches follow the pattern `claude/<topic>-<random-suffix>`, e.g.:
- `claude/csrf-protection-demo-0eGTy`
- `claude/sqlite-wal-docker-01VDx8qCRXwsb92j7hMT7ycn`
- `claude/ast-grep-import-rewriter-01Qod885WrCkgwSNpdsEbeYm`

There are 90+ such branches in the repository. Each represents one research task dispatched to an agent. The work is done on the branch, then merged via pull request.

### 3. The Commit Lifecycle

A typical project follows this pattern:

1. **Branch creation**: A `claude/*` branch is created.
2. **Agent commits**: The agent (author: "Claude", email: noreply@anthropic.com) commits its work — typically a single commit with all files.
3. **PR merge**: Merged to `main` as a merge commit (e.g., `"SQLite WAL mode works correctly across Docker containers sharing a volume (#106)"`).
4. **Auto-update**: GitHub Actions immediately runs `cogapp` and auto-commits `"Auto-update README with cogapp [skip ci]"`.

### 4. The README Auto-Generation Pipeline (cogapp + llm)

The root `README.md` is not manually maintained. It contains an embedded Python script inside `cogapp` markers (`<!--[[[cog ... ]]]-->`) that:

**a) Discovers all project directories** by iterating the filesystem and looking up each folder's first commit date via `git log`.

**b) Sorts projects by date** (newest first) and renders a heading with a link for each.

**c) Generates or caches summaries** using the `llm` CLI tool:
   - If a `_summary.md` file already exists in the project folder, it uses that cached summary.
   - If not, it calls `llm -m github/gpt-4.1` with a specific summarization prompt to generate a 1-paragraph + bullet-list summary from the project's README.
   - The generated summary is saved as `_summary.md` for future runs (caching).

**d) Injects AI-generated disclosure banners** into every project's `README.md`:
   - Adds a GitHub `> [!NOTE]` callout after the first `# heading` stating "This is an AI-generated research report."
   - Projects can opt out with a `<!-- not-ai-generated -->` marker.

### 5. Dependencies

`requirements.txt` contains just three packages:
- **`cogapp`** — Ned Batchelder's code generation tool. Executes Python code embedded in text files between `[[[cog` and `]]]` markers, replacing the output section.
- **`llm`** — Simon Willison's own CLI tool for interacting with LLMs.
- **`llm-github-models`** — An `llm` plugin that provides access to GitHub-hosted models (used here with `github/gpt-4.1` for summary generation).

### 6. GitHub Actions Workflow

`.github/workflows/update-readme.yml` triggers on every push to `main`:
1. Checks out the repo with full history (`fetch-depth: 0`) — needed because cogapp uses `git log` to determine project dates.
2. Installs Python 3.11 and the three pip dependencies.
3. Runs `cog -r -P README.md` to regenerate the README in-place.
4. Commits any changes to `README.md`, `*/README.md` (AI-note injections), and `*/_summary.md` (new cached summaries).
5. Uses `[skip ci]` in the commit message to prevent infinite recursion.

## Per-Project Structure

Each research project directory follows a consistent pattern:

| File | Purpose |
|------|---------|
| `notes.md` | Lab notebook — what was tried, what was learned, raw observations |
| `README.md` | Polished final report with findings, methodology, and conclusions |
| `_summary.md` | Auto-generated 1-paragraph summary (created by cogapp/llm, not the agent) |
| `*.py`, `*.sh`, etc. | Code artifacts created during the investigation |
| `*.png`, `*.json` | Supporting data/screenshots (under 2MB) |

## Design Principles

1. **Minimal agent instructions, maximal structure**: The AGENTS.md file is only ~15 lines but produces a consistent format across 83+ projects because it specifies *what to produce* (notes.md, README.md, code, diffs) rather than *how to produce it*.

2. **Separation of concerns**: Agents produce raw research; the CI pipeline handles presentation (summaries, index, disclosure banners). The agent never needs to know about cogapp or the root README.

3. **Async / fire-and-forget**: Each research task is dispatched to a branch. The human reviews the PR when ready. The commit history shows Simon Willison as the merge author, with "Claude" as the branch author — a clear audit trail of human-directed, AI-executed work.

4. **Caching to control costs**: The `_summary.md` files act as a cache layer so the LLM summarization (via GPT-4.1) only runs once per project, not on every README rebuild.

5. **Self-documenting provenance**: Every project README gets an injected banner disclosing it was AI-generated, with an opt-out mechanism (`<!-- not-ai-generated -->`).

6. **No scaffolding or templates**: There's no cookiecutter, no project generator. The agent creates the directory and files from scratch each time, guided only by AGENTS.md. This keeps the system simple and flexible.
