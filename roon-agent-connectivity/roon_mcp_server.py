"""Minimal Roon MCP server skeleton.

This is a *starting point*, not a production server. It wires `pyroon`
(the community Python Roon API client, published on PyPI as `roonapi`)
into a FastMCP server so an MCP-compatible client (Claude Desktop, Claude
Code, etc.) can browse a Roon library, read zone state, and control
playback through natural language.

Prereqs:
    pip install roonapi mcp

First run:
    Roon Labs' extension model requires the user to approve the extension
    once in Roon → Settings → Extensions. On first launch this script
    writes a token to `roon_token.txt`; subsequent launches reuse it.

What's intentionally missing:
    - Error handling beyond the basics
    - Physical-collection (Discogs / MusicBrainz) tools — add a second
      module and register more @mcp.tool()s
    - Pagination for large browse results
    - Image fetching (the Roon image API returns URLs you can hand back)
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP
from roonapi import RoonApi, RoonDiscovery

APP_INFO = {
    "extension_id": "com.example.roon_mcp",
    "display_name": "Roon MCP Bridge",
    "display_version": "0.1.0",
    "publisher": "example",
    "email": "you@example.com",
    "website": "https://example.com",
}

TOKEN_PATH = Path(os.environ.get("ROON_TOKEN_PATH", "roon_token.txt"))

mcp = FastMCP("roon")


def _connect() -> RoonApi:
    """Discover a Roon Core on the LAN and connect to it."""
    token = TOKEN_PATH.read_text().strip() if TOKEN_PATH.exists() else None
    discover = RoonDiscovery(None)
    server = discover.first()  # (host, port) tuple
    discover.stop()
    if not server:
        raise RuntimeError("No Roon Core found on the network")
    api = RoonApi(APP_INFO, token, *server, blocking_init=True)
    # Persist the token so we don't have to re-authorize next launch.
    if api.token:
        TOKEN_PATH.write_text(api.token)
    return api


roon = _connect()


# ---------------------------------------------------------------------------
# Zones and now-playing
# ---------------------------------------------------------------------------


@mcp.tool()
def list_zones() -> list[dict[str, Any]]:
    """List every Roon zone with its current state and what's playing."""
    out: list[dict[str, Any]] = []
    for zone_id, zone in roon.zones.items():
        now = zone.get("now_playing") or {}
        three = now.get("three_line") or {}
        out.append(
            {
                "zone_id": zone_id,
                "display_name": zone.get("display_name"),
                "state": zone.get("state"),  # playing | paused | stopped | loading
                "outputs": [o.get("display_name") for o in zone.get("outputs", [])],
                "now_playing": {
                    "title": three.get("line1"),
                    "artist": three.get("line2"),
                    "album": three.get("line3"),
                    "seek_position": now.get("seek_position"),
                    "length": now.get("length"),
                }
                if now
                else None,
            }
        )
    return out


@mcp.tool()
def now_playing(zone_name: str) -> dict[str, Any] | None:
    """Get the currently playing track in a named zone."""
    zone_id = roon.zone_by_name(zone_name)
    if not zone_id:
        return None
    zone = roon.zones.get(zone_id, {})
    return zone.get("now_playing")


# ---------------------------------------------------------------------------
# Library browse / search
# ---------------------------------------------------------------------------


@mcp.tool()
def search_library(query: str, limit: int = 20) -> list[dict[str, Any]]:
    """Search the entire Roon library (local files + linked streaming services)
    and return the top matches across albums, artists, tracks, composers,
    playlists, etc.
    """
    # pyroon exposes `list_media(zone_id, path)` as a convenience. For search
    # we walk the browse tree: path=["Search", query] returns a mixed list of
    # hits organized by section (Artists, Albums, Tracks, ...).
    zone_id = next(iter(roon.zones), None)
    if not zone_id:
        return []
    items = roon.list_media(zone_id, ["Search", query]) or []
    return items[:limit]


@mcp.tool()
def list_albums_by_artist(artist: str, limit: int = 50) -> list[dict[str, Any]]:
    """Return albums by a specific artist from the Roon library."""
    zone_id = next(iter(roon.zones), None)
    if not zone_id:
        return []
    items = roon.list_media(zone_id, ["Library", "Artists", artist]) or []
    return items[:limit]


@mcp.tool()
def list_genres() -> list[str]:
    """Return every genre present in the Roon library."""
    zone_id = next(iter(roon.zones), None)
    if not zone_id:
        return []
    return [i.get("title", "") for i in roon.list_media(zone_id, ["Library", "Genres"]) or []]


@mcp.tool()
def list_tags() -> list[str]:
    """Return every custom tag the user has created. Useful for implementing
    a 'Vinyl' or 'I own this on CD' physical-media convention on top of Roon's
    tag system.
    """
    zone_id = next(iter(roon.zones), None)
    if not zone_id:
        return []
    return [i.get("title", "") for i in roon.list_media(zone_id, ["Library", "Tags"]) or []]


# ---------------------------------------------------------------------------
# Transport control
# ---------------------------------------------------------------------------


@mcp.tool()
def play_album(zone_name: str, artist: str, album: str) -> str:
    """Play a specific album by artist in a named zone."""
    zone_id = roon.zone_by_name(zone_name)
    if not zone_id:
        return f"no such zone: {zone_name}"
    ok = roon.play_media(zone_id, ["Library", "Artists", artist, album])
    return "ok" if ok else "failed"


@mcp.tool()
def control(zone_name: str, action: str) -> str:
    """Transport control. action in {play, pause, playpause, stop, next, previous}."""
    zone_id = roon.zone_by_name(zone_name)
    if not zone_id:
        return f"no such zone: {zone_name}"
    roon.playback_control(zone_id, action)
    return "ok"


@mcp.tool()
def set_volume(zone_name: str, level: int) -> str:
    """Set zone volume to an absolute level (0-100)."""
    zone_id = roon.zone_by_name(zone_name)
    if not zone_id:
        return f"no such zone: {zone_name}"
    roon.change_volume_percent(zone_id, level)
    return "ok"


if __name__ == "__main__":
    mcp.run()
