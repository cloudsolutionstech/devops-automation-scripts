#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

need_cmd git

DAYS="${DAYS:-60}"
REMOTE="${REMOTE:-origin}"

git fetch --prune "$REMOTE" >/dev/null 2>&1 || die "Failed to fetch remote: $REMOTE"

log "Stale branches on $REMOTE older than $DAYS days:"

git for-each-ref --format='%(committerdate:iso8601) %(refname:short)' "refs/remotes/$REMOTE/" |
while read -r DATE BRANCH; do
  [[ "$BRANCH" == "$REMOTE/HEAD" ]] && continue

  EPOCH="$(to_epoch_utc "$DATE")"
  NOW="$(date -u +%s)"
  AGE_DAYS=$(( (NOW - EPOCH) / 86400 ))

  if [[ "$AGE_DAYS" -ge "$DAYS" ]]; then
    echo "  $BRANCH  (last commit: $DATE, age: ${AGE_DAYS}d)"
  fi
done
