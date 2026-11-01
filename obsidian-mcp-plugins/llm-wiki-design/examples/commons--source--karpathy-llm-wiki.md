---
type: Source
title: "Karpathy: LLM Wiki (gist)"
summary: Pattern for an LLM-maintained, interlinked markdown wiki over immutable raw sources, with ingest/query/lint operations and index.md/log.md.
uuid: 3f2e9a10-1c44-4d7a-b6c2-9e8f1a7b5c33
resource: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
topics: [llm-wiki-pattern, personal-knowledge-management]
scope: {space: commons}
created: '2026-10-31T10:10:00Z'
updated: '2026-10-31T10:10:00Z'
status: stable
volatility: stable
generated: {by: agent:claude-code@nas#s-41f2, at: '2026-10-31T10:10:00Z'}
sources:
  - id: raw
    resource: raw/2026-10-31-karpathy-llm-wiki.md
    author: human:karpathy
    tier: T3
    retrieved: '2026-10-31'
    hash: sha256:5c28c2be23161080f936237494050d22500528f8425bc06d626aec83413855dc
---
## Key claims
- Three layers: immutable raw sources, an LLM-owned wiki, and a schema file.[^raw]
- Operations: ingest, query (good answers are filed back), lint.[^raw]
- index.md is enough "at moderate scale (~100 sources, ~hundreds of pages)"; beyond that, use search such as qmd.[^raw]

## Pages this source updated
[[llm-wiki-pattern]], [[qmd]], [[obsidian]]

[^raw]: Archived copy in raw/, hash above.
