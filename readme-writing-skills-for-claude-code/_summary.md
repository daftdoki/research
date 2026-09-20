To write natural-sounding READMEs in Claude Code, combine two complementary tools rather than searching for one all-in-one solution. The `readme` skill from [johnsyweb/agent-skills](https://github.com/johnsyweb/agent-skills/tree/main/readme) handles structure across all four core asks (what it is, install, use, develop) while keeping small projects lean through source-based inclusion. Pair it with `unslop` for general text cleanup and `docs-doc` from [immagiov4/my-codex-skills](https://github.com/immagiov4/my-codex-skills/tree/main/skills/docs-doc) to remove README-specific AI prose.

- Most README skills are landing-page generators (badges, hero images); structural skills lack prose guidance
- johnsyweb is the only small skill covering all four asks and development sections
- Research includes a draft vendored skill combining johnsyweb's structure with README-specific anti-tells
