# Automating Bandcamp Collection Downloads and Reconciliation

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Is there a way to automate the process of reconciling a local music library against Bandcamp purchases and downloading any missing albums? The manual workflow -- browsing the Bandcamp collection page, checking what's already downloaded, and individually grabbing new purchases -- is tedious and error-prone. ([original prompt](#original-prompt))

## Answer

**Yes, several existing open-source tools solve this problem.** The best option for ongoing automated sync is [**bandcampsync**](https://github.com/meeb/bandcampsync), a Python tool (also available as a Docker container) that scans your local library, compares it against your full Bandcamp collection, and downloads only what's missing. It supports scheduled daily runs, FLAC and other lossless formats, and parallel downloads.

The one unavoidable manual step across *all* tools: **you must periodically export your Bandcamp session cookies from your browser**, because Bandcamp's login uses CAPTCHA and cannot be automated. In practice this means running a browser extension every few weeks. For additional and more detailed information see the [research notes](notes.md).

## Tool Landscape

Six notable tools exist for downloading Bandcamp collections. All use the same fundamental approach: authenticate via exported browser cookies, enumerate the collection by scraping, and hit Bandcamp's download endpoints.

| Tool | Language | Stars | Last Release | Best For |
|------|----------|-------|-------------|----------|
| [bandcampsync](https://github.com/meeb/bandcampsync) | Python | 318 | Jan 2026 | **Ongoing automated sync** |
| [bandcamp-downloader](https://github.com/easlice/bandcamp-downloader) | Python | 376 | Nov 2024 | One-off collection grabs |
| [bandsnatch](https://github.com/Ovyerus/bandsnatch) | Rust | 99 | Sep 2024 | Fast CLI with caching |
| [bandcamp-collection-downloader](https://github.com/Ezwen/bandcamp-collection-downloader) | Kotlin | 284 | -- | Auto Firefox cookie detection |
| [bcdl](https://github.com/corbin-zip/bcdl) | Python | 3 | -- | Searchable local database |
| [Batchcamp](https://github.com/hyphmongo/batchcamp) | JS (ext) | -- | -- | Manual bulk browser downloads |

## Recommended Setup: bandcampsync

### Why bandcampsync

- **Purpose-built for sync**: scans your local directory, compares against your remote Bandcamp collection, downloads only what's missing
- **Actively maintained**: latest release v0.7.0 (January 2026), uses `curl-cffi` for Cloudflare compatibility
- **Docker with scheduling**: built-in `RUN_DAILY_AT` for automated daily runs
- **Clean directory structure**: `Artist/Album/` layout with cover art, compatible with Plex/Jellyfin/Navidrome
- **Tracks downloads**: drops a `bandcamp_item_id.txt` in each album folder so it knows what it's already grabbed, even if you rename directories
- **Notifications**: HTTP callbacks when sync completes (can integrate with Gotify, ntfy, webhooks, etc.)

### Quick Start with pip

```bash
# Install
pip install bandcampsync

# Export your Bandcamp cookies to a file first (see "Cookie Export" below)

# Run a sync
bandcampsync -c cookies.txt -d /path/to/music --format flac

# Dry run to see what would be downloaded
bandcampsync -c cookies.txt -d /path/to/music --format flac --dry-run
```

### Quick Start with Docker

```bash
docker run -d \
  --name bandcampsync \
  -e RUN_DAILY_AT=3 \
  -v /path/to/cookies.txt:/cookies.txt \
  -v /path/to/music:/music \
  -e FORMAT=flac \
  ghcr.io/meeb/bandcampsync:latest
```

This runs a sync every day at 3 AM (with a randomized delay to avoid hammering Bandcamp).

### Configuration Options

| Option | CLI Flag | Docker Env | Default | Description |
|--------|----------|------------|---------|-------------|
| Cookies file | `-c` | Volume mount | -- | Path to exported cookies |
| Output directory | `-d` | Volume mount | -- | Where music is saved |
| Format | `--format` | `FORMAT` | `flac` | Audio format (flac, mp3-320, mp3-v0, wav, aiff-lossless, alac, aac-hi, vorbis) |
| Concurrency | `-j` | `CONCURRENCY` | `1` | Parallel downloads |
| Ignore artists | `-i` | `IGNORE` | -- | Skip specific artists |
| Notify URL | `-n` | `NOTIFY_URL` | -- | HTTP callback on completion |
| Max retries | `--max-retries` | `MAX_RETRIES` | `3` | Download retry attempts |
| Retry wait | `--retry-wait` | `RETRY_WAIT` | `5` | Seconds between retries |

### Cookie Export

Since Bandcamp uses CAPTCHA on login, all tools require you to export cookies from an authenticated browser session:

**Firefox:**
1. Install the [Cookie Quick Manager](https://addons.mozilla.org/en-US/firefox/addon/cookie-quick-manager/) extension
2. Log into Bandcamp
3. Export cookies for `bandcamp.com` in Netscape format
4. Save to a file (e.g., `cookies.txt`)

**Chrome:**
1. Install the [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) extension
2. Log into Bandcamp
3. Export cookies for the current site
4. Save to a file

Cookies typically remain valid for weeks to months. When bandcampsync starts failing to authenticate, re-export.

### Scheduling with cron (non-Docker)

```bash
# Run nightly at 2 AM
0 2 * * * /usr/local/bin/bandcampsync -c /path/to/cookies.txt -d /path/to/music --format flac >> /var/log/bandcampsync.log 2>&1
```

## Alternatives Worth Considering

### bandcamp-downloader (easlice)

Best if you want to **read cookies directly from your browser profile** without manually exporting:

```bash
pip install bandcamp-downloader
bandcamp-downloader <your-bandcamp-username> --browser firefox --format flac -d /path/to/music --parallel-downloads 4
```

Supports date filtering (`--download-since`, `--download-until`) which is useful for grabbing only recent purchases. Less suited for ongoing automation since it doesn't have built-in scheduling or Docker support, but works well with cron.

### bandsnatch

Best if you want a **fast, single-binary tool** with no runtime dependencies:

```bash
# Install via Homebrew
brew install bandsnatch

# Download collection
bandsnatch <username> -f flac -o /path/to/music -c cookies.json
```

Uses a cache file to track what's been downloaded, so subsequent runs are incremental. Written in Rust, so it's fast.

## What No Tool Can Do

- **Automate Bandcamp login**: CAPTCHA prevents this. You must maintain valid cookies manually.
- **Use an official API**: Bandcamp's API is only for labels/partners, not end-user collection access.
- **Guarantee long-term stability**: All tools rely on scraping Bandcamp's website. If Bandcamp changes their page structure or adds aggressive bot detection, tools may break (though the active ones have historically adapted quickly).

## Files

- `notes.md` -- Research notes and work log with detailed findings on each tool
- `README.md` -- This report

## Original Prompt

> I buy music from Bandcamp, which makes lossless digital downloads available. I keep these in a directory on my file system. However, Bandcamp does not provide an easy way to make sure I have downloaded everything automatically and I sometimes have to reconcile this manually myself by browsing my collection on their website and making sure I have the files downloaded. Also, when I purchase new music I have to manually grab them and process them into my directory structure. Is there a way to automate this reconciliation and new purchase download? An existing program, code, or other workflow? If not, can we build it?
