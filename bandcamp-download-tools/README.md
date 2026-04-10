# Bandcamp Collection Download Tools: A Comprehensive Survey

## Question / Goal

What tools, scripts, and programs exist for automating the download of a user's Bandcamp music collection? This investigation covers official APIs, open-source CLI tools, browser extensions, userscripts, and Python packages -- along with their current maintenance status, capabilities, and known limitations in the post-Songtradr era.

## Answer / Summary

There is **no official Bandcamp API for downloading purchased music**. The official API (bandcamp.com/developer) only serves labels/partners for merch orders and sales reports. All collection download tools are third-party and rely on **scraping + cookie-based authentication**, since Bandcamp's login uses reCAPTCHA which prevents automated sign-in.

The ecosystem is healthy with 10+ actively maintained tools across multiple languages. The best options in April 2026 are:

- **For most users**: [bandcampsync](https://github.com/meeb/bandcampsync) (Python, Docker support, most recently released) or [easlice/bandcamp-downloader](https://github.com/easlice/bandcamp-downloader) (Python, automatic browser cookie extraction)
- **For browser-based bulk download**: [Batchcamp](https://github.com/hyphmongo/batchcamp) (Chrome/Firefox extension)
- **For Windows GUI users**: [BandcampDownloader](https://github.com/Otiel/BandcampDownloader) (C#/.NET desktop app, but only downloads 128kbps preview streams -- not purchased quality)
- **For Rust enthusiasts**: [bandsnatch](https://github.com/Ovyerus/bandsnatch)

The Songtradr acquisition (Nov 2023) has **not broken** existing tools in any major way. Bandcamp's collection page structure remains largely intact, and cookie-based authentication still works.

---

## 1. Official Bandcamp API

**URL**: https://bandcamp.com/developer

The official API is **not useful for downloading music**. It is restricted to labels and fulfillment partners and covers only:

| Endpoint | Purpose |
|----------|---------|
| Account API | Account management |
| Sales Report API | Sales data in JSON |
| Merch Orders API | Query orders, mark shipped |

- **Authentication**: OAuth 2.0 (client credentials flow, tokens expire after 1 hour)
- **Access**: Must contact Bandcamp with a description of intended use; not publicly available
- **Key limitation**: No endpoints for fan purchases, collections, or music downloads

---

## 2. Collection Download Tools (CLI / Desktop)

These tools download your **purchased** music in full quality. They are the most feature-complete category.

### 2a. easlice/bandcamp-downloader (Python)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/easlice/bandcamp-downloader |
| **Stars** | 376 |
| **Language** | Python |
| **Method** | Scraping + browser cookie extraction (via browser_cookie3) |
| **Last release** | v0.2.0, November 2024 |
| **Formats** | aac-hi, aiff-lossless, alac, flac, mp3-320, mp3-v0, vorbis, wav |

**Key features:**
- Automatic cookie extraction from Firefox, Chrome, Chromium, Brave, Opera, Edge
- Manual Netscape-format cookie file support as fallback
- Parallel downloads (1-32 threads, default 5)
- File size verification to skip already-downloaded items
- Date-range filtering by purchase date
- Archive extraction with cleanup
- Dry-run mode
- Retry logic (default 5 attempts)

**Known issues:**
- browser_cookie3 Chrome decryption can fail (upstream bug)
- WSL crashes due to DBUS/keyring issues
- Flatpak/Snap browser installs require manual cookie path
- Some reports of `KeyError: 'content-length'` in recent issues
- "Redownloading purchased albums is broken" (issue #46)

---

### 2b. meeb/bandcampsync (Python)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/meeb/bandcampsync |
| **Stars** | 318 |
| **Language** | Python |
| **Method** | Scraping + manual cookie extraction |
| **Last release** | v0.7.0, January 2026 |
| **Formats** | flac (default), mp3-320, mp3-v0, aac-hi, alac, aiff, vorbis, wav |

**Key features:**
- Five-step process: authenticate, scan local files, index collection, download missing, extract
- `bandcamp_item_id.txt` marker files for tracking downloads without re-fetching
- Docker container (`ghcr.io/meeb/bandcampsync:latest`) with scheduled daily syncs
- Configurable concurrency and retry logic
- Compatible with Lidarr and other media managers
- Ignore file for skipping problematic items

**Known issues:**
- Requires manual cookie extraction from browser dev tools (no automatic browser cookie reading)
- Cookie file is a security-sensitive credential
- Depends on beautifulsoup4 and curl-cffi

---

### 2c. Ezwen/bandcamp-collection-downloader (Kotlin)

| Field | Detail |
|-------|--------|
| **URL** | https://framagit.org/Ezwen/bandcamp-collection-downloader (official) / https://github.com/Ezwen/bandcamp-collection-downloader (mirror) |
| **Stars** | 284 (GitHub mirror) |
| **Language** | Kotlin |
| **Method** | Scraping + browser cookie extraction |
| **Last activity** | 185 commits, active |
| **Formats** | flac, wav, aac-hi, mp3-320, aiff, vorbis, mp3-v0, alac |

**Key features:**
- Automatic Firefox cookie reading (v74.0+, Windows/Linux)
- Manual cookie export via Cookie Quick Manager (Firefox) or Get cookies.txt LOCALLY (Chrome)
- Parallel downloads (default 4 threads)
- Caching system to avoid redundant downloads
- Dry-run mode
- Artist/year-album folder organization
- Distributed as executable JAR

**Known issues:**
- 27 open issues on GitHub mirror
- Cannot read Firefox container tab cookies
- "Could not connect to the Bandcamp API with the provided cookies" is a recurring issue
- GitHub is only a mirror; official repo on Framagit

---

### 2d. Ovyerus/bandsnatch (Rust)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/Ovyerus/bandsnatch |
| **Stars** | 99 |
| **Language** | Rust |
| **Method** | Scraping + manual cookie extraction |
| **Last release** | v0.3.3, September 2024 |
| **Formats** | flac, wav, aac-hi, mp3-320, aiff-lossless, vorbis, mp3-v0, alac |

**Key features:**
- Cache file to track previously downloaded items (incremental sync)
- Parallel processing (default 4 jobs)
- Dry-run mode
- Force refresh to ignore cache
- Environment variable configuration for automation
- Supports both cookies.json and cookies.txt formats

**Known issues:**
- Developer describes it as "still currently a work in progress"
- First substantial Rust project by the author
- 7 open issues
- Large collections may need more testing

---

### 2e. Metalnem/bandcamp-downloader (C#)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/Metalnem/bandcamp-downloader |
| **Stars** | 22 |
| **Language** | C# |
| **Method** | Direct login with username/password |
| **Last activity** | 33 commits, updated April 2026 |
| **Formats** | MP3 V0 only |

**Key features:**
- Lists all items in collection
- Can filter for "disabled" (removed from Bandcamp) albums
- Targeted download by album ID
- One of the few tools that uses direct credentials instead of cookies

**Known issues:**
- Only supports MP3 V0 format
- Direct credential login may break if Bandcamp changes auth flow
- Minimal feature set compared to alternatives

---

### 2f. iliana/bandcamp-dl (Python)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/iliana/bandcamp-dl |
| **Stars** | 64 |
| **Language** | Python |
| **Method** | Undocumented Bandcamp API + cookie authentication |
| **Last commit** | December 2020 |
| **Formats** | flac (default), aac-hi, aiff-lossless, alac, mp3-320, mp3-v0, vorbis, wav |

**Key features:**
- Uses undocumented Bandcamp API endpoints
- Automatic cookie extraction via browser_cookie3 or manual `--identity` flag
- Downloads albums as ZIP files, tracks as individual files

**Known issues:**
- **Unmaintained since December 2020**
- Author explicitly states "may break at any time" and "will not provide support"
- Uses undocumented APIs that are subject to change

---

## 3. Public Page / Free Music Downloaders

These tools download publicly accessible content (128kbps preview streams or free/PWYW releases). They do **not** require authentication.

### 3a. Otiel/BandcampDownloader (C# / Windows)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/Otiel/BandcampDownloader |
| **Stars** | 1,164 (highest-starred Bandcamp tool) |
| **Language** | C# |
| **Method** | Extracts 128kbps MP3 preview streams |
| **Last release** | v1.5.2, December 2025 |
| **Formats** | MP3 128kbps only |

**Key features:**
- Windows GUI (WPF) application
- Downloads from album, track, and artist pages
- Adds ID3 tags (album, artist, title, track number, year, lyrics)
- Downloads and embeds album artwork
- Creates playlist files (m3u, pls, wpl, zpl)
- No authentication required

**Known issues:**
- **Only 128kbps quality** -- preview streams, not purchased quality
- 54 open issues, many crash reports
- "Could not retrieve data" errors reported
- Windows-only

---

### 3b. Evolution0/bandcamp-dl (Python)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/Evolution0/bandcamp-dl |
| **Stars** | 1,138 |
| **Language** | Python |
| **Method** | Web scraping (BeautifulSoup, Demjson) |
| **Last release** | v0.0.17, March 2025 |
| **PyPI** | `pip install bandcamp-downloader` |
| **Formats** | Depends on page availability (typically MP3/FLAC) |

**Key features:**
- Individual tracks, complete albums, and full discographies
- ID3 tag embedding (artist, album, track, lyrics, genres)
- Album art download with configurable quality
- Flexible filename templates (`%{artist}`, `%{album}`, etc.)
- Text processing (slugify, ASCII conversion, case handling)
- No authentication required

**Known issues:**
- 23 open issues
- Downloads publicly available content only (not purchased quality for all formats)
- Relies on page scraping, vulnerable to Bandcamp layout changes

---

### 3c. daot/bcdl (Go)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/daot/bcdl |
| **Stars** | 55 |
| **Language** | Go |
| **Method** | Simulates free/PWYW purchase flow |
| **Last release** | December 2025 |

**Key features:**
- Downloads actual full-quality files (not 128kbps rips) for free/PWYW releases
- Batch download from URL list
- Library tracking via config.json

---

### 3d. 7x11x13/free-bandcamp-downloader (Python)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/7x11x13/free-bandcamp-downloader |
| **Stars** | 37 |
| **Language** | Python |
| **PyPI** | `pip install free-bandcamp-downloader` (command: `bcdl-free`) |
| **Method** | Automates free/PWYW purchase process |
| **Formats** | flac, mp3 (V0/320), aac, ogg, alac, wav, aiff |

**Key features:**
- Downloads free and $0-minimum name-your-price releases in lossless quality
- Automatic metadata tagging
- Disposable email support (set email to 'auto')
- Download history tracking
- Batch downloading from labels/artist pages
- Can also access authenticated collection via identity cookie

---

### 3e. Other notable tools

- **cisoun/bandcamp-downloader** (Python, 48 stars) -- Simple MP3 downloader from Bandcamp pages. Inactive since 2020.
- **campdown** (Python, PyPI: `pip install campdown`) -- CLI for public tracks. Last update December 2020. Dormant.
- **bandripper** (Python, PyPI: `pip install bandripper`) -- Downloads albums at 128kbps. Last update October 2025. Has release monitoring feature.

---

## 4. Browser Extensions

### 4a. Batchcamp

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/hyphmongo/batchcamp |
| **Stars** | 123 |
| **Language** | TypeScript |
| **Available on** | Chrome Web Store, Firefox Add-ons |

**Key features:**
- Select multiple/all releases from collection or purchases page
- Automatic queueing and downloading
- Progress monitoring in dedicated tab
- Retry for failed downloads
- Configurable default format and concurrency
- No cookie export needed -- runs within authenticated browser context

**Known issues:**
- 7 open issues
- Depends on Bandcamp's page structure remaining stable

---

### 4b. KeepTune

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/jaymoulin/keeptune |
| **Stars** | 76 |
| **Language** | JavaScript |
| **Last release** | v3.1.5, January 2026 |

**Key features:**
- Detects listenable albums and shows download notification
- Downloads from Bandcamp and SoundCloud
- Batch downloading via dedicated page
- Retry for failed tracks
- ZIP output with folder organization

**Known issues:**
- **Removed from Chrome Web Store** (policy non-compliance)
- Must install manually from keeptune.jaymoulin.me
- Maintenance depends on sponsorship

---

## 5. Userscripts (Greasemonkey / Tampermonkey)

### 5a. Bandcamp-Greasy

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/RyanBluth/Bandcamp-Greasy |
| **Stars** | 306 |
| **Language** | JavaScript |
| **Method** | Injects UI into Bandcamp collection page |

**Key features:**
- Two scripts: DownloadCollection.user.js (scans collection) + DownloadAlbum.user.js (downloads)
- 8 format options (MP3 320 default, V0, FLAC, AAC, Ogg, ALAC, WAV, AIFF)
- Works in Firefox (Greasemonkey) and Chrome (Tampermonkey)
- Configurable username and format

**Known issues:**
- 13 open issues, 3 open PRs
- HTTP 429 rate limiting reported (issue #17)
- No formal releases or versioning
- No guarantee of compatibility with current Bandcamp page structure

### 5b. Greasy Fork Scripts

Several smaller userscripts are available at https://greasyfork.org/en/scripts/by-site/bandcamp.com:

- **Bandcamp download mp3s** (cuzi) -- 3,481 installs. Shows download links for preview files. Updated Feb 2024.
- **Bandcamp Album and Singles MP3 Downloader** (invulBox) -- 63 installs. Individual or bulk track download. Updated Jul 2025.
- **Bandcamp download mp3s (single + bulk)** -- 37 installs. Per-track and bulk download links. Updated Sep 2025.
- **Bandcamp Downloader (w/ metadata)** (sudoker0) -- 20 installs. Downloads 128kbps with metadata. Updated Jan 2026.
- **BC: do free downloads** -- 198 installs. Automates free download flow. Updated Oct 2024.

---

## 6. Developer Libraries (Not End-User Tools)

### 6a. bandcamp-fetch (Node.js)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/patrickkfkan/bandcamp-fetch |
| **npm** | `bandcamp-fetch` |
| **Stars** | 72 |

A scraping library for building other tools. Fetches albums, tracks, artist info, fan collections, wishlists, search results, and Bandcamp Daily articles. Supports authenticated sessions via cookie for high-quality streams and private collection access. 0 open issues.

### 6b. bandcamp-scraper (Node.js)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/masterT/bandcamp-scraper |
| **npm** | `bandcamp-scraper` |

Older scraping library. Inspiration for bandcamp-fetch.

---

## 7. Browser Automation Tools

### 7a. corbin-zip/bcdl (Python + Selenium)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/corbin-zip/bcdl |
| **Stars** | 3 |
| **Method** | Selenium browser automation with Firefox/Geckodriver |

Uses Selenium to log in, scroll through collection, build SQLite database of owned albums, and manage batch downloads. Supports 8 formats.

### 7b. impaler/bandcamp-dl (JavaScript, ARCHIVED)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/impaler/bandcamp-dl |
| **Stars** | 31 |
| **Status** | Archived |

Browser automation script for batch downloading. No longer maintained.

### 7c. marekceglowski/Bandcamp-Download-Automation (Python + PhantomJS)

| Field | Detail |
|-------|--------|
| **URL** | https://github.com/marekceglowski/Bandcamp-Download-Automation |
| **Status** | **Broken** -- README states "This project is now outdated, it won't work with Bandcamp's current webpage format!" |

Used Splinter/PhantomJS for headless browser automation. No longer functional.

---

## 8. Docker / Self-Hosted Solutions

| Tool | Docker Image | Features |
|------|-------------|----------|
| bandcampsync | `ghcr.io/meeb/bandcampsync:latest` | Scheduled daily syncs, timezone config, UID/GID mapping |
| bandcamp-downloader-docker | `chooban/bandcamp-downloader-docker` | Containerized wrapper around easlice/bandcamp-downloader (37 stars) |

---

## 9. Cross-Cutting Issues and Limitations

### Authentication
Every collection download tool faces the same fundamental challenge: Bandcamp uses Google reCAPTCHA on login, so automated tools **cannot log in programmatically**. All tools require users to:
1. Log into Bandcamp in a browser
2. Extract the session cookie (especially the `identity` cookie)
3. Provide it to the tool (automatically via browser_cookie3, or manually)

The browser_cookie3 library (used by several Python tools) has recurring issues:
- Chrome cookie decryption failures
- WSL/DBUS keyring access errors
- Flatpak/Snap browser installations use non-standard paths

### Rate Limiting
Bandcamp returns HTTP 429 errors when too many downloads are requested too quickly. This is a deliberate server-side measure. Tools handle this with:
- Configurable concurrency (typically 1-5 parallel downloads)
- Retry logic with backoff
- Randomized delays between requests

### Post-Songtradr Acquisition (November 2023)
- ~50% of Bandcamp staff were laid off
- Core site functionality and collection/download pages remain intact
- New features added: Playlists (May 2025), Clubs (Sep 2025), Stripe payments (summer 2025)
- No wholesale site redesign that broke download tools
- Some tools report intermittent "Could not retrieve data" errors
- The collection page API structure appears largely unchanged

### Legal/Ethical Considerations
- Collection downloaders access music you have **already purchased** -- this is generally considered legitimate personal backup
- Preview stream rippers (128kbps) access what is "already freely available on Bandcamp" for streaming
- Free/PWYW downloaders automate a process any user could do manually
- None of these tools circumvent DRM (Bandcamp does not use DRM)

---

## Summary Comparison Table

| Tool | Language | Type | Auth | Formats | Quality | Docker | Last Release | Stars |
|------|----------|------|------|---------|---------|--------|-------------|-------|
| easlice/bandcamp-downloader | Python | Collection CLI | Auto cookies | 8 | Purchased | Via wrapper | Nov 2024 | 376 |
| meeb/bandcampsync | Python | Collection CLI | Manual cookies | 8 | Purchased | Native | Jan 2026 | 318 |
| Ezwen/bandcamp-collection-downloader | Kotlin | Collection CLI | Auto/manual cookies | 8 | Purchased | No | Active | 284 |
| Ovyerus/bandsnatch | Rust | Collection CLI | Manual cookies | 8 | Purchased | No | Sep 2024 | 99 |
| Metalnem/bandcamp-downloader | C# | Collection CLI | Username/password | 1 (MP3 V0) | Purchased | No | Active | 22 |
| Otiel/BandcampDownloader | C# | Public page GUI | None | 1 (MP3 128) | Preview | No | Dec 2025 | 1,164 |
| Evolution0/bandcamp-dl | Python | Public page CLI | None | Varies | Preview/public | No | Mar 2025 | 1,138 |
| Batchcamp | TypeScript | Browser ext. | Browser session | Configurable | Purchased | N/A | Active | 123 |
| Bandcamp-Greasy | JavaScript | Userscript | Browser session | 8 | Purchased | N/A | Active | 306 |
| bandcamp-fetch | Node.js | Library | Optional cookie | N/A | N/A | No | Active | 72 |
| free-bandcamp-downloader | Python | Free/PWYW CLI | Optional cookie | 8 | Full (free only) | No | Sep 2025 | 37 |
| daot/bcdl | Go | Free/PWYW CLI | None | Full | Full (free only) | No | Dec 2025 | 55 |

---

## Files

| File | Description |
|------|-------------|
| `README.md` | This report |
| `notes.md` | Research notes tracking methodology and incremental findings |
