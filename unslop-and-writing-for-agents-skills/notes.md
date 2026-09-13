# Notes: best public versions of the unslop and writing-for-agents skills

## Goal

Find the public versions of two Claude Code skills, `unslop` and
`writing-for-agents`, compare them, and pick one of each to list in the
`dokidlc` plugin marketplace (`daftdoki/dokidlc-plugins`).

## Starting point (2026-09-12)

- Local `~/.claude/skills/unslop/SKILL.md` (6.6k, dated 2026-08-27). No SOURCE.md,
  so its origin is unknown. Its structure (Process / Adding soul / numbered
  pattern list) looks like blader/humanizer, which I need to confirm.
- Local `~/.claude/skills/writing-for-agents/` has SOURCE.md: vendored from
  mattpocock/skills at 6654f6b (2026-08-24), path
  skills/productivity/writing-for-agents, with agents/openai.yaml dropped.
- The marketplace today lists two plugins (questlog, memory), each in its own
  repo `daftdoki/dokidlc-skill-<name>`, pinned by sha in marketplace.json.

## Work log

### Where the local unslop came from

- GitHub code search `filename:SKILL.md path:unslop` returns 48 hits, and the
  commit messages in several of them ("vendor the pstack skill", "add outreach,
  pstack, and composio skills") point at one upstream: the `pstack` plugin in
  `cursor/plugins` (Lauren Tan, "poteto"), path `pstack/skills/unslop/SKILL.md`.
  MIT per `pstack/.cursor-plugin/plugin.json`.
- Diffed the local file against pstack at HEAD and at the first commit
  (24bd6eb, 2026-05-23). Local is byte-identical to a public copy in
  michaelshimeles/skills apart from the description line, and sits between
  pstack commits 99559f2 (2026-08-02) and 73f8be4 (2026-09-01). So the local
  copy is pstack's August 2026 version with no edits.
- pstack changed the skill twice after the local copy was taken:
  - 73f8be4 (2026-09-01) added `disable-model-invocation: true`. Upstream now
    fires only when someone types `/unslop`. michaelshimeles dropped that flag
    when vendoring, for the same reason I would.
  - e8d856f (2026-09-07, "density and mannered-prose pass") deleted the
    "Adding soul" section, deleted rules 1, 2, 4, 6 and 21 (numbers stay as
    gaps because "rule numbers are stable ids that other skills cite"), and
    added rule 32 (mannered prose) and rule 33 (over-compression). Net -20 +7
    lines.
- Dead end: mshumer/unslop (548 stars) is a Python tool that samples a model
  and writes a "what to avoid" profile. Not a prose-editing skill. howells/skills
  `unslop` is about code tells, with a separate `deslop` for prose. Both out.
- mattpocock/skills has no unslop skill and never had one (commit search for
  "unslop" in that repo returns 0).

### Prose unslop candidates found

| Repo | Stars | Pushed | License | SKILL.md size |
|---|---:|---|---|---:|
| cursor/plugins (pstack/skills/unslop) | 7,551 (whole repo) | 2026-09-13 | MIT | 6.1k |
| blader/humanizer | 47,337 | 2026-09-06 | MIT | 28.7k |
| theclaymethod/unslop | 406 | 2026-09-07 | MIT in frontmatter, no LICENSE file | 6.8k + references |
| MohamedAbdallah-14/unslop | 135 | 2026-09-07 | MIT | 16.3k |
| asavvin-pixel/unslop | 67 | 2026-07-14 (one day) | MIT | 17.4k |
| badmuriss/unslop | 19 | 2026-08-26 | NOASSERTION | 18.4k |
| woerndl/unsloppify | 17 | 2026-08-17 | NOASSERTION | 9.7k |
| mnapoli/skills (unslop) | 10 | 2026-08-28 | ? | 4.6k, "heavily inspired by Cursor's unslop" |
| Vuk97/unslop | 5 | 2026-08-18 | Apache-2.0 | (fetch failed, 14 bytes) |

### Full unslop lineage (confirmed by reading each commit)

1. Wikipedia, "Signs of AI writing" (the humanizer README names it as the source).
2. blader/humanizer, initial commit 63def2e on 2026-01-18. v2.0.0 the same day
   is "Complete rewrite based on Wikipedia source". Commit 35c699f on
   2026-01-19 adds "PERSONALITY AND SOUL" with the sentence "Avoiding AI
   patterns is only half the job. Sterile, voiceless writing is just as
   obvious as slop."
3. poteto/noodle (Lauren Tan's own repo), commit d0242cb on 2026-02-23:
   "Tightened version of the humanizer skill per skill-creator principles: no
   examples, no references, just the 24 patterns and the soul section. Renamed
   humanizer → unslop." 3.7k bytes, 24 rules in five groups.
4. cursor/plugins pstack, 24bd6eb on 2026-05-23, 27 rules (adds Jargon 26 and
   Plain speech 27), 6.3k bytes. Later grows to 31 rules by 99559f2
   (2026-08-02). This is the version the local copy matches.
5. pstack e8d856f (2026-09-07): soul section removed again, rules 1/2/4/6/21
   deleted, 32 and 33 added. 6.1k bytes, 28 live rules.

Code search for the soul sentence "Removing patterns is half the job" returns
674 files. That phrase exists only in the poteto lineage, so this is the most
copied unslop text on GitHub by a wide margin. pnpm/pnpm.io, Effect-TS/website
and JesusFilm/core carry it in their repos.

### What the other prose unslop skills are

- blader/humanizer v3.0.0 (2026-09-06): 25 patterns in five groups, ordered
  strongest first, with a "Why AI text sounds the way it does" preamble, a
  "How to work" section that forbids adding facts, a voice section, and a
  "When not to act" section. 28.7k bytes. Installable as a plugin on its own
  (`.claude-plugin/plugin.json` with `"skills": ["./"]`). 52 commits to
  SKILL.md, several outside contributors.
- theclaymethod/unslop v2.3.0: a slash-command product. `/unslop rewrite|
  cleanup|teach|mimic`, four voice presets, a core-contract reference, 50k
  taboo-phrase catalog, 20+ Python scripts, and a large eval suite. SKILL.md is
  a router; the behavior lives in references/. No LICENSE file in the repo
  (frontmatter says MIT). Its own SKILL.md uses em dashes.
- MohamedAbdallah-14/unslop v0.7.0: "ACTIVE EVERY RESPONSE" persistence rule,
  intensity modes (subtle/balanced/full/voice-match/anti-detector), hooks,
  benchmarks, and packaging for seven agent tools. 16k bytes, 18 em dashes in
  the skill text.
- asavvin-pixel/unslop: three levels (typography, vocabulary, structure and
  epistemics), leans on a 2026 UMD/DeepMind detection study the skill cites
  (61,608 texts, detection 95.5% to 93.9% after surface edits). 17k bytes.
  Created and last pushed on the same day, 2026-07-14.
- badmuriss/unslop: surface layer plus a "narrative layer" from the StoryScope
  paper (arXiv:2604.03136), with a pt-br gate. Fiction-oriented. CC BY-SA 4.0,
  which is share-alike and would bind a vendored copy.
- woerndl/unsloppify: six failure modes (importance inflation, manufactured
  drama, performative register, false precision, template filling, process
  leakage), each with a test, a banned list, an escape, and an example. Has a
  precedence rule for guards (facts beat quotes beat voice beat register beat
  anti-slop) and a "do not overcorrect into anti-slop register" guard. 9.7k
  bytes, zero em dashes in its own text, MIT. Ships a rg-based scanner.
- mnapoli/skills unslop: a rewrite of the pstack text with a French sibling.
- Vuk97/unslop: raw fetch returned 14 bytes (path guess wrong). 5 stars, one
  day of commits. Not pursued.

### Local writing-for-agents is upstream HEAD, and every public copy derives from it

- Local files are byte-identical to mattpocock/skills HEAD
  (skills/productivity/writing-for-agents/SKILL.md 10,886 bytes and
  SKILL-MECHANICS.md 2,629 bytes). The only upstream file dropped locally is
  agents/openai.yaml.
- History: created as `writing-great-skills` on 2026-06-17 (bc4cf90), renamed
  and restructured to `writing-for-agents` on 2026-07-23 (1fc6573), "cache"
  leading word added 2026-07-28, Codex model-invocation fix 2026-08-05, em
  dashes removed repo-wide 2026-08-19 (3216582). Nothing since.
- Code search `filename:SKILL.md path:writing-for-agents` returns 32 files. I
  fetched all 30 that matched the path pattern and md5-grouped them
  (hash_copies.py): 15 are byte-identical to upstream HEAD, 4 are the
  pre-2026-08-19 em-dash version, and the remaining 11 are personal edits:
  punctuation tweaks (pedroclobo), a "Cross-Client Portability" appendix
  (PracticalSwan), a version that swaps the leading-word section for a
  blander paragraph (dipsylala), one that ties it to a private "core
  contract" (dbolivar25), and three condensed rewrites of 2k to 4k bytes
  (malinskibeniamin, ArchdevilForge, carlitose).
- No independent skill named writing-for-agents exists. The competition for
  the job is different skills: Anthropic's skill-creator plugin, and Matt
  Pocock's own in-progress writing-beats/-fragments/-shape.
- mattpocock/skills is one Claude Code plugin (`mattpocock-skills`, source
  "./") carrying all 37 skills. There is no per-skill plugin upstream.

### How a marketplace can list a skill that lives inside someone else's repo

From code.claude.com/docs/en/plugin-marketplaces and /plugins-reference:
- `source: {"source": "git-subdir", "url": "owner/repo", "path": "...",
  "sha": "..."}` points at a subdirectory and pins it.
- A manifest is optional. "If a plugin has no skills/ directory and no skills
  manifest field, a SKILL.md at the plugin root is loaded as a single skill."
  The invocation name comes from the frontmatter `name`.
So `pstack/skills/unslop` and `skills/productivity/writing-for-agents` can
each be listed as a plugin without a fork. The cost: no control over
`disable-model-invocation: true`, which pstack added on 2026-09-01.

### Decision

- unslop: pstack lineage, vendored into daftdoki/dokidlc-skill-unslop from
  99559f2 (the local file) with rules 32 and 33 from e8d856f, a Guards section
  borrowed in spirit from unsloppify, and no disable-model-invocation flag.
  Draft in unslop-SKILL.draft.md. The deciding fact is the CLAUDE.md `@`
  import: the body is in context every turn, so 16k to 29k candidates are out
  regardless of quality.
- writing-for-agents: mattpocock/skills at 3216582, vendored as the local copy
  already is. No other independent version exists.
- Vendor rather than git-subdir: matches the two existing dokidlc repos, keeps
  control of frontmatter, and avoids cloning cursor/plugins or mattpocock/skills
  whole on each install.

### Things I could not verify without touching the host

- That a manifest-less plugin directory with a bare SKILL.md loads under the
  default `strict: true`. The docs say the manifest is optional; if it refuses,
  `strict: false` on the marketplace entry is the documented fallback.
- That the `@~/.claude/skills/unslop/SKILL.md` import keeps working after a
  plugin install. It will not on its own; plugins land in
  ~/.claude/plugins/cache/<marketplace>/<plugin>/<hash>/.

### Tooling notes

- `ls` in this shell hangs when piped or run at the end of a compound command
  (an alias, probably eza with git status). `/bin/ls` works.
- Commands in a `while read` loop lost PATH (base64 and md5 not found), so the
  copy hashing moved to hash_copies.py.
- curl to raw.githubusercontent.com works but took over two minutes for ten
  files; `gh api repos/.../contents/... --jq .content | base64 -d` is faster.
