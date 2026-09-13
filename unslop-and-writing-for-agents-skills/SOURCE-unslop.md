Vendored from https://github.com/cursor/plugins
Path: pstack/skills/unslop/SKILL.md
Commit: 99559f2 (2026-08-02), plus rules 32 and 33 from e8d856f (2026-09-07)
Pulled: 2026-09-12
License: MIT (pstack/LICENSE, Lauren Tan)
Lineage: Wikipedia "Signs of AI writing", then blader/humanizer, then poteto/noodle, then cursor/plugins pstack

Kept against upstream HEAD:
- no `disable-model-invocation: true` (added upstream 73f8be4), so the agent
  applies it on its own
- the "Adding soul" section and rules 1, 2, 4, 6 and 21 (removed upstream e8d856f)
Added: a Guards section (facts and quoted text outrank the rules; do not
overcorrect into anti-slop register), after woerndl/unsloppify.

To update: diff against upstream at the path above and pull rule additions by hand.
