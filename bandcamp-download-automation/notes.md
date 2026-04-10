# Research Notes: Bandcamp Download Automation

## Goal
Find or build a way to automatically reconcile and download Bandcamp purchases into a local directory structure, avoiding manual browsing of the collection page.

## Key Findings

### No Official API
- Bandcamp has an API at bandcamp.com/developer but it's for labels/merch partners, not end-user collection access
- No public endpoint for "list my purchases" or "download my purchase"
- All existing tools use web scraping + exported browser cookies

### Authentication Challenge
- Bandcamp login has Google CAPTCHA - can't automate login programmatically
- All tools require manually exporting cookies from a browser session
- Cookies expire periodically, requiring re-export (frequency varies, typically weeks to months)
- Cookie export via extensions: "Cookie Quick Manager" (Firefox), "Get cookies.txt LOCALLY" (Chrome)

### Tools Found

#### bandcampsync (Python) - github.com/meeb/bandcampsync
- **Stars**: 318, **Last release**: v0.7.0 (Jan 2026) - actively maintained
- `pip install bandcampsync` or Docker with daily scheduling
- Uses curl-cffi (Cloudflare-compatible HTTP client)
- Creates Artist/Album/ structure with bandcamp_item_id.txt tracking files
- Scans local inventory, compares to remote collection, downloads only missing items
- Docker has RUN_DAILY_AT for scheduled syncs
- HTTP notification callbacks on completion
- Concurrency, retry, ignore lists
- 5 open issues, none critical/blocking

#### bandcamp-downloader (Python) - github.com/easlice/bandcamp-downloader
- **Stars**: 376, **Last release**: v0.2.0 (Nov 2024)
- Can read cookies directly from browser profiles (Firefox, Chrome, Brave, etc.)
- Parallel downloads (1-32 threads), date filtering, dry-run
- File size comparison to skip already-downloaded items
- Good for one-off syncs but less designed for ongoing automation
- Some issues with Chrome cookie decryption, WSL compatibility

#### bandsnatch (Rust) - github.com/Ovyerus/bandsnatch
- **Stars**: 99, **Last release**: v0.3.3 (Sep 2024)
- Fast compiled binary, cross-platform
- Cache file for incremental sync (bandcamp-collection-downloader.cache)
- Available via Homebrew, Scoop, AUR, Cargo, Nix
- 7 open issues, none about breakage
- Self-described as "work in progress"

#### bandcamp-collection-downloader (Kotlin/Java) - github.com/Ezwen (Framagit primary)
- **Stars**: 284
- Requires JRE, distributed as JAR
- Can auto-find Firefox cookies on Windows/Linux
- Artist/Year - Album structure
- Cache to avoid re-downloads

#### bcdl (Python/Selenium) - github.com/corbin-zip/bcdl
- **Stars**: 3
- Uses browser automation (Selenium + Geckodriver)
- Can handle CAPTCHA (user completes manually in automated browser)
- SQLite database of owned albums, searchable
- More complex setup, less maintained

#### Batchcamp (Browser Extension) - Firefox & Chrome
- Not CLI, runs in browser
- Good for bulk selection on collection page
- Queue management, format selection
- Manual, not suitable for full automation

### Comparison of Top Tools for Ongoing Sync

| Feature | bandcampsync | bandcamp-downloader | bandsnatch |
|---------|-------------|-------------------|------------|
| Language | Python | Python | Rust |
| Install | pip/Docker | pip | Binary/Brew |
| Scheduling | Docker RUN_DAILY_AT | None (use cron) | None (use cron) |
| Tracking | ID files in dirs | File size comparison | Cache file |
| Cookie source | Manual export file | Browser profile auto-read | Manual export file |
| Cloudflare | curl-cffi | requests/browser_cookie3 | reqwest |
| Notifications | HTTP callbacks | None | None |
| Last release | Jan 2026 | Nov 2024 | Sep 2024 |

### Recommendation
**bandcampsync** is the best fit for ongoing sync/reconciliation:
- Purpose-built for the sync use case (scan local, compare remote, download delta)
- Docker container with built-in daily scheduling
- Most recently maintained
- curl-cffi handles Cloudflare challenges
- Clean directory structure compatible with Plex/Jellyfin

### Bandcamp Technical Internals (from reverse-engineering research)

#### Authentication
- Cookie-based session auth; the `identity` cookie is the critical token
  - Format: `7 <base64>= {"ex":<expiry>,"id":<user_id>}`
- Login page has Google reCAPTCHA, preventing automated login
- Undocumented OAuth login flow exists: `POST /oauth_login` with 3-step challenge-response
  (HMAC-SHA256 challenge via `X-Bandcamp-Dm`, Hashcash proof-of-work via `X-Bandcamp-Pow`, then Bearer token)
  - Not practically useful yet since it's undocumented and may require solving CAPTCHAs anyway

#### Collection API Endpoints
- `POST /api/fancollection/1/collection_items` - paginated collection listing
  - First ~20 items embedded in page HTML (`<div id="pagedata" data-blob="{JSON}">`)
  - Remaining items fetched via POST with `older_than_token` cursor (5 colon-separated fields)
- `POST /api/fancollection/1/hidden_items` - hidden collection items
- `POST /api/fancollection/1/search_items` - search within own collection
- `GET /api/fan/2/collection_summary` - collection summary with tralbum_lookup
- Additional endpoints for wishlist, followers, following, gifts, feed updates

#### Download Flow
1. Collection API provides `redownload_urls` mapping items to download pages
2. Download pages list available formats as "stat URLs" (not direct downloads)
3. Convert `/download/` path to `/statdownload/` with added `.rand` and `.vrs=1` params
4. The `/statdownload/` endpoint returns JSON with actual CDN `download_url` on `p4.bcbits.com`
5. CDN URLs are signed and time-limited

#### Anti-Automation Measures
- Login reCAPTCHA
- Proof-of-work challenges on undocumented OAuth flow
- Download speed throttling (~50 KiB/s after first MB of a file)
- User-Agent enforcement (403 without one)
- Signed, time-limited CDN URLs
- Possible TLS fingerprint inspection (hence why bandcampsync uses curl-cffi)

#### Post-Songtradr Acquisition (Nov 2023)
- Core site and collection pages remain structurally intact
- ~50% staff layoffs but download workflow unaffected
- New features (Playlists, Clubs, Stripe payments) haven't disrupted download tools
- Some tools report intermittent data retrieval errors

### Remaining Manual Step
No tool can fully avoid the cookie export step. The most automated workflow is:
1. Export cookies once (and re-export when they expire)
2. Run bandcampsync on a schedule (Docker or cron)
3. It handles reconciliation and downloading automatically
