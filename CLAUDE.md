@AGENTS.md

## PR formatting

When creating a pull request, always format the PR body so that the **first section** is labeled `## Prompt` and contains the verbatim text of the original user prompt, quoted in a blockquote (`>`). The rest of the PR description follows after that quoted section.

## Memory <!-- memory -->

`.memory/` holds what past sessions learned. A hook names matching pages when you are prompted; read them before you investigate. Search yourself before an install, a config change, or a design choice, and when the creator says "remember" or "did we". When something took more than one attempt, write it: `memory write`. A page you find wrong, fix or delete in the same turn. The `memory` skill has the rules.
