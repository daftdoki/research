Roon does not support Model Context Protocol (MCP) directly, but its extension SDK and the mature Python wrapper [`roonapi`](https://pypi.org/project/roonapi/) make building your own MCP server straightforward. The recommended approach is to wrap `pyroon` in a FastMCP server for digital music collection access, then integrate `python3-discogs-client` to bridge physical collections (vinyl/CD) via the Discogs API. While Home Assistant offers easy Roon integration with its built-in MCP server, it exposes only basic playback controls and lacks deep library features. Bridging both via a unified FastMCP server enables agents to reason across digital and physical collections, matching records by text or MusicBrainz ID for seamless querying.

**Key findings:**
- No existing MCP server for Roon; you must build one using `roonapi` (Python).
- Home Assistant MCP server is easiest to configure but limits feature depth.
- Discogs API, via `python3-discogs-client`, is optimal for physical collection integration.
- Combining Roon and Discogs APIs in one FastMCP server allows agents to match items across digital and physical catalogs.
- See [`roon_mcp_server.py`](roon_mcp_server.py) for a starting code skeleton.
