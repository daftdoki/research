---
name: readme
description: Write or patch the root README.md so it says what the project is, how to install it, how to use it, and how to develop on it, in plain prose with no filler. Use when asked to write, update, tighten, or review a README.
disable-model-invocation: true
---

<!--
Proposed SKILL.md for daftdoki/dokidlc-skill-readme.
Structure and the "heading only when it has a source" rule are from
johnsyweb/agent-skills `readme` (MIT, commit 7977ac0, 2026-08-15).
The completion test and the tell list are new. Prose rules defer to the
always-on unslop skill; the tells below are the README-specific ones.
-->

The deliverable is the root `README.md`. Patch it, or create it if missing, and stop.

## 1. Gather

Read before writing. Every claim in the README must trace to one of these.

- Manifests and scripts: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, `justfile`, `Dockerfile`, `compose.yaml`, `.env.example`.
- Entry points and CLI definitions: `main`, `cmd/`, `bin/`, argument parsers. Run `--help` when a binary exists.
- CI workflows: the test and lint commands are the "develop" section.
- Sibling files: `LICENSE`, `CONTRIBUTING.md`, `CHANGELOG.md`, `SECURITY.md`, `docs/`.
- The existing README: keep any sentence that still answers a required question. Match its voice.

If what the project is for is not in the repo, ask once. Do not guess it.

## 2. Write

Sections in this order. A heading with no source is omitted, not filled.

```markdown
# name

One sentence: what it does. Two more at most on why you would want it.

## Install

The shortest working path for a user, as copy-paste commands from the manifest or release process.
Prerequisites only when they bite (minimum runtime version, a system package).

## Usage

The one or two commands or calls a user actually runs, with real flags and real output.
Configuration as a short table only when there are options most users touch.

## Development

Clone, install, test, lint: the commands CI runs, in the order a contributor runs them.
Link CONTRIBUTING.md when it exists instead of restating it.

## License

Name and link to the LICENSE file.
```

Rules:

- Badges: at most three (CI, version, license), one row under the title, only when the service exists. None is fine.
- No Features list. If the pitch needs bullets, the pitch is wrong.
- No table of contents, no logo, no emoji, no `<div align="center">`, no Mermaid unless the repo already had one.
- Sibling files (`CONTRIBUTING.md`, `SECURITY.md`, `docs/`) get a link, not a summary.
- Commands are real. Never `<your-value-here>` or `USER/REPO`.
- A claim that contradicts the code is rewritten from the code or removed.

## 3. Prose

The always-on unslop rules apply. The tells that show up in generated READMEs specifically:

- "blazing fast", "powerful", "seamless", "robust", "comprehensive", "modern", "lightweight" as adjectives. Say the number or the mechanism, or say nothing.
- "This project aims to", "is designed to", "provides a way to". Say what it does.
- Bold lead-ins on every bullet, three-item lists where one sentence would do.
- "Getting Started" that is one line of "Follow the steps below".
- Closing sections: Acknowledgments, Roadmap, "Made with ❤️", Star History.
- Em dashes. Use a period or a comma.

## 4. Done when

Someone new can install, run, and start hacking on the project from the README alone, every command has been checked against the repo, and no line can be deleted without losing an instruction or a fact. Stop. The file is the product.
