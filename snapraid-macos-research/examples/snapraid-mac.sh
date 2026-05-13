#!/bin/bash
#
# snapraid-mac.sh — minimal SnapRAID wrapper for macOS Apple Silicon
#
# Runs the standard maintenance cycle (diff → sync → scrub) with a safety
# threshold on deletions, sends macOS Notification Center alerts on
# success / failure, and keeps the host awake for the duration via caffeinate.
#
# Tested with snapraid 14.4 from Homebrew on macOS 15 / 26.

set -u
set -o pipefail

# ---------- Settings ----------
CONFIG="/opt/homebrew/etc/snapraid.conf"
SNAPRAID="/opt/homebrew/bin/snapraid"

# Maximum number of deleted files SnapRAID is allowed to "see" before
# sync is aborted as suspicious. Tune to your library's churn.
MAX_DELETES=500

# Scrub: verify N% of the oldest blocks at least M days old.
SCRUB_PERCENT=5
SCRUB_AGE=10

LOG_DIR="$HOME/Library/Logs"
LOG="$LOG_DIR/snapraid-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

notify() {
  local title="$1"; local message="$2"
  /usr/bin/osascript -e "display notification \"$message\" with title \"$title\""
}

# Keep the Mac awake (and prevent disk sleep) for the entire run.
exec /usr/bin/caffeinate -dimsu -w $$ /bin/bash -c '
set -u; set -o pipefail
echo "==== SnapRAID run started $(date) ====" | tee -a "'"$LOG"'"

# ---- diff ----
echo "---- diff ----" | tee -a "'"$LOG"'"
DIFF_OUT=$('"$SNAPRAID"' -c "'"$CONFIG"'" diff 2>&1 | tee -a "'"$LOG"'")
DIFF_RC=$?
# `snapraid diff` exits 2 when there are changes; that is normal.
if [[ $DIFF_RC -ne 0 && $DIFF_RC -ne 2 ]]; then
  '"$(declare -f notify)"'
  notify "SnapRAID FAILED" "diff exited $DIFF_RC — see $('"$LOG"')"
  exit $DIFF_RC
fi

# Safety threshold: count "removed" lines reported by diff.
REMOVED=$(printf "%s\n" "$DIFF_OUT" | grep -c "^remove " || true)
if [[ "$REMOVED" -gt "'"$MAX_DELETES"'" ]]; then
  '"$(declare -f notify)"'
  notify "SnapRAID PAUSED" "$REMOVED files marked removed (limit '"$MAX_DELETES"'). Sync skipped."
  echo "Safety abort: $REMOVED removed files." | tee -a "'"$LOG"'"
  exit 1
fi

# ---- sync ----
echo "---- sync ----" | tee -a "'"$LOG"'"
'"$SNAPRAID"' -c "'"$CONFIG"'" sync 2>&1 | tee -a "'"$LOG"'"
SYNC_RC=${PIPESTATUS[0]}
if [[ $SYNC_RC -ne 0 ]]; then
  '"$(declare -f notify)"'
  notify "SnapRAID sync FAILED" "exit $SYNC_RC — see $('"$LOG"')"
  exit $SYNC_RC
fi

# ---- pool refresh (symlink tree) ----
echo "---- pool ----" | tee -a "'"$LOG"'"
'"$SNAPRAID"' -c "'"$CONFIG"'" pool 2>&1 | tee -a "'"$LOG"'" || true

# ---- scrub ----
echo "---- scrub ----" | tee -a "'"$LOG"'"
'"$SNAPRAID"' -c "'"$CONFIG"'" scrub -p '"$SCRUB_PERCENT"' -o '"$SCRUB_AGE"' 2>&1 | tee -a "'"$LOG"'"
SCRUB_RC=${PIPESTATUS[0]}

# ---- status + smart summaries ----
echo "---- status ----" | tee -a "'"$LOG"'"
'"$SNAPRAID"' -c "'"$CONFIG"'" status 2>&1 | tee -a "'"$LOG"'" || true
echo "---- smart ----" | tee -a "'"$LOG"'"
'"$SNAPRAID"' -c "'"$CONFIG"'" smart 2>&1 | tee -a "'"$LOG"'" || true

echo "==== SnapRAID run finished $(date) ====" | tee -a "'"$LOG"'"

'"$(declare -f notify)"'
if [[ $SCRUB_RC -eq 0 ]]; then
  notify "SnapRAID OK" "sync + scrub completed."
else
  notify "SnapRAID scrub WARNING" "scrub exited $SCRUB_RC — see $('"$LOG"')"
fi
'
