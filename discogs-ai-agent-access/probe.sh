#!/usr/bin/env bash
# Re-run the unauthenticated Discogs API probes behind this report.
# Usage: ./probe.sh [public_username]
# Optional: DISCOGS_TOKEN=... to compare authenticated behaviour.
set -u
UA="${UA:-DiscogsAgentProbe/1.0 +https://github.com/daftdoki/research}"
USER_NAME="${1:-willchatham}"
API=https://api.discogs.com
AUTH=()
[ -n "${DISCOGS_TOKEN:-}" ] && AUTH=(-H "Authorization: Discogs token=${DISCOGS_TOKEN}")

code() { curl -sS -o /dev/null -w '%{http_code}' -A "$UA" "${AUTH[@]}" "$@"; }

echo "== rate limit headers"
curl -sS -D - -o /dev/null -A "$UA" "${AUTH[@]}" "$API/releases/249504" | grep -i '^x-discogs-ratelimit'

echo "== User-Agent enforcement"
echo "empty UA:        $(curl -sS -o /dev/null -w '%{http_code}' -H 'User-Agent:' "$API/releases/249504")"
echo "default curl UA: $(curl -sS -o /dev/null -w '%{http_code}' "$API/releases/249504")"

echo "== database"
echo "release:          $(code "$API/releases/249504")"
echo "search:           $(code "$API/database/search?q=nirvana&per_page=1")"
curl -sS -A "$UA" "${AUTH[@]}" "$API/database/search?q=nirvana&per_page=500" |
  python3 -c 'import json,sys;p=json.load(sys.stdin)["pagination"];print("search per_page asked 500 ->",p["per_page"],"| pages",p["pages"],"| items",p["items"])'
echo "search page 201@50: $(code "$API/database/search?q=nirvana&page=201&per_page=50")  (10k result cap)"
curl -sS -A "$UA" "${AUTH[@]}" "$API/database/search?q=nirvana&type=master&per_page=1" |
  python3 -c 'import json,sys;r=json.load(sys.stdin)["results"][0];print("search image fields present:",bool(r.get("thumb")),bool(r.get("cover_image")))'

echo "== user $USER_NAME (public collection assumed)"
for p in profile collection/folders "collection/folders/0/releases?per_page=1" "wants?per_page=1" lists collection/value collection/fields; do
  url="$API/users/$USER_NAME/$p"; [ "$p" = profile ] && url="$API/users/$USER_NAME"
  printf '%-40s %s\n' "${url#$API}" "$(code "$url")"
done
echo "/oauth/identity                          $(code "$API/oauth/identity")"
