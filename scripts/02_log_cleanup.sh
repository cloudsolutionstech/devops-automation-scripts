#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

LOG_DIR="${LOG_DIR:-/var/log}"
DAYS_OLD="${DAYS_OLD:-14}"
DRY_RUN="${DRY_RUN:-false}"
PATTERN="${PATTERN:-*.log}"

[[ -d "$LOG_DIR" ]] || die "LOG_DIR not found: $LOG_DIR"

log "Cleaning logs in: $LOG_DIR older than $DAYS_OLD days (pattern=$PATTERN, dry-run=$DRY_RUN)"

if [[ "$DRY_RUN" == "true" ]]; then
  find "$LOG_DIR" -type f -mtime +"$DAYS_OLD" -name "$PATTERN" -print
else
  find "$LOG_DIR" -type f -mtime +"$DAYS_OLD" -name "$PATTERN" -print -delete
fi
log "Log cleanup completed."