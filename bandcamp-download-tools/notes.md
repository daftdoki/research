# Research Notes: Bandcamp Collection Download Tools

## Research approach

1. Searched GitHub for repositories matching "bandcamp downloader", "bandcamp collection downloader", "bcdl", "bandcamp download" - sorted by stars
2. Searched the web for Bandcamp official API documentation at bandcamp.com/developer
3. Fetched README pages for the top ~15 repositories
4. Searched for browser extensions and userscripts on Greasy Fork and GitHub
5. Searched PyPI for installable Python packages (bandcamp-downloader, free-bandcamp-downloader, bandripper, campdown)
6. Searched for information on Bandcamp site changes post-Songtradr acquisition (Nov 2023)
7. Checked GitHub issues for common breakage patterns (cookies, captcha, rate limiting, 429 errors)

## Key findings

### Official Bandcamp API
- Bandcamp has an official API at bandcamp.com/developer but it is NOT useful for downloading purchased music
- The API only covers: Account management, Sales Reports, Merch Orders
- Access is restricted to "labels and merchandise fulfillment partners" - not general public
- Uses OAuth 2.0 authentication
- There is NO official endpoint for accessing fan purchases or collection data

### Authentication is the central challenge
- All collection download tools must authenticate as the user
- Bandcamp uses Google reCAPTCHA on login, preventing automated login
- Every tool requires manual cookie extraction from a browser session
- The `identity` cookie is the key authentication token
- browser_cookie3 Python library is popular but has issues (Chrome decryption, WSL/dbus, Flatpak/Snap browsers)

### Bandcamp rate limiting
- Bandcamp returns HTTP 429 "Too Many Requests" when downloads are too rapid
- Official help article exists acknowledging this for large discography purchases
- Tools handle this with configurable concurrency and retry delays

### Post-Songtradr acquisition (Nov 2023)
- No major site redesign that broke downloaders wholesale
- ~50% staff layoffs but core site functionality preserved
- New features added: Bandcamp Playlists (May 2025), Bandcamp Clubs (Sep 2025), Bluesky integration
- Payment system transitioning to Stripe (summer 2025)
- Collection page structure appears largely unchanged
- Some tools report "Could not retrieve data" errors, possibly related to minor page changes

### Categories of tools found
1. **Collection downloaders** (download your purchased library) - most useful/popular
2. **Public page rippers** (download free/preview streams at 128kbps) - limited quality
3. **Free/PWYW downloaders** (automate "purchasing" free albums) - niche use case
4. **Browser extensions** (run within browser context, no cookie export needed) - easiest UX
5. **Userscripts** (Greasemonkey/Tampermonkey) - lightweight browser approach
6. **Scraping libraries** (developer tools for building other apps) - not end-user tools

### Most actively maintained tools (as of April 2026)
1. easlice/bandcamp-downloader (Python) - last release Nov 2024, active issues
2. meeb/bandcampsync (Python) - last release Jan 2026, Docker support
3. Ovyerus/bandsnatch (Rust) - last release Sep 2024
4. Otiel/BandcampDownloader (C#) - last release Dec 2025, Windows GUI
5. Evolution0/bandcamp-dl (Python) - last release Mar 2025, PyPI package
6. hyphmongo/batchcamp (TypeScript) - browser extension, Chrome + Firefox
7. Ezwen/bandcamp-collection-downloader (Kotlin) - official repo on Framagit
