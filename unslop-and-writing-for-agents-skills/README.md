# Which unslop and writing-for-agents to list in the dokidlc marketplace

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Two skills run on this machine, `unslop` and `writing-for-agents`. At least `unslop` exists in several public versions by different people. Which version of each is the best one to list in the `dokidlc` plugin marketplace ([daftdoki/dokidlc-plugins](https://github.com/daftdoki/dokidlc-plugins)), and how should the listing point at it? ([original prompt](#original-prompt))

Nothing was installed. Every claim comes from a file or commit read through the GitHub API on 2026-09-12, or from the Claude Code plugin docs.

## Answer / Summary

**unslop: keep the lineage you already run, the pstack skill by Lauren Tan in [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop), but vendor it into `daftdoki/dokidlc-skill-unslop` rather than pointing at upstream.** The local file is byte-for-byte pstack commit `99559f2` (2026-08-02). Upstream has moved twice since: on 2026-09-01 it set `disable-model-invocation: true`, so the skill only fires when someone types `/unslop`, and on 2026-09-07 a "density pass" deleted the "Adding soul" section and five rules while adding two good ones (mannered prose, over-compression). A vendored copy lets you keep soul and model invocation and still take the two new rules. The draft is in [Files](#files).

The reason the pstack text wins is the way you use it. Your global `CLAUDE.md` imports the skill body with `@`, so it sits in context on every turn. That rules out the other well-made candidates, which are 16k to 29k bytes and built as on-demand rewrite tools: [blader/humanizer](https://github.com/blader/humanizer) (47,337 stars, the ancestor of the pstack text), [theclaymethod/unslop](https://github.com/theclaymethod/unslop) (a slash-command product with presets and an eval suite), and [MohamedAbdallah-14/unslop](https://github.com/MohamedAbdallah-14/unslop). The pstack file is 6k bytes and is also, by the count in the results below, the most copied unslop text on GitHub. If you want a heavy `/humanizer` for the occasional long rewrite, humanizer ships its own `plugin.json` and can be listed with a plain `github` source next to it.

**writing-for-agents: there is only one.** Every one of the 30 public copies I hashed descends from [mattpocock/skills](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents), and the local copy is byte-identical to upstream HEAD. Fifteen copies are exact, four are the stale pre-August version with em dashes, and the rest are personal edits, none of which improve on the original. Vendor it the same way, pinned to `3216582`, which is the current HEAD and the commit that removed the em dashes.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Read the two local skills. `writing-for-agents/SOURCE.md` names its upstream and commit; `unslop/SKILL.md` has no provenance, so its origin had to be found.
2. GitHub code search for `filename:SKILL.md path:unslop` (48 hits) and `path:writing-for-agents` (32 hits), plus a repository search for `unslop` (146 repos). Read the commit messages of the copies, which is what exposed the pstack upstream ("vendor the pstack skill").
3. Diffed the local files against upstream at HEAD and at each candidate commit until a byte-identical match appeared. Walked each upstream's commit log for the skill file and read the commit messages, then followed the humanizer attribution back one more hop.
4. For writing-for-agents, [`hash_copies.py`](hash_copies.py) fetched the 30 path-matching copies and grouped them by md5 to see how many diverge from upstream and how.
5. Fetched the SKILL.md, license and top-level tree of each prose unslop candidate and read them for structure, size and guards.
6. Read the Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) and [plugin reference](https://code.claude.com/docs/en/plugins-reference) docs for how a marketplace entry can point at a skill living inside someone else's repo.

Searched but discarded: [mshumer/unslop](https://github.com/mshumer/unslop) (548 stars) is a Python tool that samples a model and writes an avoid-list, not an editing skill; howells/skills `unslop` targets code tells and keeps prose in a separate `deslop`.

## Results

### Where the local unslop came from

| Step | Where | When | What changed |
|---|---|---|---|
| 1 | Wikipedia, "Signs of AI writing" | | Source named by humanizer's README |
| 2 | [blader/humanizer](https://github.com/blader/humanizer) `63def2e`, `35c699f` | 2026-01-18, 01-19 | 24 patterns from the Wikipedia page; "Personality and Soul" section added the next day |
| 3 | [poteto/noodle](https://github.com/poteto/noodle) `d0242cb` | 2026-02-23 | "Tightened version of the humanizer skill: no examples, no references, just the 24 patterns and the soul section. Renamed humanizer → unslop." 3.7k bytes |
| 4 | [cursor/plugins](https://github.com/cursor/plugins) pstack `24bd6eb` | 2026-05-23 | 27 rules; adds "Abstract metaphor nouns" and "Say the concrete thing" |
| 5 | pstack `99559f2` | 2026-08-02 | 31 rules. **This is the local file, unchanged.** |
| 6 | pstack `73f8be4` | 2026-09-01 | `disable-model-invocation: true` |
| 7 | pstack `e8d856f` | 2026-09-07 | Soul section removed; rules 1, 2, 4, 6, 21 deleted (numbers kept as gaps, "stable ids that other skills cite"); rules 32 and 33 added |

A code search for the soul section's first sentence, "Removing patterns is half the job", returns 674 files. That sentence exists only in the poteto lineage. pnpm/pnpm.io, Effect-TS/website and JesusFilm/core all carry it.

### Prose unslop candidates

| Skill | Stars | Last push | License | Size | Kind | Own text has em dashes |
|---|---:|---|---|---:|---|---:|
| [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop) | 7,551 (repo) | 2026-09-13 | MIT | 6.1k | Always-on rules, 28 live | 0 |
| [blader/humanizer](https://github.com/blader/humanizer) v3.0.0 | 47,337 | 2026-09-06 | MIT | 28.7k | On-demand rewrite, 25 patterns | 3 |
| [theclaymethod/unslop](https://github.com/theclaymethod/unslop) v2.3.0 | 406 | 2026-09-07 | MIT in frontmatter, no LICENSE file | 6.8k router + 50k phrase catalog + scripts | Slash-command product | yes |
| [MohamedAbdallah-14/unslop](https://github.com/MohamedAbdallah-14/unslop) v0.7.0 | 135 | 2026-09-07 | MIT | 16.3k | Always-on with intensity modes | 18 |
| [asavvin-pixel/unslop](https://github.com/asavvin-pixel/unslop) | 67 | 2026-07-14 (one day) | MIT | 17.4k | Three-level rewrite, cites a UMD/DeepMind detection study | 1 |
| [badmuriss/unslop](https://github.com/badmuriss/unslop) | 19 | 2026-08-26 | CC BY-SA 4.0 | 18.4k | Fiction, StoryScope narrative layer | 2 |
| [woerndl/unsloppify](https://github.com/woerndl/unsloppify) | 17 | 2026-08-17 | MIT | 9.7k | Six failure modes, each with a test | 0 |
| [mnapoli/skills](https://github.com/mnapoli/skills) unslop | 10 | 2026-08-28 | | 4.6k | Rewrite of pstack, with a French sibling | |

### writing-for-agents copies

| Group | Copies | What they are |
|---|---:|---|
| Identical to mattpocock/skills HEAD `3216582` | 15 | Straight vendors |
| Pre-2026-08-19 upstream (em dashes intact) | 4 | Stale vendors |
| Personal edits | 11 | Punctuation tweaks, a "Cross-Client Portability" appendix, a version that replaces the leading-word section with a blander paragraph, and three 2k to 4k condensations |

Upstream history: created as `writing-great-skills` on 2026-06-17, renamed and restructured on 2026-07-23, "cache" leading word added 2026-07-28, Codex invocation fix 2026-08-05, em dashes removed 2026-08-19. Nothing since. mattpocock/skills is published as one plugin carrying all 37 skills; there is no per-skill plugin upstream.

## Analysis

### The axis that decides unslop

The candidates split into two kinds. Always-on style rules of a few kilobytes (pstack, unsloppify, mnapoli) and on-demand rewrite tools of 16k to 29k (humanizer, theclaymethod, Mohamed, asavvin, badmuriss). The second group is better at the job of taking a finished AI draft and humanizing it. humanizer v3 orders its patterns strongest first, forbids adding facts during a rewrite, and has a "when not to act" section, none of which the pstack text has. theclaymethod goes further with presets, a rubric and evals. But you import the skill into `CLAUDE.md`, so its whole body is a per-turn tax. Twenty-eight kilobytes every turn to catch tells in a commit message is the wrong trade. The pstack text is the condensed form of the same Wikipedia-derived list, written by someone who did that condensation on purpose.

Two things the pstack text lacks are worth one line each in the vendored copy, borrowed from unsloppify: a guard that facts, quotes and the user's requested voice outrank any anti-slop rule, and a warning not to overcorrect into staccato "Not X. Y." fragments, which are themselves a tell. The draft below adds both.

### Which pstack commit

Three states are on the table.

- `99559f2` is what runs today. Soul section, 31 rules, model-invoked.
- HEAD (`e8d856f`) has the author's density pass. The five deleted rules are Wikipedia-article tells (name-dropping media outlets, "nestled", "must-visit", "despite challenges... continues to thrive") that rarely show up in engineering text, so losing them costs little. The two added rules fill real gaps in the older version. Rule 32 catches the aphorisms and personified code that a model reaches for once the obvious words are banned, and rule 33 catches the opposite failure, arrow-and-fragment shorthand that reads like notes. But the soul section is gone, and it is the part that keeps a report from reading like a sterile checklist.
- The vendored draft: `99559f2` plus rules 32 and 33 and the two guards, without `disable-model-invocation`. That is the recommendation.

### Vendor, don't point at upstream

`git-subdir` with a pinned `sha` can list `pstack/skills/unslop` or `skills/productivity/writing-for-agents` without a fork. The docs say a directory with a bare `SKILL.md` and no manifest loads as a single skill, named from the frontmatter. Three reasons to vendor anyway.

1. Both dokidlc plugins today are their own `daftdoki/dokidlc-skill-<name>` repos, and the local writing-for-agents already carries a `SOURCE.md` that records upstream, commit and what was dropped. Same pattern, two more repos.
2. The unslop copy needs edits (frontmatter, soul, two rules). A subdir pointer gives no control over those.
3. `git-subdir` clones the whole upstream repo on every install. cursor/plugins holds every Cursor plugin with assets; mattpocock/skills holds docs and a package-lock. Two three-file repos install faster in a cloud VM or container.

Two caveats I could not test here because the host stays untouched. The docs say the manifest is optional and the marketplace doc's `strict: true` default says `plugin.json` is the authority; if a manifest-less plugin refuses to load, `"strict": false` on the marketplace entry is the documented fallback, or add a two-line `plugin.json`. And the `@~/.claude/skills/unslop/SKILL.md` import in global `CLAUDE.md` will not follow a plugin install, since plugins land under a hashed cache path. Either keep the file in `~/.claude/skills` in sync by hand, or switch the import to the plugin's cache path once installed.

### Alternatives for the writing-for-agents job

Nobody else publishes a skill under that name. The nearest competitors do a different job: Anthropic's `skill-creator` (in [anthropics/skills](https://github.com/anthropics/skills), 176,008 stars) scaffolds and evaluates a skill package, and obra/superpowers `writing-skills` (285,827 stars) is a TDD-style process for testing a skill on subagents. Matt Pocock's text is the only one of the three that is about the writing itself: context pointers, the two loads, information hierarchy, leading words. Keep it, and keep `skill-creator` for the scaffolding.

## Proposed marketplace entries

For `daftdoki/dokidlc-plugins/.claude-plugin/marketplace.json`, once the two vendor repos exist:

```json
{
  "name": "unslop",
  "description": "Cut AI tells from any writing. pstack lineage, with the soul section and model invocation kept",
  "source": {
    "source": "github",
    "repo": "daftdoki/dokidlc-skill-unslop",
    "sha": "<pin after first commit>"
  }
},
{
  "name": "writing-for-agents",
  "description": "Writing documents for agents: skills, AGENTS.md, CLAUDE.md",
  "source": {
    "source": "github",
    "repo": "daftdoki/dokidlc-skill-writing-for-agents",
    "sha": "<pin after first commit>"
  }
}
```

Each vendor repo holds `SKILL.md` at the root (plus `SKILL-MECHANICS.md` for writing-for-agents), a `LICENSE` copied from upstream (both MIT), and a `SOURCE.md` in the format the local writing-for-agents already uses. [`unslop-SKILL.draft.md`](unslop-SKILL.draft.md) is the proposed unslop body; [`SOURCE-unslop.md`](SOURCE-unslop.md) and [`SOURCE-writing-for-agents.md`](SOURCE-writing-for-agents.md) are the provenance files.

## Files

| File | What it is |
|---|---|
| `README.md` | This report |
| `notes.md` | Work log: searches, dead ends, diffs, and the full lineage trail |
| `hash_copies.py` | Fetches every public `writing-for-agents/SKILL.md` and groups them by md5 against upstream |
| `unslop-SKILL.draft.md` | Proposed `SKILL.md` for `daftdoki/dokidlc-skill-unslop`: pstack `99559f2` plus rules 32 and 33 from `e8d856f`, two guards from unsloppify, model invocation kept |
| `SOURCE-unslop.md` | Provenance file for the unslop vendor repo |
| `SOURCE-writing-for-agents.md` | Provenance file for the writing-for-agents vendor repo, updated to the current upstream sha |
| `_summary.md` | One-paragraph summary spliced into the root README index |

## Original Prompt

> I use skills called unslop and writing-for-agents and I know that at least unslop has several different versions created by multiple folks. I want to identify the best of these two skills so that I can list them in my own claude plugin repository that I use.
