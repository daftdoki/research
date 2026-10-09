No existing product treats short-lived sessions as first-class guests, but three practical patterns enable local Claude Code to connect with centralized agents across projects. [Paperclip](https://github.com/paperclipai/paperclip) comes closest, allowing temporary sessions to authenticate as board members using expiring credentials and call its MCP server or CLI without permanent enrollment. The simplest path uses hosted services like CodeRabbit, Greptile, and Claude Code Review at user scope—setup takes minutes but scatters visibility across vendor dashboards. Building a custom hub via SessionStart/SessionEnd hooks and MCP gives full control but requires handling the 1.5-second SessionEnd timeout and implementing lease expiration.

Key findings:
- Paperclip's board-key auth and `board prompt --agent` command are the closest match to "guest" access today, though CLI paths are undocumented
- Easiest start: combine existing review/security services at user scope, pushing config via managed MCP
- [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) provides coordination primitives (per-session identity, time-limited file reservations) if building your own hub
