# AI agent access to the *arr stack — Notes

## Goal

Find out how an AI agent (Claude Code etc.) can talk to Sonarr, Radarr, SABnzbd
and the rest of the *arr family, and ask a Neckbeard agent what the arrstack on
the host `frame` actually contains.

## Work log

- Branch: `claude/arrstack-ai-agent-access` (session started detached from main).
- `ListAgents` showed no peer sessions on this machine, so the SendMessage
  transport could not reach Neckbeard.
- `list_sessions` (claude-code-remote MCP) showed the Neckbeard sessions run in
  bridge environment `env_01AXySBjPTU1F6AUReA7LNmo`. Most `neckbeard@neckbeard`
  sessions were archived. `neckbeard-dhi` (session_01Ku3YAMLLyxjJcsdWgvzBfR,
  repo daftdoki/agent-neckbeard, branch neckbeard-9301) was idle and connected,
  so I sent it the question with `send_message`. Asked for: services and
  images, deployment/compose path, network layout, existing MCP/agent
  integrations, where API keys live (location only, no values).
- Started a background web-research subagent on native APIs, existing MCP
  servers, other agent routes, and security.
