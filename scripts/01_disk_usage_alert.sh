#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"

THRESHOLD="${THRESHOLD:-75}"
EMAIL_TO="${EMAIL_TO:-you@example.com}"
HOST="$(hostname -f 2>/dev/null || hostname)"

ALERTS=()

while read -r filesystem _ _ avail usepct mount; do
  pct="${usepct%\%}"
  if [[ "$pct" -ge "$THRESHOLD" ]]; then
    ALERTS+=("Mount: $mount | Usage: $usepct | Avail: $avail | FS: $filesystem")
  fi
done < <(df -hP | awk 'NR>1 {print $1,$2,$3,$4,$5,$6}')

if [[ "${#ALERTS[@]}" -gt 0 ]]; then
  msg=$'Disk usage threshold exceeded:\n\n'"$(printf "%s\n" "${ALERTS[@]}")"
  send_email_best_effort "[ALERT] Disk usage on $HOST" "$msg" "$EMAIL_TO" || true
fi
exit 0