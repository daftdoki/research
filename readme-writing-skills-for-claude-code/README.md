# Claude Code skills for writing a plain, short project README

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Which Claude Code skills or plugins write a repository README and usage docs that read like a normal software project's README: what it is, how to install it, how to use it, how to develop on it, kept short, with none of the tells of generated text? ([original prompt](#original-prompt))

Nothing was installed. Every claim comes from a skill file, README, license, or commit page read through GitHub on 2026-09-20, plus the Claude Code and GitHub docs.

## Answer / Summary

**There is no single skill that does all of it. Use two: a small structure skill and a prose rule set.** The README-writing skills on GitHub split into two camps. About two thirds are landing-page generators: badges, hero images, Mermaid, emoji headers, Features lists, a Chinese translation. The rest are short structural skills that say which sections to write and where to get the facts, and none of those has any rule about how the prose should sound.

**For structure, take `readme` from [johnsyweb/agent-skills](https://github.com/johnsyweb/agent-skills/tree/main/readme).** It is 3.5 KB plus a 1.4 KB section guide, MIT, and its above-the-fold is GitHub's own five README questions (what, why, getting started, help, maintainers). Below the fold it writes Local development, Contributing, Releasing, Security and License, but only "when it has a source" in the repo, so a small project gets a small README. It caps badges at five, turns sibling files like `CONTRIBUTING.md` into one-line pointers, asks one round of questions only for real gaps, and stops when the file is written. It is the only small skill that covers the "how to develop on it" ask. Its author's own repo README is a live sample of the output and reads like a maintainer wrote it.

**For prose, keep pstack `unslop` always on**, as the sibling report [unslop-and-writing-for-agents-skills](../unslop-and-writing-for-agents-skills/README.md) already recommends. Add `docs-doc` from [immagiov4/my-codex-skills](https://github.com/immagiov4/my-codex-skills/tree/main/skills/docs-doc) as an optional finishing pass on any doc: its section 7 is the most complete "remove AI-sounding prose" list I found inside a documentation skill, and it defers to unslop for the general catalog.

If you would rather vendor one file into the dokidlc marketplace, [`readme-SKILL.draft.md`](readme-SKILL.draft.md) merges the johnsyweb structure with a "no line you could delete" completion test and the README-specific tells. It is 3 KB.

The one heavier skill worth knowing about is [adewale/good-readme](https://github.com/adewale/good-readme), the most-developed README skill in the set (72 installs on skills.sh, 15 commits, MIT). Its improve mode scores an existing README against a 100-point rubric and has a source-grounded drift protocol that checks every documented command and import against the code. It is a better auditor than writer for this brief: its framing is "the README is your pitch" and its anatomy reference lists fourteen sections including badges, visual demo and key features.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Read the sibling `unslop-and-writing-for-agents-skills/` report first, so the prose side was not redone.
2. GitHub code search for `filename:SKILL.md path:readme` (29 hits) and repo searches for `readme skill claude code` (198 repos) and `readme plugin claude-code`. Web search for README skills on skills.sh, skills-hub, lobehub, claudepluginhub and mcpmarket. Searched the claude.ai org skill and plugin catalog.
3. Code-searched the big collections for a README skill: obra/superpowers, anthropics/skills, mattpocock/skills, affaan-m/ECC, github/awesome-copilot, anthropics/knowledge-work-plugins, and the hesreallyhim/awesome-claude-code list.
4. Discarded on description anything selling "stunning", "beautiful", "star-magnet", "banners" or a profile poster. Fetched the SKILL.md and README of the 23 remaining files (about 270 KB) from raw.githubusercontent.com and read them. The GitHub file tool in this session is scoped to this repo, so raw fetches and the commit pages on github.com supplied file contents and dates.
5. Scored each skill against the four asks in the prompt (describe, install, use, develop), the brevity ask, and the "not AI" ask, and counted em dashes in each skill's own instruction text as a proxy for whether its author would notice tells in a draft.
6. Cross-checked the structure of the winner against the GitHub docs page [About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes).

## Results

### Skills that fit the brief

| Skill | Size | License | Last change | Describe | Install | Use | Develop | Brevity rule | Prose rule |
|---|---:|---|---|:-:|:-:|:-:|:-:|---|---|
| [johnsyweb/agent-skills `readme`](https://github.com/johnsyweb/agent-skills/tree/main/readme) | 3.5k + 1.4k | MIT | 2026-08-15 | yes | yes | yes | yes (Local development) | heading only when it has a source; badges max 5; siblings are pointers | none |
| [Slikon/agent-skills `readme-check`](https://github.com/Slikon/agent-skills/tree/main/skills/readme-check) | 1.6k | no LICENSE file | 2026-07-03 | yes | yes | yes | no | "no line you could delete without losing an instruction or a needed fact" | "cut the fluff: marketing lines, restated headings" |
| [Tethik/skills `readme`](https://github.com/Tethik/skills/tree/main/readme) | 4.4k | MIT | 2026-09-10 | yes | yes | yes + Configuration | link to CONTRIBUTING.md only | one screen of prose; ordered cut list for reviews | none; optional emoji on headers |
| [anthropics/knowledge-work-plugins `engineering:documentation`](https://github.com/anthropics/knowledge-work-plugins/blob/main/engineering/skills/documentation/SKILL.md) | 1.5k | Anthropic | | yes | quick start | yes | contributing | "link, don't duplicate" | none |
| [github/awesome-copilot `create-readme`](https://github.com/github/awesome-copilot/blob/main/skills/create-readme/SKILL.md) | 1.3k | MIT | | by example | by example | by example | no | "concise and to the point", skip LICENSE/CONTRIBUTING sections | "do not overuse emojis"; tone from four named READMEs |
| [immagiov4/my-codex-skills `docs-doc`](https://github.com/immagiov4/my-codex-skills/tree/main/skills/docs-doc) | 22k | MIT | 2026-09-10 | editor, not writer | | | | Diátaxis, one job per file, cut every word that does no work | §7 AI-prose list, §8 timeless prose, defers to unslop |

### Skills that do a different job

| Skill | Size | Why not |
|---|---:|---|
| [adewale/good-readme](https://github.com/adewale/good-readme) | 7.5k + 88k refs | Best auditor (100-point rubric, API drift protocol) but "the README is your pitch"; anatomy lists 14 sections incl. badges, visual demo, features |
| [linhai0872/readme-crafter-skill](https://github.com/linhai0872/readme-crafter-skill) | 20.6k + refs + scan script | Good evidence rules ("never hollow superlatives") but targets "visually polished": Mermaid, shields.io, centered HTML, and ends by suggesting GIFs and hero images to add |
| [normieg/Readme-gen](https://github.com/normieg/Readme-gen) | 9k + 7 templates | Strong "never invent" list, but applications "normally get 4-8 major technology badges plus a stack table" and Mermaid by default |
| [gupsammy/Claudest `make-readme`](https://github.com/gupsammy/Claudest/tree/main/plugins/claude-coding/skills/make-readme) | 7.7k | Interview, then shields.io badges, emoji on every H2/H3 in "Styled" mode, leaves `USER/REPO` placeholders. Repo has 275 stars |
| [weiliu1031/writing-readme](https://github.com/weiliu1031/writing-readme) | 30.8k | A hard gate mandates generating a logo, badges, a language switcher and a `README_CN.md` |
| [PeteRichardson/skills `readme`](https://github.com/PeteRichardson/skills/tree/main/readme) | 14.6k | Right tone line ("a competent colleague wrote it, not a marketing team") but the template is centered badges, TOC, bold-lead Features, 🖊/🤖 markers, 29 em dashes |
| [kevin-aoun/skills `readme`](https://github.com/kevin-aoun/skills/tree/main/readme) | 5k + templates | "Production-grade" internal-service shape: ports table, Mermaid, where-to-put-new-code table, REFERENCE.md and DECISIONS.md siblings |
| [alsi-lawr/HUMANS.md `readme-generator`](https://github.com/alsi-lawr/HUMANS.md/tree/master/coding/skills/readme-generator) | 3.4k | "Markets honestly", allows HTML banners and badges; lives inside a three-plugin marketplace |
| n2g7/agent-skills `readme` (vendored from Shpigford/skills, now gone) | 20k | "absurdly thorough" by design; Rails and deployment oriented |
| [GLINCKER `readme-generator`](https://github.com/GLINCKER/claude-code-marketplace/blob/main/skills/documentation/readme-generator/SKILL.md) | 6k | Generic section list from 2025-01, "professional but approachable" |
| [serejaris `readme-generator`](https://github.com/serejaris/ris-claude-code/blob/main/skills/readme-generator/SKILL.md) | 4.8k | Step 1 is an Exa web search; needs that MCP server |
| [whodevil/skills `readme`](https://github.com/whodevil/skills/tree/main/readme), [livlign `readme-doctor`](https://github.com/livlign/claude-skills) | 19k, 10k | Per-issue approval loop and a stars-oriented audit rubric. Maintenance tools, not writers |

Not present anywhere: obra/superpowers, anthropics/skills, mattpocock/skills and affaan-m/ECC ship no README skill. The awesome-claude-code list's only README-adjacent entry is a screenshot tool. The most-starred repo named "readme skill" (study8677/Readme.skill, 170 stars) makes GitHub profile posters.

### Em dashes in each skill's own instructions

| Skill | Count |
|---|---:|
| readme-gen, docs-doc, HUMANS.md | 0 |
| serejaris | 1 |
| readme-crafter | 5 |
| Slikon, Anthropic documentation | 6 |
| johnsyweb | 8 |
| Tethik | 17 |
| good-readme | 20 |
| PeteRichardson | 29 |

Instruction text is not output, but it is a fair signal of whether the author's ear catches the tells. It is one reason the prose layer has to come from somewhere else.

## Analysis

### Why two skills and not one

The prompt asks for two things that no single file provides: a section plan that stops at install, usage and development, and prose that does not sound generated. The structural skills (johnsyweb, Slikon, Tethik, the Anthropic documentation skill, the Copilot one) are all silent on prose beyond "concise". The skills that do have prose rules are either landing-page generators (readme-crafter's "never hollow superlatives" sits next to its badge and Mermaid guidance) or general documentation editors (docs-doc). The one file that has both a plain structure and an anti-tell list is the draft in this folder, and it exists because nothing upstream did.

### Why johnsyweb over Slikon and Tethik

Slikon's `readme-check` is the purest statement of the brevity ask, and its completion criterion is the best sentence in the whole set. But it has no development section, and the repo has no license file, so its text cannot be vendored. Tethik's `readme` is a good end-user pitch skill with a useful ordered cut list for reviews, but it pushes everything a contributor needs into `CONTRIBUTING.md`, it allows emoji on headers, and its own text has the most em dashes of the short skills. johnsyweb covers all four sections, has the "source or omit" rule that keeps a small project's README small, is MIT, and its `disable-model-invocation: true` means it runs only on `/readme`, which is right for a skill that rewrites a whole file.

Two things to know about it. It comes with `SECTIONS.md` next to `SKILL.md`, so vendor both files. It asks for observability links and a Maintainers section, which suit a team repo more than a solo one; both are omitted when there is no source, so they cost nothing on a personal project.

### Where good-readme fits

It is the skill to reach for when an existing README has drifted. The "Source-Grounded API Drift Protocol" extracts every import, command, flag and config key the README mentions and checks each against manifests, export files and CLI parsers, then reports stale symbol, current symbol and evidence file. Nothing else in the set does that. Its 88 KB of references load on demand, not per turn, so the cost is only when invoked. Use it for the audit, then write with the small skill.

### Combining with what already runs

The sibling report settled on the pstack `unslop` text imported into `CLAUDE.md` on every turn. That already covers the general tells. The draft adds only the README-specific ones: adjective stacks, "aims to / is designed to", bold-lead bullet lists, a "Getting Started" that says "follow the steps below", and the closing Acknowledgments / Roadmap / "Made with ❤️" sections. docs-doc is worth keeping around for the rest of a repo's docs rather than the README: its Diátaxis and one-job-per-file rules are about doc sets, and its §7 list overlaps unslop by design (it says so).

### Caveats

- No skill was run. Verdicts are from reading the instruction text and, for johnsyweb, the author's own README as a sample of output. Running each on the same small repo would be the next step and needs a host that can install skills.
- Install counts on skills.sh are tiny for all the small skills (johnsyweb `readme`: 2). Popularity did not decide anything here; the popular README skills are the landing-page ones.
- The draft's tell list is short on purpose. The general catalog belongs to unslop, and duplicating it per skill is how a context budget disappears.

## Files

| File | What it is |
|---|---|
| `README.md` | This report |
| `notes.md` | Work log: searches, access workarounds, per-skill read notes, dead ends, decision |
| `readme-SKILL.draft.md` | Proposed `SKILL.md` for a vendored `readme` skill: johnsyweb structure (MIT, attributed) plus a completion test and README-specific tells |
| `_summary.md` | One-paragraph summary spliced into the root README index |

## Original Prompt

> Do research on skills or plugins for Claude code that are for writing for repo README and usage documentation. I want something that writes README that don't look like AI and are more in-line with what you'd expect from a normal software project README. I want it to describe the project, how to use it, how to install it and how to develop on it in a brief and non-slop way.
