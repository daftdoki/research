# Bandcamp Download Infrastructure for Authenticated Users

## Question / Goal

How does Bandcamp's website technically work for authenticated users who want to access and download their purchased music collection? Specifically: authentication mechanisms, collection page structure, download process flow, internal API endpoints, and anti-automation measures.

## Answer / Summary

Bandcamp uses **cookie-based session authentication** centered on an `identity` cookie. The login form is protected by Google reCAPTCHA, so all third-party tools require users to manually extract cookies from their browser. The collection page at `bandcamp.com/<username>` embeds initial data in a `data-blob` JSON attribute, with additional items fetched via POST requests to undocumented `/api/fancollection/1/collection_items` endpoints using cursor-based pagination. The download process is a multi-step flow: collection data provides redownload URLs, which lead to download pages containing "stat URLs" per format, which must be converted to `/statdownload/` requests that return the actual CDN download URL (on `p4.bcbits.com`). Eight audio formats are available (FLAC, WAV, MP3-320, MP3-V0, AAC, AIFF, Vorbis, ALAC). Anti-automation measures include login CAPTCHA, proof-of-work challenge headers, download speed throttling, User-Agent enforcement, and signed/time-limited download URLs.

---

## Methodology

Searched technical blogs, GitHub repositories (8+ Bandcamp downloader tools in Kotlin, Python, Rust, and TypeScript), community-documented API specifications, Hacker News discussions, and Bandcamp's official help center. Cross-referenced findings across multiple independent implementations to verify consistency.

---

## Results

### 1. Authentication

#### Cookie-Based Web Authentication

Bandcamp's primary web authentication uses session cookies. The critical cookies are:

| Cookie Name | Purpose |
|---|---|
| `identity` | Primary authentication token (required) |
| `client_id` | Unique client identifier |
| `session` | Session token |
| `js_logged_in` | Login state flag |
| `logout` | User information |
| `download_encoding` | Preferred download format |
| `BACKENDID3` | Backend server routing |

The `identity` cookie is the only one strictly required for API access. Its value follows this format:

```
7 <base64-encoded-string>= {"ex":<expiration_timestamp>,"id":<numeric_user_id>}
```

The login page (`bandcamp.com/login`) is protected by **Google reCAPTCHA**, which means automated login via HTTP requests is not straightforward. Every third-party tool surveyed (8 tools across 4 languages) requires users to manually log in via a browser and then extract cookies using:
- Browser developer tools (Application > Cookies)
- Firefox addon "Cookie Quick Manager" (JSON export)
- Chrome addon "Get cookies.txt LOCALLY" (Netscape format)
- Automatic extraction from Firefox profile via `browser_cookie3` (some tools)

#### OAuth 2.0 (Official API)

Bandcamp's official developer API (for labels and merchants) uses OAuth 2.0 with tokens issued at `https://bandcamp.com/oauth_token`. Access tokens expire after 1 hour and can be refreshed. This API is restricted to approved partners.

#### Challenge-Response Login (Reverse-Engineered)

A [detailed reverse-engineering effort by Dejan Mijailovic](https://mijailovic.net/2024/04/04/bandcamp-auth/) documented a three-step challenge-response authentication flow via `POST /oauth_login`:

1. **Step 1**: POST credentials to `/oauth_login`. Server responds with **HTTP 418** and `X-Bandcamp-Dm` header containing an HMAC-SHA256 challenge. The client must compute: `HmacSha256(key2 + request.Body, key1)` where `key1` and `key2` are derived from the incoming header value.

2. **Step 2**: Resend with calculated `X-Bandcamp-Dm`. Server responds with **HTTP 451** and `X-Bandcamp-Pow` header containing a Hashcash-style proof-of-work challenge in format `<version>:<difficulty>:<challenge>` (e.g., `1:10:f6e592b662b3`).

3. **Step 3**: Client finds a counter value where `SHA-1(request_body + challenge + counter)` has the specified number of leading zero bits. Counter is encoded in Base36 and appended (e.g., `1:10:f6e592b662b3:l4` where `l4` is 760 in Base36). Server responds with **HTTP 200** and a Bearer token.

The `X-Bandcamp-Dm` header was introduced around mid-2018; `X-Bandcamp-Pow` was added in December 2019.

### 2. Collection Page Structure

#### URL Structure

- **Fan page**: `https://bandcamp.com/<username>` (customizable in Settings > Fan)
- **Purchases page**: accessible from the fan page navigation
- **Collection page**: shows purchased music and wishlisted items

#### HTML/Data Structure

The fan page embeds collection data directly in HTML via a `<div id="pagedata">` element:

```html
<div id="pagedata" data-blob='{"fan_data":{"fan_id":12345,...},"collection_data":{...},"wishlist_data":{...},"item_cache":{...}}'></div>
```

The `data-blob` JSON object contains:

- **`fan_data`**: Contains `fan_id` (numeric user identifier) needed for API calls
- **`collection_data`**: First batch of collection items and `redownload_urls`
- **`wishlist_data`**: Wishlist items with `last_token` for pagination
- **`item_cache`**: Cached item metadata including `following_bands`

Key HTML grid elements:
- `#collection-grid` / `#wishlist-grid` - grid containers
- `#collection-items-container` / `#wishlist-items-container` - items wrapper
- `#collection-items` / `#wishlist-items` - actual item lists
- `#fan-banner.owner` - indicates the page belongs to the logged-in user

The initial page load includes approximately the first 20 items. Larger collections require pagination via the fancollection API.

### 3. Download Process

The download flow involves multiple steps:

#### Step 1: Obtain Redownload URLs

The collection API response includes a `redownload_urls` object that maps items to their download page URLs. Keys are formatted as `<sale_item_type><sale_item_id>` (e.g., `"a1234567890"`).

#### Step 2: Access the Download Page

Redownload URLs point to pages like:

```
https://bandcamp.com/download?from=collection&payment_id=<id>&sale_item_id=<id>&sale_item_type=<type>&sig=<signature>
```

This page contains another `<div id="pagedata" data-blob="...">` with a `digital_items` array. Each item's `downloads` object lists available formats:

```json
{
  "digital_items": [{
    "downloads": {
      "mp3-320": {
        "size_mb": "63.3MB",
        "encoding_name": "mp3-320",
        "url": "https://popplers5.bandcamp.com/download/album?enc=mp3-320&fsig=<sig>&id=<id>&ts=<timestamp>.0"
      },
      "flac": {
        "size_mb": "412.7MB",
        "encoding_name": "flac",
        "url": "https://popplers5.bandcamp.com/download/album?enc=flac&fsig=<sig>&id=<id>&ts=<timestamp>.0"
      }
    }
  }]
}
```

#### Step 3: Convert to Statdownload Request

The URLs in `downloads` are **stat URLs, not direct download links**. To obtain the actual download URL, convert `/download/` to `/statdownload/` and modify parameters:

| Original | Modified |
|---|---|
| Endpoint: `/download/album` | Endpoint: `/statdownload/album` |
| `ts=<timestamp>.0` | `ts=<timestamp>.<random_decimal>` |
| (none) | Add `&.rand=<epoch_milliseconds>` |
| (none) | Add `&.vrs=1` |

Example transformation:

```
# Original stat URL
https://popplers5.bandcamp.com/download/album?enc=mp3-320&fsig=abc123&id=999&ts=1700000000.0

# Converted statdownload URL
https://popplers5.bandcamp.com/statdownload/album?enc=mp3-320&fsig=abc123&id=999&ts=1700000000.7382&.rand=1700000000123&.vrs=1
```

#### Step 4: Receive CDN Download URL

The statdownload endpoint returns JSON:

```json
{
  "result": "ok",
  "url": "popplers5.bandcamp.com/statdownload/album?enc=mp3-320&...",
  "host": "scruffycentral-b4gx-2",
  "download_url": "https://p4.bcbits.com/download/album/<hash>/mp3-320/<id>?fsig=<sig>&id=<id>&ts=<epoch>.<decimal>&token=<timestamp>_<hash>"
}
```

The `download_url` field contains the actual CDN link to the ZIP file. On error (e.g., expired links), the response may be wrapped in JavaScript:

```javascript
if (window.Downloads) {
    Downloads.statResult({
        "result": "err",
        "retry_url": "https://popplers5.bandcamp.com/download/album?enc=...",
        "errortype": "ExpiredFreeDownloadError"
    })
}
```

#### Available Download Formats

| Format ID | Description | File Extension |
|---|---|---|
| `flac` | FLAC lossless | `.flac` / `.zip` |
| `wav` | WAV uncompressed | `.wav` / `.zip` |
| `aiff-lossless` | AIFF lossless | `.aiff` / `.zip` |
| `alac` | Apple Lossless | `.m4a` / `.zip` |
| `mp3-320` | MP3 CBR 320kbps | `.mp3` / `.zip` |
| `mp3-v0` | MP3 VBR V0 (~245kbps) | `.mp3` / `.zip` |
| `aac-hi` | AAC high quality | `.m4a` / `.zip` |
| `vorbis` | Ogg Vorbis | `.ogg` / `.zip` |

Albums are delivered as ZIP archives; single tracks as individual files.

#### CDN Infrastructure

| Hostname Pattern | Purpose |
|---|---|
| `popplers1-5.bandcamp.com` | Stat/download request routing |
| `p1-4.bcbits.com` | File download CDN |
| `t1-4.bcbits.com` | Audio streaming CDN |
| `f0-4.bcbits.com` | Artwork/image CDN |

Download URLs include signed tokens in the format `token=<timestamp>_<hash>` that are time-limited.

### 4. Internal API Endpoints

The following endpoints have been documented by the community (primarily via [michaelherger/Bandcamp-API](https://github.com/michaelherger/Bandcamp-API) and various downloader implementations):

#### Fan Collection Endpoints (all POST, require identity cookie)

| Endpoint | Body Parameters | Returns |
|---|---|---|
| `/api/fancollection/1/collection_items` | `fan_id`, `older_than_token`, `count` | Items, track_list, redownload_urls, more_available, last_token |
| `/api/fancollection/1/hidden_items` | `fan_id`, `older_than_token`, `count` | Same structure as collection_items |
| `/api/fancollection/1/wishlist_items` | `fan_id`, `older_than_token`, `count` | Same structure |
| `/api/fancollection/1/search_items` | `fan_id`, `search_key`, `search_type` | tralbums, redownload_urls, item_lookup, track_list |
| `/api/fancollection/1/followers` | `fan_id`, `older_than_token`, `count` | Followers list with more_available, last_token |
| `/api/fancollection/1/following_bands` | `fan_id`, `older_than_token`, `count` | Following bands list |
| `/api/fancollection/1/following_fans` | `fan_id`, `older_than_token`, `count` | Following fans list |
| `/api/fancollection/1/gifts_given` | `fan_id`, `older_than_token`, `count` | Gifts list |
| `/api/fancollection/1/fan_suggestions` | `fan_id`, `older_than_token`, `count` | Suggested fans |

#### Other Fan Endpoints

| Endpoint | Method | Returns |
|---|---|---|
| `/api/fan/2/collection_summary` | GET (identity cookie) | fan_id, tralbum_lookup, follows, url, username |
| `/fan_feed_poll` | POST (identity cookie) | Feed updates (body: `since`, `crumb`) |
| `/fan_dash_feed_updates` | POST (identity cookie) | Stories, fan_info, band_info |

#### Public/Semi-Public Endpoints

| Endpoint | Method | Parameters |
|---|---|---|
| `/api/band/3/search` | GET | `key`, `name` |
| `/api/band/3/discography` | GET | `key`, `band_id` |
| `/api/album/2/info` | GET | `key`, `album_id` |
| `/api/track/3/info` | GET | `key`, `track_id` |
| `/api/url/1/info` | GET | `key`, `url` |
| `/api/discover/3/get_web` | GET | `p` (page), `s` (sort: top/pic/new/most) |
| `/api/salesfeed/1/get` | GET | `start_date` (optional unix timestamp) |
| `/api/bcweekly/2/list` | GET | (none) |
| `/api/bcweekly/2/get` | GET | `id` |

Note: The `key` parameter refers to a developer API key that Bandcamp no longer distributes to new applicants.

#### Collection Sync (Bearer Token Required)

| Endpoint | Method | Parameters |
|---|---|---|
| `/api/collectionsync/1/collection` | GET | `page_size` (e.g., 200) |

This endpoint requires the Bearer token obtained through the full challenge-response OAuth login flow and returns album metadata, track information, and audio URLs.

#### Pagination: `older_than_token` Format

The token is a colon-separated string with 5 fields:

```
<unix_timestamp>:<tralbum_id>:<tralbum_type>:<index>:<empty>
```

Example: `1486347388:3314754897:a:2:`

| Field | Required | Description |
|---|---|---|
| 1: Unix timestamp | No (can be blank) | When fan purchased the item |
| 2: tralbum_id | No (can be blank) | Item identifier |
| 3: tralbum_type | Yes (any non-empty value) | `a` for album, `t` for track |
| 4: Index | Only field that matters for offset | Pagination offset (positive integer) |
| 5: (empty) | No | Unused padding |

Practical shortcut to fetch from the beginning: `f"{int(time.time())}::a::"`

The response includes `more_available` (boolean) and `last_token` (string) for fetching the next page.

### 5. Anti-Automation Measures

#### Login Protection
- **Google reCAPTCHA** on the login form at `bandcamp.com/login` -- this is the primary barrier preventing automated login. All surveyed third-party tools (8 tools) require manual browser login and cookie extraction.
- **Proof-of-work challenge** (`X-Bandcamp-Pow`): Hashcash-style SHA-1 computation required for the API OAuth login flow.
- **HMAC challenge** (`X-Bandcamp-Dm`): HMAC-SHA256 challenge-response for the API OAuth login flow.

#### Download Restrictions
- **Speed throttling**: Downloads reportedly start at ~3 Mbit/s then throttle to ~50 KiB/s after the first megabyte. This appears designed to support streaming playback speed rather than bulk downloading. (Note: this was reported in 2016 and may have changed.)
- **Signed, time-limited download URLs**: CDN download URLs include `token=<timestamp>_<hash>` parameters that expire.
- **User-Agent enforcement**: CDN servers return HTTP 403 for requests without a proper User-Agent header.
- **Streaming limits**: Non-purchasers are limited to 3 plays per song.
- **Free download quotas**: Artist accounts start with 200 free download credits per month.

#### Bot Detection
- **TLS fingerprinting**: Some tools (notably `bandcampsync`) use `curl_cffi` with Chrome impersonation to present browser-like TLS/JA3 fingerprints, suggesting Bandcamp may inspect TLS characteristics.
- **No evidence of Cloudflare or Turnstile**: Research did not find evidence that Bandcamp uses Cloudflare Bot Management or Turnstile CAPTCHAs (beyond the login reCAPTCHA).
- **No evidence of IP-based rate limiting for authenticated downloads**: None of the surveyed tools implement IP rotation or mention IP bans during collection downloads, though most use conservative concurrency defaults (1-5 parallel downloads).

---

## Analysis

### Why Cookie Extraction Is Universal

Every Bandcamp downloader tool uses the same authentication approach: extract the `identity` cookie from a browser session. This is because:
1. The login form has reCAPTCHA that blocks simple HTTP-based login
2. The OAuth challenge-response (X-Bandcamp-Dm/Pow) is complex to implement and not well-documented
3. The identity cookie is long-lived enough for batch operations
4. Only one cookie (`identity`) is needed for most API access

### The Statdownload Indirection

The fact that download URLs in the page data are "stat URLs" rather than direct download links serves dual purposes:
1. **Analytics**: The `/statdownload/` endpoint likely records download statistics before redirecting
2. **Security**: Adding the `.rand` and `.vrs` parameters plus modifying the timestamp provides a layer of request validation

### Tool Ecosystem Maturity

The ecosystem of Bandcamp download tools is mature and well-maintained, driven largely by user concern about content permanence (especially after the Songtradr acquisition in 2023). Tools range from simple browser extensions (Batchcamp) to Docker-deployable automation services (bandcampsync) with webhook notifications.

### Stability of the API

The undocumented `/api/fancollection/1/` endpoints have remained stable for years (tools dating to 2019+ still function). The pagination token format and response structure have been consistent enough for multiple independent implementations to work reliably.

---

## Files

| File | Description |
|---|---|
| `notes.md` | Raw research notes with all findings, sources searched, and data collected |
| `README.md` | This report -- structured analysis of Bandcamp's download infrastructure |
