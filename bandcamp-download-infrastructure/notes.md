# Research Notes: Bandcamp Download Infrastructure

## What I investigated
Technical details of how Bandcamp's website works for authenticated users accessing their purchased music collection. Focus areas: authentication, collection pages, download process, internal API endpoints, and anti-automation measures.

## Sources searched
- Blog post: "Reverse engineering Bandcamp authentication protocol" by Dejan Mijailovic (April 2024) - https://mijailovic.net/2024/04/04/bandcamp-auth/
- Blog post: "Reverse engineering Bandcamp downloads for love and piece" by torunar (June 2024) - https://torunar.github.io/en/2024/06/24/bandcamp-downloads/
- GitHub: Ezwen/bandcamp-collection-downloader (Kotlin/Java tool, official at framagit.org)
- GitHub: meeb/bandcampsync (Python tool with Docker support)
- GitHub: easlice/bandcamp-downloader (Python tool)
- GitHub: hyphmongo/batchcamp (Chrome/Firefox browser extension)
- GitHub: 7x11x13/free-bandcamp-downloader (Python, free/NYP items)
- GitHub: yyyyyyyan/bandcamper (Python downloader)
- GitHub: Ovyerus/bandsnatch (Rust CLI tool)
- GitHub: corbin-zip/bcdl and s6angrev/bcdl (various bcdl implementations)
- GitHub: michaelherger/Bandcamp-API (Swagger documentation of undocumented API)
- GitHub: patrickkfkan/bandcamp-fetch (Node.js library)
- Greasyfork: Bandcamp Collection Filters userscript (shows HTML/JS structure)
- Bandcamp official help center articles
- Bandcamp official developer API docs
- Hacker News discussions (multiple threads about archiving Bandcamp collections)
- GitHub issues on iheanyi/bandcamp-dl about speed throttling
- Reddit communities: r/datahoarder, r/musichoarder (referenced in searches)

## Key findings

### Authentication
1. Bandcamp login page has Google reCAPTCHA - can't be automated with simple HTTP requests
2. Primary auth mechanism for web: session cookies, especially the "identity" cookie
3. Identity cookie format: `7 <base64-encoded-string>= {"ex":<expiration>,"id":<user_id>}`
4. Full cookie set includes: client_id, session, identity, js_logged_in, logout, download_encoding, BACKENDID3
5. OAuth 2.0 exists for the official API (labels/merchants) - tokens expire in 1 hour with refresh tokens
6. Login endpoint POST /oauth_login has a 3-step challenge-response:
   - Step 1: POST credentials -> HTTP 418 + X-Bandcamp-Dm header
   - Step 2: Resend with calculated X-Bandcamp-Dm -> HTTP 451 + X-Bandcamp-Pow header
   - Step 3: Resend with calculated X-Bandcamp-Pow -> HTTP 200 + auth token
7. X-Bandcamp-Dm: HMAC-SHA256 based challenge
8. X-Bandcamp-Pow: Hashcash-style proof-of-work (SHA-1, find leading zero bits, counter in Base36)
9. X-Bandcamp-Pow introduced Dec 2019, X-Bandcamp-Dm introduced ~mid 2018

### Collection Page Structure
1. Fan page URL: `https://bandcamp.com/<username>`
2. HTML contains `<div id="pagedata" data-blob="{JSON}">` with embedded collection data
3. The data-blob JSON contains: fan_data (fan_id), collection_data, wishlist_data, item_cache
4. Initial page load includes first ~20 items; rest requires API pagination
5. Grid elements: #collection-grid, #wishlist-grid, with items in #collection-items-container

### Internal API Endpoints (undocumented)
1. POST `https://bandcamp.com/api/fancollection/1/collection_items` - Body: fan_id, older_than_token, count
2. POST `https://bandcamp.com/api/fancollection/1/hidden_items` - Same format
3. POST `https://bandcamp.com/api/fancollection/1/wishlist_items` - Same format
4. POST `https://bandcamp.com/api/fancollection/1/search_items` - Body: fan_id, search_key, search_type
5. GET `https://bandcamp.com/api/fan/2/collection_summary` - Returns fan_id, tralbum_lookup
6. POST endpoints for followers, following_bands, following_fans, gifts_given, fan_suggestions
7. GET `https://bandcamp.com/api/collectionsync/1/collection?page_size=200` (requires Bearer token)

### older_than_token Format
- 5 colon-separated fields: `<unix_timestamp>:<tralbum_id>:<tralbum_type>:<index>:<empty>`
- Example: `1486347388:3314754897:a:2:`
- Fields 1-2 (timestamp, id) can be left blank
- Field 3 (tralbum_type) must not be empty but any value works
- Field 4 (index) is the pagination offset
- Practical shortcut: `f"{int(time.time())}::a::"`

### Download Process
1. Collection API returns `redownload_urls` mapping sale_item_type+sale_item_id to download page URLs
2. Download page contains `digital_items[].downloads` keyed by encoding name
3. URLs in downloads are "stat URLs" - NOT direct download links
4. Convert `/download/` to `/statdownload/` with modified ts, added .rand and .vrs=1 params
5. Statdownload returns JSON with `download_url` pointing to actual CDN file (p4.bcbits.com)

### CDN Infrastructure
- Stat URLs: popplers1-5.bandcamp.com
- Download CDN: p1-4.bcbits.com
- Streaming CDN: t1-4.bcbits.com
- Artwork CDN: f0-4.bcbits.com
- Download URLs include signed tokens: `token=<timestamp>_<hash>`

### Available Download Formats
mp3-v0, mp3-320, flac, wav, aac-hi, aiff-lossless, vorbis, alac

### Anti-Automation Measures
1. Google reCAPTCHA on login form
2. Download throttling (~50 KiB/s after first MB, reported 2016)
3. User-Agent requirement (403 without)
4. Proof-of-work on API login (X-Bandcamp-Pow)
5. HMAC challenge on API login (X-Bandcamp-Dm)
6. Streaming limits (3 plays for non-purchasers)
7. Free download quotas (200/month per artist)
8. Signed/time-limited download URLs
9. TLS fingerprint inspection (tools use curl_cffi with Chrome impersonation)

### Existing Tools Summary
| Tool | Language | Auth Method |
|------|----------|-------------|
| bandcamp-collection-downloader | Kotlin | Firefox cookies auto-detect or cookie file |
| bandcampsync | Python | Manual cookie extraction, curl_cffi |
| bandcamp-downloader (easlice) | Python | browser_cookie3 auto-detect |
| batchcamp | TypeScript | Browser session (extension) |
| bandsnatch | Rust | Cookie file |
| free-bandcamp-downloader | Python | Identity cookie |
| bandcamper | Python | Not specified |
| bcdl (s6angrev) | Python | Selenium login |
