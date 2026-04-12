# Research

Research projects carried out by AI tools. Each directory is a separate research project carried out by an LLM tool — usually [Claude Code](https://www.claude.com/product/claude-code). Every single line of text and code was written by an LLM.

This workflow is based on Simon Willison's [research repository](https://github.com/simonw/research) and his approach to [async code research with AI agents](https://simonwillison.net/2025/Nov/6/async-code-research/). The agent instructions, project structure, cogapp-powered README generation, and CI pipeline are all adapted from his original design.

Prompts and links to transcripts are included in [the PRs](https://github.com/daftdoki/research/pulls?q=is%3Apr+is%3Aclosed) that added each report, or in [the commits](https://github.com/daftdoki/research/commits/main/).

*Times shown are in UTC.*

<!--[[[cog
import os
import re
import subprocess
import pathlib
from datetime import datetime, timezone

# Model to use for generating summaries
MODEL = "github/gpt-4.1"

# Safety cap for the text we pipe into `llm`. Keeps us comfortably under
# GitHub Models' 8000-token input cap for gpt-4.1 even on projects that
# omit the standard Question/Goal and Answer/Summary headers and therefore
# fall back to the full README.
LLM_INPUT_MAX_CHARS = 20000


def extract_summary_input(readme_text):
    """Return just the parts of a research README that matter for a short
    index-page summary: the title (H1) plus the "## Question / Goal" and
    "## Answer / Summary" H2 sections that AGENTS.md mandates. Falls back
    to the full README if neither section is present. In all cases the
    result is truncated to LLM_INPUT_MAX_CHARS so the llm call stays
    within GitHub Models' input token cap."""
    lines = readme_text.splitlines()

    title_line = next((ln for ln in lines if ln.startswith('# ')), None)

    # Split on H2 headers.
    sections = {}  # heading text (lowercase) -> (original heading line, body)
    current_heading = None
    current_body = []
    for ln in lines:
        if ln.startswith('## '):
            if current_heading is not None:
                sections[current_heading.lower()] = (current_heading, '\n'.join(current_body).rstrip())
            current_heading = ln[3:].strip()
            current_body = []
        elif current_heading is not None:
            current_body.append(ln)
    if current_heading is not None:
        sections[current_heading.lower()] = (current_heading, '\n'.join(current_body).rstrip())

    def find(*needles):
        for key, value in sections.items():
            if all(needle in key for needle in needles):
                return value
        return None

    goal = find('goal') or find('question')
    summary = find('summary') or find('answer')

    if goal is None and summary is None:
        # No standard headers - fall back to the full README, still capped.
        return readme_text[:LLM_INPUT_MAX_CHARS]

    parts = []
    if title_line:
        parts.append(title_line)
    for section in (goal, summary):
        if section is not None:
            heading, body = section
            parts.append(f"## {heading}\n\n{body}")
    return '\n\n'.join(parts)[:LLM_INPUT_MAX_CHARS]


# Get all subdirectories with their first commit dates
research_dir = pathlib.Path.cwd()
subdirs_with_dates = []

for d in research_dir.iterdir():
    if d.is_dir() and not d.name.startswith('.') and not d.name.startswith('_'):
        # Get the date of the first commit that touched this directory
        try:
            result = subprocess.run(
                ['git', 'log', '--diff-filter=A', '--follow', '--format=%aI', '--reverse', '--', d.name],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                # Parse first line (oldest commit)
                date_str = result.stdout.strip().split('\n')[0]
                commit_date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                subdirs_with_dates.append((d.name, commit_date))
            else:
                # No git history, use directory modification time
                subdirs_with_dates.append((d.name, datetime.fromtimestamp(d.stat().st_mtime, tz=timezone.utc)))
        except Exception:
            # Fallback to directory modification time
            subdirs_with_dates.append((d.name, datetime.fromtimestamp(d.stat().st_mtime, tz=timezone.utc)))

# Print the heading with count
print(f"## {len(subdirs_with_dates)} research projects\n")

# Sort by date, most recent first
subdirs_with_dates.sort(key=lambda x: x[1], reverse=True)

for dirname, commit_date in subdirs_with_dates:
    folder_path = research_dir / dirname
    readme_path = folder_path / "README.md"
    summary_path = folder_path / "_summary.md"

    date_formatted = commit_date.astimezone(timezone.utc).strftime('%Y-%m-%d %H:%M')

    # Build GitHub URL
    github_url = f"https://github.com/daftdoki/research/tree/main/{dirname}"

    # Extract title from first H1 header in README, fallback to dirname
    title = dirname
    if readme_path.exists():
        with open(readme_path, 'r') as f:
            for readme_line in f:
                if readme_line.startswith('# '):
                    title = readme_line[2:].strip()
                    break

    print(f"### [{title}]({github_url}#readme) ({date_formatted})\n")

    # Check if summary already exists
    if summary_path.exists():
        # Use cached summary
        with open(summary_path, 'r') as f:
            description = f.read().strip()
            if description:
                print(description)
            else:
                print("*No description available.*")
    elif readme_path.exists():
        # Generate new summary using llm command. We pipe only the parts of
        # the README that matter for the summary (title + Question/Goal +
        # Answer/Summary), trimmed to LLM_INPUT_MAX_CHARS, so long reports
        # stay within the model's input token cap.
        with open(readme_path, 'r') as f:
            llm_input = extract_summary_input(f.read())
        prompt = """Summarize this research project concisely. Write just 1 paragraph (3-5 sentences) followed by an optional short bullet list if there are key findings. Vary your opening - don't start with "This report" or "This research". Include 1-2 links to key tools/projects. Be specific but brief. No emoji."""
        result = subprocess.run(
            ['llm', '-m', MODEL, '-s', prompt],
            input=llm_input,
            capture_output=True,
            text=True,
            timeout=60
        )
        if result.returncode != 0:
            error_msg = f"LLM command failed for {dirname} with return code {result.returncode}"
            if result.stderr:
                error_msg += f"\nStderr: {result.stderr}"
            raise RuntimeError(error_msg)
        if result.stdout.strip():
            description = result.stdout.strip()
            print(description)
            # Save to cache file
            with open(summary_path, 'w') as f:
                f.write(description + '\n')
        else:
            raise RuntimeError(f"LLM command returned no output for {dirname}")
    else:
        print("*No description available.*")

    print()  # Add blank line between entries

# Add AI-generated note to all project README.md files
# Note: we construct these marker strings via concatenation to avoid the HTML comment close sequence
AI_NOTE_START = "<!-- AI-GENERATED-NOTE --" + ">"
AI_NOTE_END = "<!-- /AI-GENERATED-NOTE --" + ">"
AI_NOTE_CONTENT = """> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research)."""

NOT_AI_GENERATED = "<!-- not-ai-generated --" + ">"

for dirname, _ in subdirs_with_dates:
    folder_path = research_dir / dirname
    readme_path = folder_path / "README.md"

    if not readme_path.exists():
        continue

    content = readme_path.read_text()

    # Skip files marked as not AI-generated
    if NOT_AI_GENERATED in content:
        continue

    # Check if note already exists
    if AI_NOTE_START in content:
        # Replace existing note
        pattern = re.escape(AI_NOTE_START) + r'.*?' + re.escape(AI_NOTE_END)
        new_note = f"{AI_NOTE_START}\n{AI_NOTE_CONTENT}\n{AI_NOTE_END}"
        new_content = re.sub(pattern, new_note, content, flags=re.DOTALL)
        if new_content != content:
            readme_path.write_text(new_content)
    else:
        # Add note after first heading (# ...)
        lines = content.split('\n')
        new_lines = []
        note_added = False
        for i, line in enumerate(lines):
            new_lines.append(line)
            if not note_added and line.startswith('# '):
                # Add blank line, then note, then blank line
                new_lines.append('')
                new_lines.append(AI_NOTE_START)
                new_lines.append(AI_NOTE_CONTENT)
                new_lines.append(AI_NOTE_END)
                note_added = True

        if note_added:
            readme_path.write_text('\n'.join(new_lines))

]]]-->
## 5 research projects

### [Bambu Lab H2D Camera: External Access Options](https://github.com/daftdoki/research/tree/main/bambu-h2d-camera-access#readme) (2026-04-11 19:51)

The Bambu Lab H2D's built-in chamber camera can be accessed externally via a LAN-only RTSPS (RTSP-over-TLS) stream, allowing integration with various third-party applications such as Home Assistant (via the [ha-bambulab integration](https://github.com/greghesp/ha-bambulab)), VLC, OctoEverywhere, Blue Iris, and others. To enable this, "LAN Only Liveview" must be toggled on in the printer's settings, and the stream is accessed at `rtsps://bblp:<ACCESS_CODE>@<PRINTER_IP>:322/streaming/live/1` using your printer's LAN Access Code. The toolhead calibration camera remains inaccessible outside Bambu's ecosystem, and no ONVIF or HTTP snapshot endpoints are provided. Sub-second latency for Home Assistant is achievable with tools like [go2rtc](https://github.com/AlexxIT/go2rtc).

**Key Findings:**
- Chamber camera stream is available via secure LAN-only RTSPS, compatible with many tools but not cloud-direct.
- Only the chamber camera is exposed; nozzle (toolhead) camera is not externally accessible.
- Adding to Home Assistant is easiest with the ha-bambulab integration, with go2rtc/WebRTC Card recommended for lowest latency.

### [Roon Agent Connectivity: MCP and Other Options](https://github.com/daftdoki/research/tree/main/roon-agent-connectivity#readme) (2026-04-11 03:58)

Roon does not support Model Context Protocol (MCP) directly, but its extension SDK and the mature Python wrapper [`roonapi`](https://pypi.org/project/roonapi/) make building your own MCP server straightforward. The recommended approach is to wrap `pyroon` in a FastMCP server for digital music collection access, then integrate `python3-discogs-client` to bridge physical collections (vinyl/CD) via the Discogs API. While Home Assistant offers easy Roon integration with its built-in MCP server, it exposes only basic playback controls and lacks deep library features. Bridging both via a unified FastMCP server enables agents to reason across digital and physical collections, matching records by text or MusicBrainz ID for seamless querying.

**Key findings:**
- No existing MCP server for Roon; you must build one using `roonapi` (Python).
- Home Assistant MCP server is easiest to configure but limits feature depth.
- Discogs API, via `python3-discogs-client`, is optimal for physical collection integration.
- Combining Roon and Discogs APIs in one FastMCP server allows agents to match items across digital and physical catalogs.
- See [`roon_mcp_server.py`](roon_mcp_server.py) for a starting code skeleton.

### [Discogs MCP Servers for a Collection + Wantlist Agent](https://github.com/daftdoki/research/tree/main/discogs-mcp-servers#readme) (2026-04-11 03:55)

Several Discogs MCP servers are available for interacting with a user's music collection and wantlist, but [cswkim/discogs-mcp-server](https://github.com/cswkim/discogs-mcp-server) stands out as the only one providing comprehensive, first-class tools for both collection and wantlist management, making it the best foundation for an interactive agent. [rianvdm/discogs-mcp](https://github.com/rianvdm/discogs-mcp) offers a superior OAuth authentication flow and unique recommendation features but lacks wantlist support, while [michielryvers/discogs-mcp](https://www.nuget.org/packages/discogs-mcp) is a flexible but low-level REST wrapper not optimized for LLM interaction. To cover the digital collection aspect, pairing a Discogs-focused MCP server with a local music MCP project like [gorums/music-mcp-server](https://github.com/gorums/music-mcp-server) is recommended, as no Discogs server natively handles local digital files.

Key findings:
- **cswkim/discogs-mcp-server**: Best overall; fully supports collection and wantlist; actively developed.
- **rianvdm/discogs-mcp**: Best authentication and recommendations, but lacks wantlist tools.
- **michielryvers/discogs-mcp**: Thin, generic wrapper providing maximum flexibility but minimal user-friendliness.
- No single MCP server supports both Discogs (physical) and local digital libraries; combining separate servers is necessary for full coverage.

### [Automating Bandcamp Collection Downloads and Reconciliation](https://github.com/daftdoki/research/tree/main/bandcamp-download-automation#readme) (2026-04-10 15:40)

Automating reconciliation and download of Bandcamp collections can be streamlined using open-source tools like [bandcampsync](https://github.com/meeb/bandcampsync), which compares your local music library against your Bandcamp purchases and downloads only missing albums. bandcampsync supports scheduled runs, multiple audio formats, and parallel downloads, ideal for ongoing syncing, but requires periodic manual export of Bandcamp session cookies due to CAPTCHA-protected logins. Alternatives such as [bandcamp-downloader](https://github.com/easlice/bandcamp-downloader) and bandsnatch offer one-off or fast sync capabilities, but none can fully automate login or guarantee against changes in Bandcamp's web interface. All solutions rely on scraping with browser cookies, making periodic cookie refreshes necessary for authentication.

**Key Findings:**
- bandcampsync is best for automated, incremental syncing with Docker and scheduling options.
- All tools require manual export of valid session cookies; Bandcamp login automation is not possible.
- Support exists for lossless formats, parallel downloads, and directory organization.
- Long-term reliability depends on Bandcamp's web design and bot detection changes.

### [Python Equivalent of Tailscale's tsnet](https://github.com/daftdoki/research/tree/main/python-tsnet-research#readme) (2026-04-08 05:49)

No production-quality Python equivalent to Tailscale's tsnet currently exists; the only near option is experimental Python bindings provided in Tailscale’s [`libtailscale`](https://github.com/tailscale/libtailscale/tree/main/python) C library repository. These bindings allow embedding a Tailscale node directly in Python, but they require manual build steps, are not published to PyPI, and are reportedly broken as of mid-2024. Third-party Python libraries for direct embedding do not exist, nor are there Python-native implementations. Most practical Python integrations rely on running the `tailscaled` daemon as a subprocess and communicating via its local UNIX socket API, using libraries like [`tslocal`](https://github.com/bouk/tslocal) or `tailscale_localapi`.

Key findings:
- Experimental libtailscale Python bindings exist but are hard to build and not production-ready.
- All Python Tailscale ecosystem packages are API clients, not node embedders.
- Running `tailscaled` as a subprocess and controlling it via the local API is the recommended, supported pattern for Python integration.

<!--[[[end]]]-->
