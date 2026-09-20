# README-writing skills and plugins for Claude Code — Notes

## Goal

Find Claude Code skills or plugins that write a repo README and usage docs
that read like a normal software project README: what it is, install, usage,
how to develop on it. Brief, no AI tells. Recommend one (or a combination).

## Constraints

Cloud session, host untouched. Nothing installed. Every claim from a file read
through the GitHub API, a web page, or the Claude Code docs. Date: 2026-09-20.

## Prior work in this repo

`unslop-and-writing-for-agents-skills/` (2026-09-12) already covers the anti-slop
side: pstack `unslop` (cursor/plugins) recommended as an always-on rule set,
humanizer / theclaymethod as heavier on-demand rewriters. This investigation
is about the README-specific side, and how it combines with that.

## Work log

### 2026-09-20 initial searches

- GitHub code search `filename:SKILL.md path:readme`: 29 hits, mostly personal
  skill collections (johnsyweb, Tethik, PeteRichardson, whodevil, n2g7, kevin-aoun,
  bytesagain, tushaarmehtaa, ai4brands-design, Moamen-R, razeevascx, ...).
- GitHub repo search `readme skill claude code` (198 repos). Candidates worth reading:
  - adewale/good-readme (5 stars, pushed 2026-09-16) "writing and improving GitHub READMEs"
  - linhai0872/readme-crafter-skill (4) "honest, structured READMEs, classifies project type"
  - weiliu1031/writing-readme (2) "distilled from awesome-readme"
  - normieg/Readme-gen (2, created 2026-09-08) "create, audit, improve"
  - Slikon/agent-skills (5) has "README tidying"
  - livlign/claude-skills (19) README heroes + README audits (marketing-ish)
  - Ublaze/github-readme-generator (3) "banners, badges, comparison tables" -> visual, likely slop
  - 199-biotechnologies/github-optimization-skill (14) "star-magnet landing page" -> opposite of ask
  - Sheshiyer/readme-skill, oxgeneral/PerfectReadme, glebrati-cloud/auto-readme,
    LauraMoney42/GitPretty -> "stunning", "beautiful", "visually rich" -> discard on description
  - KorroAi/readme-roast, hidai25/readme-roast -> auditors not writers
  - study8677/Readme.skill (170 stars) is a GitHub *profile* README/poster generator, unrelated
- Web search: alsi-lawr/HUMANS.md readme-generator ("verified code, no invented commands,
  badges or claims"), gupsammy/claude-coding make-readme, GLINCKER/claude-code-marketplace
  readme-generator, github/awesome-copilot create-readme, serejaris/ris-claude-code readme-generator,
  mcpmarket "Readme Writer" (9th-grade reading level).
- SearchSkills (claude.ai org catalog): nothing. SearchPlugins: Anthropic's knowledge-work
  `engineering` plugin has an `engineering:documentation` skill; check what it does.
- Still to check: big collections (obra/superpowers, anthropics/skills, mattpocock/skills,
  affaan-m/ECC, hesreallyhim/awesome-claude-code) for a README/docs skill.

### Access notes

- The GitHub MCP `get_file_contents` tool is scoped to `daftdoki/research` only.
  `search_code` and `search_repositories` work across GitHub. Raw files come from
  `raw.githubusercontent.com` via curl through the proxy (200s). `api.github.com`
  returns 403 through the proxy. Commit dates came from WebFetch of the GitHub
  `/commits/<branch>/<path>` pages. skills.sh install counts from WebFetch of
  the skill pages.
- `search_code` rate-limited (429) a few times when fired in parallel; retries worked.

### Reading the candidates

Fetched 23 files (~270 KB) into the scratchpad and read them. Sizes are bytes of
SKILL.md unless noted.

| Skill | Size | License | Last touched | Read verdict |
|---|---:|---|---|---|
| johnsyweb/agent-skills `readme` | 3.5k + 1.4k SECTIONS.md | MIT | 2026-08-15 (one commit) | Above-the-fold = GitHub's five README questions; below-fold Local development / Contributing / Releasing / Security / License only "when it has a source". `disable-model-invocation: true`. Badges capped at five. Sibling files become pointers. Asks one round of questions only for gaps. Covers all four of the prompt's asks. |
| Slikon/agent-skills `readme-check` | 1.6k | none in repo | 2026-07-03 | What it is / install / usage / blockers. "No line you could delete without losing an instruction or a needed fact." No develop section. Smallest thing that works. |
| Tethik/skills `readme` | 4.4k | MIT | 2026-09-10 | "A README is a sales pitch, not a manual." Pitch, Usage, Configuration, link out. Optional emoji on headers (a tell for the prompt's taste). No develop section, links CONTRIBUTING.md. Good ordered cut list for reviewing an existing README. Three real example READMEs cited. |
| adewale/good-readme | 7.5k + 88k references | MIT | 2026-03-17 to 2026-07-26, 15 commits; 72 installs on skills.sh | Two modes (create / improve), source-grounded API drift protocol, 22-criterion 100-point rubric, 15 anti-patterns. Framing is "your pitch", "lead with value". anatomy.md discourages "blazingly fast" vagueness and emoji in H1, but the anatomy lists 14 sections incl. badges, visual demo, key features. Best auditor; heavier than the prompt wants for writing. |
| immagiov4/my-codex-skills `docs-doc` | 22k | MIT | 2026-08-25; 2026-09-10 "incorporate no-ai-slop guidance" | Not a README generator. A documentation editor: Diátaxis, Google dev style, STE, Global English, then §7 "Remove AI-sounding prose" (the most complete list I found inside a docs skill) and §8 timeless prose. Says "Apply the unslop skill to every doc this skill touches". Zero em dashes in its own text. Codex-format but SKILL.md is portable. |
| anthropics/knowledge-work-plugins `engineering:documentation` | 1.5k | Anthropic | | Generic. README bullets are exactly what/why, quick start, config+usage, contributing. No writing rules, no repo scan steps. |
| github/awesome-copilot `create-readme` | 1.3k | MIT (repo) | | "Do not overuse emojis, keep it concise", skip LICENSE/CONTRIBUTING sections, take tone from four named Azure-sample READMEs. Example-driven; fine as a seed but thin. |
| alsi-lawr/HUMANS.md `coding/skills/readme-generator` | 3.4k | MIT | | "Markets honestly", allows HTML banners/badges/collapsibles. Lives inside a three-plugin marketplace. Arc not template. |
| linhai0872/readme-crafter-skill | 20.6k + refs + scan script | MIT | 2026-08-18 | Honest-claims rules are good (never fabricate, never hollow superlatives) but the output target is "visually polished": Mermaid, shields.io, `<div align="center">`, hero image suggestions, a "suggestions list" of GIFs to add. Landing-page skill. |
| normieg/Readme-gen | 9k + 7 templates + BADGES/MERMAID refs | | created 2026-09-08 | Strong evidence rules, but "substantial applications normally get 4-8 major technology badges plus a stack table" and Mermaid by default. |
| weiliu1031/writing-readme | 30.8k | | | HARD-GATE mandates generating a logo, badges, a language switcher, and a README_CN.md. Opposite of the ask. |
| gupsammy/Claudest `make-readme` (+ `update-readme`) | 7.7k / 5.8k | | repo 275 stars | Interview via AskUserQuestion, then shields.io badges, "Styled" = emoji on every H2/H3, leaves `USER/REPO` placeholders. update-readme spawns three subagents and runs make-changelog first. |
| n2g7/agent-skills `readme` (vendored from Shpigford/skills, now 404) | 20k | | | "absurdly thorough" by design. Rails/deploy oriented. |
| PeteRichardson/skills `readme` | 14.6k | | | Good tone line ("a competent colleague wrote it, not a marketing team") and real-names rule, but the template is centered badges, TOC, bold-lead Features bullets, `<details>`, 🖊/🤖 markers, 29 em dashes. |
| kevin-aoun/skills `readme` | 5k + refs + templates | | | "Production-grade": ports table, Mermaid, where-to-put-new-code table, REFERENCE.md/DECISIONS.md siblings. Internal-service shape. |
| GLINCKER `readme-generator` | 6k | Apache-2.0 | 2025-01-13 | Generic section list, "professional but approachable". |
| serejaris `readme-generator` | 4.8k | | | Step 1 is an Exa web search; recommends running on haiku. Not usable without that MCP. |
| whodevil/skills `readme` | 19k | | | Six-phase per-issue approval loop. A maintenance tool, not a writer. |
| livlign `readme-doctor` | 10k | | | Audit only, rubric tuned to "maintainer outcomes (stars...)". |

### Dead ends

- obra/superpowers, anthropics/skills, mattpocock/skills: no README skill (code search for
  `readme filename:SKILL.md repo:...` hits only unrelated skills that mention the word).
- affaan-m/ECC: 56 SKILL.md files mention "readme"; none is a README writer
  (living-docs-governance, codebase-onboarding, code-tour are adjacent).
- hesreallyhim/awesome-claude-code README (195 KB): the only "readme" hit is `showreel`,
  a screenshot/GIF tool.
- Shpigford/skills (upstream of the n2g7 copy) returns "does not exist or no permission".
- study8677/Readme.skill (170 stars, the most-starred "readme skill") builds a GitHub
  *profile* README poster from local Claude Code history. Unrelated.
- The claude.ai org skill catalog (SearchSkills) has nothing for readme/documentation.
- 199-biotechnologies/github-optimization-skill, Sheshiyer/readme-skill, oxgeneral/PerfectReadme,
  glebrati-cloud/auto-readme, LauraMoney42/GitPretty, Ublaze/github-readme-generator:
  discarded on their own descriptions ("star-magnet", "stunning", "beautiful", "banners").

### Cross-check: what GitHub itself says a README holds

docs.github.com "About READMEs": what the project does, why it is useful, how users can get
started, where to get help, who maintains and contributes. johnsyweb's above-the-fold is
that list verbatim, which is why it reads like a normal project README.

### Anti-tell check across candidates

Only two skills carry explicit AI-prose rules: docs-doc §7 (long list) and, indirectly,
readme-crafter ("never hollow superlatives") / good-readme anatomy ("blazingly fast" as a
mistake). None of the small structural skills (johnsyweb, Slikon, Tethik) has any. Those
three assume the model's default prose is fine; the prompt says it is not. So the answer
is a structure skill plus a prose rule set, not one skill.

Em dashes in each skill's own instruction text: readme-gen 0, docs-doc 0, HUMANS.md 0,
serejaris 1, readme-crafter 5, Slikon 6, Anthropic 6, johnsyweb 8, Tethik 17,
good-readme 20, PeteRichardson 29. Instruction text is not output, but a skill whose
author writes in tells will not notice them in the draft either.

### Decision

Recommend johnsyweb `readme` for structure (it is the only small one that has a
"how to develop on it" slot, and its source-or-omit rule is what keeps it brief),
pstack `unslop` always-on for prose (already the recommendation in the sibling
`unslop-and-writing-for-agents-skills/` report), and docs-doc §7/§8 as the
optional finishing pass. Wrote `readme-SKILL.draft.md` merging the johnsyweb
structure (MIT, attributed) with the "every line carries an instruction or a fact"
completion criterion and a short tell list, for the dokidlc vendor pattern.
Slikon's text is not copied because that repo has no license file.
